#!/bin/sh
# The derivation must not know the name of a braid.
#
# Everything under Kumihimo/Domain/Braiding/ works out a braid from a stand and a
# table of moves. The tables themselves live outside it (Kumihimo/Domain/
# BraidMethodCatalog.swift), so adding a braid is adding data. If a braid's name
# appears inside the derivation, that separation has been lost and the third braid
# will cost what the first two did.
#
# Run from the repository root:
#     sh Scripts/check-braiding-is-general.sh

set -eu

directory="Kumihimo/Domain/Braiding"
names="MaruGenji\|HiraGenji"

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

echo "$directory names no braid."
