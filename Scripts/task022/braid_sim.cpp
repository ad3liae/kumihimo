#include "braid_sim.h"

#include "layers.h"

#include <Jolt/Jolt.h>

#include <Jolt/Core/Factory.h>
#include <Jolt/Core/JobSystemSingleThreaded.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Geometry/Triangle.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Collision/ContactListener.h>
#include <Jolt/Physics/Collision/GroupFilterTable.h>
#include <Jolt/Physics/Collision/Shape/CapsuleShape.h>
#include <Jolt/Physics/Collision/Shape/CylinderShape.h>
#include <Jolt/Physics/Collision/Shape/MeshShape.h>
#include <Jolt/Physics/Collision/Shape/SphereShape.h>
#include <Jolt/Physics/Constraints/PointConstraint.h>
#include <Jolt/Physics/PhysicsSettings.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/RegisterTypes.h>

#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdio>

namespace braid {
namespace {

constexpr float kPi = 3.14159265358979323846f;

void EnsureJoltStarted() {
    static bool started = false;
    if (started) return;
    JPH::RegisterDefaultAllocator();
    JPH::Factory::sInstance = new JPH::Factory();
    JPH::RegisterTypes();
    started = true;
}

// The mirror: a disc with a hole, both rims rounded. Revolve the cross-section.
// Every triangle is wound so that its normal is (along the profile) x (round the
// axis), which points out of the solid.
JPH::TriangleList MirrorTriangles(float outer, float inner, float thickness,
                                  float fillet, int segments) {
    struct P { float r, z; };
    std::vector<P> profile;
    const int arc = 6;
    auto arc_points = [&](float cr, float cz, float from, float to) {
        for (int i = 0; i <= arc; ++i) {
            float t = from + (to - from) * (float)i / (float)arc;
            profile.push_back({cr + fillet * std::cos(t), cz + fillet * std::sin(t)});
        }
    };
    // top face, outwards
    profile.push_back({inner + fillet, 0.0f});
    profile.push_back({outer - fillet, 0.0f});
    arc_points(outer - fillet, -fillet, 0.5f * kPi, 0.0f);          // outer top rim
    arc_points(outer - fillet, -thickness + fillet, 0.0f, -0.5f * kPi);  // outer bottom rim
    profile.push_back({inner + fillet, -thickness});
    arc_points(inner + fillet, -thickness + fillet, -0.5f * kPi, -kPi);  // inner bottom rim
    arc_points(inner + fillet, -fillet, kPi, 0.5f * kPi);           // inner top rim

    JPH::TriangleList triangles;
    auto at = [&](int i, int j) {
        float a = 2.0f * kPi * (float)j / (float)segments;
        return JPH::Float3(profile[i].r * std::cos(a), profile[i].r * std::sin(a), profile[i].z);
    };
    for (size_t i = 0; i + 1 < profile.size(); ++i)
        for (int j = 0; j < segments; ++j) {
            int k = (j + 1) % segments;
            triangles.push_back(JPH::Triangle(at((int)i, j), at((int)i + 1, j), at((int)i, k)));
            triangles.push_back(JPH::Triangle(at((int)i + 1, j), at((int)i + 1, k), at((int)i, k)));
        }
    // close the loop between the last profile point and the first
    size_t last = profile.size() - 1;
    for (int j = 0; j < segments; ++j) {
        int k = (j + 1) % segments;
        triangles.push_back(JPH::Triangle(at((int)last, j), at(0, j), at((int)last, k)));
        triangles.push_back(JPH::Triangle(at(0, j), at(0, k), at((int)last, k)));
    }
    return triangles;
}

// Walk a polyline and hand back a point every `spacing` of arc length.
std::vector<JPH::Vec3> Sample(const std::vector<JPH::Vec3> &way, float spacing, int count) {
    std::vector<JPH::Vec3> out;
    out.reserve(count);
    size_t leg = 0;
    float along = 0.0f;
    for (int i = 0; i < count; ++i) {
        float want = (float)i * spacing;
        while (leg + 1 < way.size()) {
            float len = (way[leg + 1] - way[leg]).Length();
            if (along + len >= want || leg + 2 == way.size()) break;
            along += len;
            ++leg;
        }
        if (leg + 1 >= way.size()) { out.push_back(way.back()); continue; }
        JPH::Vec3 d = way[leg + 1] - way[leg];
        float len = d.Length();
        float t = len > 1e-6f ? (want - along) / len : 0.0f;
        out.push_back(way[leg] + d * t);
    }
    return out;
}

class Penetration final : public JPH::ContactListener {
public:
    void OnContactAdded(const JPH::Body &, const JPH::Body &, const JPH::ContactManifold &m,
                        JPH::ContactSettings &) override {
        deepest = std::max(deepest, m.mPenetrationDepth);
    }
    void OnContactPersisted(const JPH::Body &, const JPH::Body &, const JPH::ContactManifold &m,
                            JPH::ContactSettings &) override {
        deepest = std::max(deepest, m.mPenetrationDepth);
    }
    float deepest = 0.0f;
};

}  // namespace

// Jolt's allocator has to exist before anything of Jolt's is built, and members
// are built before the constructor body runs -- hence a base class.
struct Started {
    Started() { EnsureJoltStarted(); }
};

struct Sim::Impl : Started {
    explicit Impl(const Config &c)
        : config(c), temp(64 * 1024 * 1024) {
        system.Init(8192, 0, 65536, 32768, broad_phase, object_vs_broad_phase, object_pair);
        system.SetGravity(JPH::Vec3(0.0f, 0.0f, -config.gravity));
        JPH::PhysicsSettings settings = system.GetPhysicsSettings();
        settings.mNumVelocitySteps = config.velocity_steps;
        settings.mNumPositionSteps = config.position_steps;
        system.SetPhysicsSettings(settings);
        system.SetContactListener(&penetration);
    }

