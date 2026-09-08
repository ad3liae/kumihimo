// Braiding on the stand: the stand, the threads, the weights and the hands.
//
// This file and braid_sim.cpp are the core. They open no files, print nothing
// and hold no global state, so Task 022-4 can call them from Swift through C++
// interop and get the same engine the harness used. main.cpp is the harness:
// command line in, positions out.
//
// UNITS. Length is one thread diameter d (docs/architecture.md, "丸台の寸法と錘").
// Mass is one gram. Time is chosen so that gravity is 9.81 in these units --
// with d = 2 mm that makes one unit of time 44.7 ms. The choice is a unit
// choice, not a model constant: every force here is a mass times this one
// gravity, so the ratios the braid actually feels are untouched.
#pragma once

#include <cstdint>
#include <memory>
#include <vector>

#include "moves.h"

namespace braid {

struct Config {
    // The stand. From docs/architecture.md "丸台の寸法と錘（作者の決定）",
    // divided by d = 2 mm. Not fitted, not measured from a photograph.
    float mirror_radius = 62.5f;      // 25 cm across
    float hole_radius = 7.5f;         // 3 cm across
    float mirror_thickness = 10.0f;   // 2 cm. NOT given by the author -- recorded as a setting
    float fillet = 1.0f;              // the rounding of both rims. A setting
    int rim_segments = 96;            // how finely the mirror is tessellated. A setting

    // The weights, in grams. The author's default for a sixteen-thread braid.
    float tama_mass = 100.0f;         // one bobbin
    float takeup_mass = 570.0f;       // 190 g x 3
    float thread_density = 0.0104f;   // silk 1.3 g/cm^3, in g per d^3 at d = 2 mm

    // The threads.
    int threads = 16;
    int beads = 240;                  // long enough to reach from the knot to the hanging tama
    float bead_spacing = 1.0f;
    float thread_radius = 0.5f;       // d / 2
    float capsule_half = 0.25f;       // half the cylinder; total capsule length 1.5 d

    // The seed: the braid is started the way it is started on a real stand.
    // The only things chosen here are the knot's depth and the initial slack,
    // which are the two seeds Task 016's test asks for.
    float knot_depth = -20.0f;
    float slack = 0.0f;

    // Which way the notch numbers run round the rim. Undecided -- it is the
    // maru-genji E/W question itself. Both are run and treated as mirrors.
    bool clockwise = true;

    // Solver settings. NOT model constants. Recorded and held fixed.
    //
    // A thread capsule weighs 0.0094 g and a tama 100 g, a ratio of about 10^4,
    // and a sequential-impulse solver cannot hold a chain across that: the links
    // came out 12-22% long under the real weights (Task 022-1). `inertia`
    // multiplies the capsules' mass, and their gravity factor is divided by the
    // same number, so **every capsule still weighs 0.0094 gf** -- only its
    // inertia grows. Nothing the braid feels changes; what changes is how well
    // the solver holds it. Run two values and the answer must be the same.
    float inertia = 1.0f;
    float gravity = 9.81f;
    float damping = -1.0f;          // < 0 keeps the engine's own default (0.05)
    float step = 1.0f / 120.0f;
    int collision_steps = 1;
    int velocity_steps = 20;
    int position_steps = 4;

    // The hands (Task 022-2). Not used while only the seed is settled.
    float carry_lift = 8.0f;          // how high above the mirror a tama is carried
    float carry_seconds = 0.6f;
};

struct Settling {
    float seconds = 0.0f;
    float max_speed = 0.0f;           // the fastest bead, in d per unit time
    float mean_speed = 0.0f;
    int awake = 0;                    // bodies Jolt has not put to sleep
    float max_penetration = 0.0f;     // deepest overlap found, in d
    float mean_stretch = 0.0f;        // link length over its rest length, averaged
    float max_stretch = 0.0f;         // the longest link, the same way
};

// What the engine's own defaults are, read out of the engine rather than set
// here. Recorded in the report; never tuned.
struct EngineDefaults {
    float friction = 0.0f;
    float restitution = 0.0f;
    float penetration_slop = 0.0f;
    float speculative_contact_distance = 0.0f;
    float baumgarte = 0.0f;
    float time_before_sleep = 0.0f;
};

class Sim {
public:
    explicit Sim(const Config &config);
    ~Sim();

    Sim(const Sim &) = delete;
    Sim &operator=(const Sim &) = delete;

    // The seed: knot below the hole with the take-up on it, threads laid out
    // radially, tama hooked over the rim at their notch.
    void BuildSeed();

    // Let it stand still. Returns how still it got.
    Settling Settle(float seconds);

    // One of book C's hands: lift this thread's tama, carry it over the mirror,
    // put it down at the far notch. Written for 022-2; not called by 022-1.
    void Play(const Move &move);

    int BeadCount() const;
    // Three floats a bead, in d, in the stand's frame (mirror at z = 0, the
    // braid growing towards -z).
    void Positions(float *out_xyz) const;
    const std::vector<int> &ThreadOfBead() const;
    const std::vector<int> &IndexInThread() const;
    // Where each thread's tama is resting now, as a book C notch.
    const std::vector<int> &NotchOfThread() const;

    float ThreadTension(int thread) const;   // the pull in the first segment, in gram-force
    EngineDefaults Defaults() const;

    // Angle of a book C notch on the rim, in radians.
    float NotchAngle(int notch) const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

}  // namespace braid
