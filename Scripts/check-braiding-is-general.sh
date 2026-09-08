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
# Kumihimo/Features/BraidSimulation/ is NOT watched yet. It holds the two frozen
# per-braid generators and the views around them, which Task 025-4 decides the fate
# of; adding it here today would fail on fifteen files that this stage is under
# instruction not to touch. It joins the list when they retire.
#
# Run from the repository root:
#     sh Scripts/check-braiding-is-general.sh

set -eu

directories="Kumihimo/Domain/Braiding Kumihimo/Features/BraidPattern Kumihimo/Features/BraidView"
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
