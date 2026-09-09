#!/bin/sh
# The derivation must not know the name of a braid.
#
# Everything under Kumihimo/Domain/Braiding/ works out a braid from a stand and a
# table of moves; Kumihimo/Features/BraidPattern/ draws that working-out flat and
# Kumihimo/Features/BraidView/ draws it solid. The tables themselves live outside
# them all (Kumihimo/Domain/BraidMethodCatalog.swift), so adding a braid is adding
# data. If a braid's name appears in any of them, that separation has been lost and
# the third braid will cost what the first two did.
#
# Kumihimo/Features/BraidSimulation/ joined the list at Task 025-4 step 4. It draws
# solid braids, and everything in it is now named for the family it draws -- sixteen
# threads flat, or sixteen in a tube -- rather than for a braid. The shape values it
# holds stayed exactly as they were; only the names moved.
#
# Still outside the list, and why: Kumihimo/Domain/ holds the per-braid data (the
# move tables, the colourings, the measured values) and that is where a braid's name
# belongs, plus HiraGenjiWeaveDerivation, which the flat drawing still asks for its
# arrival phases -- held on book A's clock by the author's ruling of 2026-09-09.
#
# Run from the repository root:
#     sh Scripts/check-braiding-is-general.sh

set -eu

directories="Kumihimo/Domain/Braiding Kumihimo/Features/BraidPattern Kumihimo/Features/BraidView Kumihimo/Features/BraidSimulation"
names="MaruGenji\|HiraGenji"

for directory in $directories; do
    if [ ! -d "$directory" ]; then
        echo "not found: $directory" >&2
        exit 2
    fi
    if grep -rn "$names" "$directory"; then
        echo >&2
        echo "A braid's name appears in $directory. Move the braid-specific part out" >&2
        echo "to Kumihimo/Domain/BraidMethodCatalog.swift and leave the working-out general." >&2
        exit 1
    fi
done

echo "$directories name no braid."
