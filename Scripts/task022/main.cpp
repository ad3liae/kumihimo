// The harness. Reads a few settings from the command line, builds the seed,
// lets it stand, and writes every capsule centre out. It does not judge:
// Scripts/task021/ does that, through read_dump.py.
//
//     braid_on_stand --settle 8 --out .build/task022-dumps/seed.txt
//
// Task 022-1 stops here: the seed has to stand still before a hand is played.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "braid_sim.h"

int main(int argc, char **argv) {
    setvbuf(stdout, nullptr, _IOLBF, 0);   // so a long run shows itself as it goes
    braid::Config config;
    float settle = 8.0f;
    std::string out;
    int hands = 0;
    bool maru = false;

    for (int i = 1; i < argc; ++i) {
        auto next = [&]() { return (i + 1 < argc) ? argv[++i] : "0"; };
        if (!strcmp(argv[i], "--settle")) settle = (float)atof(next());
        else if (!strcmp(argv[i], "--out")) out = next();
        else if (!strcmp(argv[i], "--beads")) config.beads = atoi(next());
        else if (!strcmp(argv[i], "--knot-depth")) config.knot_depth = (float)atof(next());
        else if (!strcmp(argv[i], "--slack")) config.slack = (float)atof(next());
        else if (!strcmp(argv[i], "--takeup")) config.takeup_mass = (float)atof(next());
        else if (!strcmp(argv[i], "--tama")) config.tama_mass = (float)atof(next());
        else if (!strcmp(argv[i], "--fillet")) config.fillet = (float)atof(next());
        else if (!strcmp(argv[i], "--step")) config.step = (float)atof(next());
        else if (!strcmp(argv[i], "--damping")) config.damping = (float)atof(next());
        else if (!strcmp(argv[i], "--velocity-steps")) config.velocity_steps = atoi(next());
        else if (!strcmp(argv[i], "--position-steps")) config.position_steps = atoi(next());
        else if (!strcmp(argv[i], "--anticlockwise")) config.clockwise = false;
        else if (!strcmp(argv[i], "--hands")) hands = atoi(next());
        else if (!strcmp(argv[i], "--maru")) maru = true;
        else { fprintf(stderr, "unknown argument: %s\n", argv[i]); return 2; }
    }

    braid::Sim sim(config);
    braid::EngineDefaults defaults = sim.Defaults();
    // The engine's defaults, printed so they are recorded rather than chosen.
    printf("engine defaults  friction %.3f  restitution %.3f  slop %.4f  "
           "speculative %.4f  baumgarte %.3f  sleep-after %.3f\n",
           defaults.friction, defaults.restitution, defaults.penetration_slop,
           defaults.speculative_contact_distance, defaults.baumgarte, defaults.time_before_sleep);
    printf("settings  step %.5f  velocity %d  position %d  collision %d  gravity %.3f  "
           "beads %d  spacing %.2f  knot %.1f  slack %.2f  tama %.0f  takeup %.0f  "
           "fillet %.2f  damping %.3f  %s\n",
           config.step, config.velocity_steps, config.position_steps, config.collision_steps,
           config.gravity, config.beads, config.bead_spacing, config.knot_depth, config.slack,
           config.tama_mass, config.takeup_mass, config.fillet, config.damping,
           config.clockwise ? "clockwise" : "anticlockwise");

    sim.BuildSeed();
    printf("built  %d capsules\n", sim.BeadCount());
    fflush(stdout);

    // Settle in slices so a run that is going nowhere shows it while it runs.
    const float slice = 1.0f;
    braid::Settling last;
    for (float done = 0.0f; done < settle - 1e-4f; done += slice) {
        last = sim.Settle(std::min(slice, settle - done));
        printf("settled %5.1f   max speed %10.4f   mean %10.5f   awake %5d   "
               "deepest overlap %8.4f\n",
               done + slice, last.max_speed, last.mean_speed, last.awake, last.max_penetration);
        fflush(stdout);
    }
    printf("tension in the first segment, by thread (gram-force):");
    for (int t = 0; t < config.threads; ++t) printf(" %.0f", sim.ThreadTension(t));
    printf("\n");

    const auto &table = maru ? braid::kFig32 : braid::kFig20;
    for (int h = 0; h < hands; ++h) {
        sim.Play(table[h % table.size()]);
        braid::Settling after = sim.Settle(1.0f);
        printf("hand %3d  %2d -> %2d   max speed %10.4f   deepest overlap %8.4f\n",
               h, table[h % table.size()].from, table[h % table.size()].to,
               after.max_speed, after.max_penetration);
        fflush(stdout);
    }

    if (!out.empty()) {
        FILE *f = fopen(out.c_str(), "w");
        if (f == nullptr) { fprintf(stderr, "cannot write %s\n", out.c_str()); return 1; }
        fprintf(f, "# braid_on_stand  hands %d  beads %d  threads %d  step %.5f  "
                   "velocity %d  position %d  knot %.1f  slack %.2f  tama %.0f  takeup %.0f  "
                   "mirror %.1f hole %.1f fillet %.2f  %s\n",
                hands, config.beads, config.threads, config.step, config.velocity_steps,
                config.position_steps, config.knot_depth, config.slack, config.tama_mass,
                config.takeup_mass, config.mirror_radius, config.hole_radius, config.fillet,
                config.clockwise ? "clockwise" : "anticlockwise");
        fprintf(f, "# hand thread bead x y z   (lengths in thread diameters)\n");
        std::vector<float> p((size_t)sim.BeadCount() * 3);
        sim.Positions(p.data());
        const auto &thread_of = sim.ThreadOfBead();
        const auto &index_in = sim.IndexInThread();
        for (int i = 0; i < sim.BeadCount(); ++i)
            fprintf(f, "%d %d %d %.5f %.5f %.5f\n", hands, thread_of[i], index_in[i],
                    p[3 * i], p[3 * i + 1], p[3 * i + 2]);
        fclose(f);
        printf("wrote %s\n", out.c_str());
    }
    return 0;
}
