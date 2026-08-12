#!/bin/bash
# mochi installer.
#
#   ./install.sh
#
# Copies the pet into ~/.hammerspoon and tells you the one line to add to your
# init.lua. It does NOT edit your init.lua — that file is yours, and a script
# that rewrites a live Hammerspoon config is a script that eventually eats one.
#
# The browser extension is loaded by hand, once, from extension/ — see README.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HS_DIR="$HOME/.hammerspoon"

echo "==> Checking Hammerspoon"
if [ ! -d "/Applications/Hammerspoon.app" ]; then
  echo "    not found — install it with: brew install --cask hammerspoon"
  exit 1
fi
echo "    found"

echo "==> Installing the pet into $HS_DIR/mochi"
mkdir -p "$HS_DIR/mochi/assets"
cp "$REPO"/hammerspoon/mochi/*.lua   "$HS_DIR/mochi/"
cp "$REPO"/hammerspoon/mochi/pet.json "$HS_DIR/mochi/"

# Never clobber a sprite you replaced yourself.
if [ ! -f "$HS_DIR/mochi/assets/pet.png" ]; then
  cp "$REPO"/hammerspoon/mochi/assets/pet.png "$HS_DIR/mochi/assets/"
  echo "    sprite installed"
else
  echo "    sprite already present — left alone"
fi

echo
echo "==> Add this line to $HS_DIR/init.lua if it isn't there yet:"
echo
echo '    require("mochi")'
echo
echo "    then reload Hammerspoon (menu bar → Reload Config)."
echo
echo "==> Browser extension"
echo "    Comet/Atlas/Chrome → Extensions → Developer mode → Load unpacked"
echo "    → $REPO/extension"