    Config config;
    JPH::TempAllocatorImpl temp;
    JPH::JobSystemSingleThreaded job{JPH::cMaxPhysicsJobs};
    BPLayerInterfaceImpl broad_phase;
    ObjectVsBroadPhaseLayerFilterImpl object_vs_broad_phase;
    ObjectLayerPairFilterImpl object_pair;
    JPH::PhysicsSystem system;
    Penetration penetration;

    JPH::Ref<JPH::GroupFilterTable> filter;
    std::vector<JPH::BodyID> beads;          // every capsule, thread after thread
    std::vector<int> thread_of;
    std::vector<int> index_in;
    std::vector<JPH::BodyID> tama;
    std::vector<JPH::Ref<JPH::TwoBodyConstraint>> tama_joint;
    JPH::BodyID knot;
    JPH::BodyID takeup;
    std::vector<int> notch_of_thread;
    std::vector<float> notch_angle;          // by thread

    int BeadIndex(int thread, int i) const { return thread * config.beads + i; }
};

Sim::Sim(const Config &config) : impl_(std::make_unique<Impl>(config)) {}
Sim::~Sim() = default;

float Sim::NotchAngle(int notch) const {
    float turn = 2.0f * kPi * (float)(notch - 1) / (float)kNotches;
    return impl_->config.clockwise ? -turn : turn;
}

void Sim::BuildSeed() {
    Impl &s = *impl_;
    const Config &c = s.config;
    JPH::BodyInterface &bi = s.system.GetBodyInterface();

    // The stand. Only the mirror and its hole are needed: the board and the legs
    // never touch a thread (docs/architecture.md).
    JPH::MeshShapeSettings mirror_settings(
        MirrorTriangles(c.mirror_radius, c.hole_radius, c.mirror_thickness, c.fillet,
                        c.rim_segments));
    mirror_settings.SetEmbedded();
    JPH::ShapeRefC mirror = mirror_settings.Create().Get();
    JPH::BodyCreationSettings mirror_body(mirror, JPH::RVec3::sZero(), JPH::Quat::sIdentity(),
                                          JPH::EMotionType::Static, Layers::NON_MOVING);
    mirror_body.mEnhancedInternalEdgeRemoval = true;
    bi.CreateAndAddBody(mirror_body, JPH::EActivation::DontActivate);

    // The knot the sixteen ends are tied in, and the take-up hanging on it.
    const float knot_radius = 3.0f;
    JPH::BodyCreationSettings knot_body(new JPH::SphereShape(knot_radius),
                                        JPH::RVec3(0, 0, c.knot_depth), JPH::Quat::sIdentity(),
                                        JPH::EMotionType::Dynamic, Layers::MOVING);
    knot_body.mOverrideMassProperties = JPH::EOverrideMassProperties::CalculateInertia;
    knot_body.mMassPropertiesOverride.mMass = 5.0f;
    knot_body.mEnhancedInternalEdgeRemoval = true;
    s.knot = bi.CreateAndAddBody(knot_body, JPH::EActivation::Activate);

    const float weight_half = 2.0f;
    JPH::BodyCreationSettings weight(new JPH::CylinderShape(weight_half, 8.0f),
                                     JPH::RVec3(0, 0, c.knot_depth - knot_radius - 4.0f),
                                     JPH::Quat::sRotation(JPH::Vec3::sAxisX(), 0.5f * kPi),
                                     JPH::EMotionType::Dynamic, Layers::MOVING);
    weight.mOverrideMassProperties = JPH::EOverrideMassProperties::CalculateInertia;
    weight.mMassPropertiesOverride.mMass = c.takeup_mass;
    s.takeup = bi.CreateAndAddBody(weight, JPH::EActivation::Activate);
    {
        JPH::PointConstraintSettings joint;
        joint.mSpace = JPH::EConstraintSpace::WorldSpace;
        joint.mPoint1 = joint.mPoint2 = JPH::RVec3(0, 0, c.knot_depth - knot_radius);
        s.system.AddConstraint(bi.CreateConstraint(&joint, s.knot, s.takeup));
    }

    // Adjacent capsules of one thread overlap by design, so they must not push
    // each other apart. Threads are different groups and do collide.
    s.filter = new JPH::GroupFilterTable((JPH::uint)c.beads);
    for (int i = 0; i + 1 < c.beads; ++i)
        s.filter->DisableCollision((JPH::CollisionGroup::SubGroupID)i,
                                   (JPH::CollisionGroup::SubGroupID)(i + 1));

    JPH::CapsuleShapeSettings capsule_settings(c.capsule_half, c.thread_radius);
    capsule_settings.SetDensity(c.thread_density);
    capsule_settings.SetEmbedded();
    JPH::ShapeRefC capsule = capsule_settings.Create().Get();

    s.beads.resize((size_t)c.threads * c.beads);
    s.thread_of.resize(s.beads.size());
    s.index_in.resize(s.beads.size());
    s.tama.resize(c.threads);
    s.tama_joint.resize(c.threads);
    s.notch_of_thread.assign(c.threads, 0);
    s.notch_angle.assign(c.threads, 0.0f);

    for (int t = 0; t < c.threads && t < (int)kRestingNotches.size(); ++t) {
        const int notch = kRestingNotches[t].first;
        const float a = NotchAngle(notch);
        s.notch_of_thread[t] = notch;
        s.notch_angle[t] = a;
        const float cx = std::cos(a), cy = std::sin(a);
        const float r = c.thread_radius;

        // From the knot, up through the hole, out over the mirror, over the rim,
        // and down the outside. The thread rests on the mirror; nothing here
        // decides a height inside the braid.
        std::vector<JPH::Vec3> way;
        auto ring = [&](float radius, float z) { return JPH::Vec3(radius * cx, radius * cy, z); };
        way.push_back(ring(knot_radius * 0.95f, c.knot_depth + 0.8f));
        way.push_back(ring(c.hole_radius * 0.8f, c.knot_depth * 0.5f));
        way.push_back(ring(c.hole_radius * 0.9f, -c.mirror_thickness * 0.4f));
        way.push_back(ring(c.hole_radius + c.fillet + r, r));
        if (c.slack > 0.0f)
            way.push_back(ring(0.5f * (c.hole_radius + c.mirror_radius), r + c.slack));
        way.push_back(ring(c.mirror_radius - c.fillet, r));
        way.push_back(ring(c.mirror_radius + r, -c.fillet - r));

        float fixed = 0.0f;
        for (size_t i = 0; i + 1 < way.size(); ++i) fixed += (way[i + 1] - way[i]).Length();
        float hang = (float)(c.beads - 1) * c.bead_spacing - fixed;
        if (hang < c.bead_spacing) hang = c.bead_spacing;   // too few beads: reported by main
        way.push_back(ring(c.mirror_radius + r, -c.fillet - r - hang));

        // Bead 0 is the tama's end; the last bead is at the knot.
        std::reverse(way.begin(), way.end());
        std::vector<JPH::Vec3> at = Sample(way, c.bead_spacing, c.beads);

        for (int i = 0; i < c.beads; ++i) {
            JPH::Vec3 dir = (i + 1 < c.beads ? at[i + 1] - at[i] : at[i] - at[i - 1]);
            if (dir.Length() < 1e-6f) dir = JPH::Vec3::sAxisZ();
            JPH::BodyCreationSettings bcs(capsule, JPH::RVec3(at[i]),
                                          JPH::Quat::sFromTo(JPH::Vec3::sAxisY(), dir.Normalized()),
                                          JPH::EMotionType::Dynamic, Layers::MOVING);
            bcs.mCollisionGroup = JPH::CollisionGroup(s.filter, (JPH::CollisionGroup::GroupID)t,
                                                      (JPH::CollisionGroup::SubGroupID)i);
            bcs.mEnhancedInternalEdgeRemoval = true;
            if (c.damping >= 0.0f) {
                // Settling is quasi-static: damping only decides how long the
                // swinging takes, not where it comes to rest. A solver setting.
                bcs.mLinearDamping = c.damping;
                bcs.mAngularDamping = c.damping;
            }
            int k = s.BeadIndex(t, i);
            s.beads[k] = bi.CreateAndAddBody(bcs, JPH::EActivation::Activate);
            s.thread_of[k] = t;
            s.index_in[k] = i;
        }

        // The tama: a weight hanging on the end of the thread, over the rim.
        // Its pull is its mass in this world's gravity. Nothing is applied by hand.
        JPH::BodyCreationSettings ball(new JPH::SphereShape(2.0f),
                                       JPH::RVec3(at[0] - JPH::Vec3(0, 0, 2.5f)),
                                       JPH::Quat::sIdentity(), JPH::EMotionType::Dynamic,
                                       Layers::MOVING);
        ball.mOverrideMassProperties = JPH::EOverrideMassProperties::CalculateInertia;
        ball.mMassPropertiesOverride.mMass = c.tama_mass;
        if (c.damping >= 0.0f) { ball.mLinearDamping = c.damping; ball.mAngularDamping = c.damping; }
        s.tama[t] = bi.CreateAndAddBody(ball, JPH::EActivation::Activate);

        JPH::PointConstraintSettings joint;
        joint.mSpace = JPH::EConstraintSpace::WorldSpace;
        joint.mPoint1 = joint.mPoint2 = JPH::RVec3(at[0]);
        JPH::Ref<JPH::TwoBodyConstraint> made =
            bi.CreateConstraint(&joint, s.beads[s.BeadIndex(t, 0)], s.tama[t]);
        s.tama_joint[t] = made;
        s.system.AddConstraint(made);
    }

    // The chain: one point joint between neighbours, and the far end tied to the knot.
    for (int t = 0; t < c.threads; ++t) {
        for (int i = 0; i + 1 < c.beads; ++i) {
            JPH::BodyID a = s.beads[s.BeadIndex(t, i)];
            JPH::BodyID b = s.beads[s.BeadIndex(t, i + 1)];
            JPH::PointConstraintSettings joint;
            joint.mSpace = JPH::EConstraintSpace::WorldSpace;
            joint.mPoint1 = joint.mPoint2 = 0.5f * (bi.GetPosition(a) + bi.GetPosition(b));
            s.system.AddConstraint(bi.CreateConstraint(&joint, a, b));
        }
        JPH::BodyID end = s.beads[s.BeadIndex(t, c.beads - 1)];
        JPH::PointConstraintSettings joint;
        joint.mSpace = JPH::EConstraintSpace::WorldSpace;
        joint.mPoint1 = joint.mPoint2 = bi.GetPosition(end);
        s.system.AddConstraint(bi.CreateConstraint(&joint, end, s.knot));
    }

    s.system.OptimizeBroadPhase();
}

Settling Sim::Settle(float seconds) {
    Impl &s = *impl_;
    s.penetration.deepest = 0.0f;
    int steps = (int)std::lround(seconds / s.config.step);
    for (int i = 0; i < steps; ++i)
        s.system.Update(s.config.step, s.config.collision_steps, &s.temp, &s.job);

    Settling out;
    out.seconds = (float)steps * s.config.step;
    JPH::BodyInterface &bi = s.system.GetBodyInterface();
    double total = 0.0;
    for (JPH::BodyID id : s.beads) {
        float v = bi.GetLinearVelocity(id).Length();
        out.max_speed = std::max(out.max_speed, v);
        total += v;
        if (bi.IsActive(id)) ++out.awake;
    }
    out.mean_speed = s.beads.empty() ? 0.0f : (float)(total / (double)s.beads.size());
    out.max_penetration = s.penetration.deepest;
    return out;
}

void Sim::Play(const Move &move) {
    // Book C's hand: lift this thread's tama clear of the others, carry it over
    // the mirror, and put it down at the far notch. The carry is kinematic --
    // the hand moves the tama, the engine does everything else. Where the thread
    // ends up in the braid is not decided here; it falls out of the order.
    Impl &s = *impl_;
    const Config &c = s.config;
    int thread = -1;
    for (int t = 0; t < (int)s.notch_of_thread.size(); ++t)
        if (s.notch_of_thread[t] == move.from) thread = t;
    if (thread < 0) return;

    JPH::BodyInterface &bi = s.system.GetBodyInterface();
    JPH::BodyID id = s.tama[thread];
    const float from = NotchAngle(move.from), to = NotchAngle(move.to);
    const float rim = c.mirror_radius + c.thread_radius;
    JPH::RVec3 start = bi.GetPosition(id);
    auto over = [&](float angle, float lift) {
        return JPH::RVec3(rim * std::cos(angle), rim * std::sin(angle), lift);
    };

    bi.SetMotionType(id, JPH::EMotionType::Kinematic, JPH::EActivation::Activate);
    const int steps = std::max(1, (int)std::lround(c.carry_seconds / c.step));
    float sweep = to - from;
    while (sweep > kPi) sweep -= 2.0f * kPi;
    while (sweep < -kPi) sweep += 2.0f * kPi;
    for (int leg = 0; leg < 3; ++leg)
        for (int i = 1; i <= steps; ++i) {
            float u = (float)i / (float)steps;
            JPH::RVec3 target;
            if (leg == 0) target = start + (over(from, c.carry_lift) - start) * u;
            else if (leg == 1) target = over(from + sweep * u, c.carry_lift);
            else target = over(to, c.carry_lift) + (over(to, -c.fillet - c.thread_radius)
                                                   - over(to, c.carry_lift)) * u;
            bi.MoveKinematic(id, target, JPH::Quat::sIdentity(), c.step);
            s.system.Update(c.step, c.collision_steps, &s.temp, &s.job);
        }
    bi.SetMotionType(id, JPH::EMotionType::Dynamic, JPH::EActivation::Activate);
    s.notch_of_thread[thread] = move.to;
    s.notch_angle[thread] = to;
}

int Sim::BeadCount() const { return (int)impl_->beads.size(); }

void Sim::Positions(float *out) const {
    const JPH::BodyInterface &bi = impl_->system.GetBodyInterfaceNoLock();
    for (size_t i = 0; i < impl_->beads.size(); ++i) {
        JPH::RVec3 p = bi.GetPosition(impl_->beads[i]);
        out[3 * i + 0] = (float)p.GetX();
        out[3 * i + 1] = (float)p.GetY();
        out[3 * i + 2] = (float)p.GetZ();
    }
}

const std::vector<int> &Sim::ThreadOfBead() const { return impl_->thread_of; }
const std::vector<int> &Sim::IndexInThread() const { return impl_->index_in; }
const std::vector<int> &Sim::NotchOfThread() const { return impl_->notch_of_thread; }

float Sim::ThreadTension(int thread) const {
    if (thread < 0 || thread >= (int)impl_->tama_joint.size()) return 0.0f;
    JPH::TwoBodyConstraint *joint = impl_->tama_joint[thread];
    if (joint == nullptr) return 0.0f;
    JPH::Vec3 lambda = static_cast<JPH::PointConstraint *>(joint)->GetTotalLambdaPosition();
    // impulse / dt is a force; dividing by gravity puts it in gram-force.
    return lambda.Length() / impl_->config.step / impl_->config.gravity;
}

EngineDefaults Sim::Defaults() const {
    JPH::BodyCreationSettings fresh;
    JPH::PhysicsSettings settings;   // the engine's own defaults, not ours
    EngineDefaults out;
    out.friction = fresh.mFriction;
    out.restitution = fresh.mRestitution;
    out.penetration_slop = settings.mPenetrationSlop;
    out.speculative_contact_distance = settings.mSpeculativeContactDistance;
    out.baumgarte = settings.mBaumgarte;
    out.time_before_sleep = settings.mTimeBeforeSleep;
    return out;
}

}  // namespace braid
