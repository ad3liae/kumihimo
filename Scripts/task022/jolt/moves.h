// Book C's tables, copied from Scripts/task021/braid_geometry.py, which took
// them from the source of record. One entry is one thread moving from one notch
// to another; a row of four is read left to right, and the rows top to bottom.
//
// The names below select an input. Nothing in braid_sim.cpp reads them: the
// stand, the threads and the hands work off the table alone. Same rule as
// Scripts/check-braiding-is-general.sh keeps in the app.
#pragma once

#include <array>

namespace braid {

struct Move { int from; int to; };

// Fig.20 -- 24 hands: twelve braiding, twelve tidying.
inline constexpr std::array<Move, 24> kFig20 = {{
    {9, 28}, {14, 27}, {30, 11}, {25, 12},
    {18, 4}, {21, 3}, {5, 18}, {2, 21},
    {17, 5}, {22, 2}, {6, 17}, {1, 22},
    {29, 30}, {28, 29}, {26, 25}, {27, 26},
    {10, 9}, {11, 10}, {13, 14}, {12, 13},
    {2, 1}, {3, 2}, {5, 6}, {4, 5},
}};

// Fig.32 -- 24 hands: eight braiding, sixteen tidying.
inline constexpr std::array<Move, 24> kFig32 = {{
    {17, 4}, {22, 3}, {6, 19}, {1, 20},
    {9, 28}, {14, 27}, {30, 11}, {25, 12},
    {2, 1}, {3, 2}, {5, 6}, {4, 5},
    {21, 22}, {20, 21}, {18, 17}, {19, 18},
    {29, 30}, {28, 29}, {26, 25}, {27, 26},
    {10, 9}, {11, 10}, {13, 14}, {12, 13},
}};

// The sixteen notches a thread rests on, and the stand position each is.
// notch -> position 1..16.
inline constexpr std::array<std::pair<int, int>, 16> kRestingNotches = {{
    {1, 15}, {2, 16}, {5, 1}, {6, 2}, {9, 3}, {10, 4}, {13, 5}, {14, 6},
    {17, 7}, {18, 8}, {21, 9}, {22, 10}, {25, 11}, {26, 12}, {29, 13}, {30, 14},
}};

inline constexpr int kNotches = 32;

}  // namespace braid
