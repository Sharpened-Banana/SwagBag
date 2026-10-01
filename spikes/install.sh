#!/usr/bin/env bash
# =====================================================================
# THROWAWAY SPIKE helper: link the SwagBagSpikes test addon into WoW.
#
#   ./install.sh            show the plan, ask, then create the symlink
#   ./install.sh --yes      same, without asking
#   ./install.sh --copy     copy the folder instead of symlinking
#   ./install.sh --remove   remove the symlink/copy again (results file is kept)
#
# Override the game location with:  WOW_DIR="/path/to/World of Warcraft" ./install.sh
# =====================================================================
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/SwagBagSpikes"
NAME="SwagBagSpikes"
MODE="link"
ASSUME_YES=0

for a in "$@"; do
  case "$a" in
    --yes|-y) ASSUME_YES=1 ;;
    --copy) MODE="copy" ;;
    --remove) MODE="remove" ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a"; exit 2 ;;
  esac
done

# Find the game folder
CANDIDATES=()
[ -n "${WOW_DIR:-}" ] && CANDIDATES+=("$WOW_DIR")
CANDIDATES+=("/Applications/World of Warcraft" "$HOME/Applications/World of Warcraft")
WOW=""
for c in "${CANDIDATES[@]}"; do
  if [ -d "$c/_retail_/Interface/AddOns" ]; then WOW="$c"; break; fi
done
if [ -z "$WOW" ]; then
  echo "Could not find '<World of Warcraft>/_retail_/Interface/AddOns'."
  echo "Looked in: ${CANDIDATES[*]}"
  echo "Start WoW once so the folder exists, or run:  WOW_DIR=\"/path/to/World of Warcraft\" ./install.sh"
  exit 1
fi
ADDONS="$WOW/_retail_/Interface/AddOns"
DEST="$ADDONS/$NAME"

if [ ! -f "$SRC/$NAME.toc" ]; then
  echo "Spike addon not found at: $SRC"; exit 1
fi

echo "Game AddOns folder : $ADDONS"
echo "Spike addon source : $SRC"
case "$MODE" in
  link)   echo "Plan               : create symlink  $DEST  ->  $SRC" ;;
  copy)   echo "Plan               : copy folder to  $DEST" ;;
  remove) echo "Plan               : remove          $DEST  (your results in WTF/.../SavedVariables are NOT touched)" ;;
esac

if [ "$MODE" != "remove" ] && [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
  echo "A real folder named $NAME already exists there. Not touching it."
  echo "Remove it yourself or run: ./install.sh --remove"
  exit 1
fi
if [ "$MODE" = "link" ] && [ -L "$DEST" ] && [ "$(readlink "$DEST")" = "$SRC" ]; then
  echo "Already installed (symlink points here). Nothing to do."; exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  read -r -p "Proceed? [y/N] " ans
  case "$ans" in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 0 ;; esac
fi

case "$MODE" in
  link)
    [ -L "$DEST" ] && rm "$DEST"
    ln -s "$SRC" "$DEST"
    echo "Done. Linked."
    ;;
  copy)
    [ -L "$DEST" ] && rm "$DEST"
    cp -R "$SRC" "$DEST"
    echo "Done. Copied."
    ;;
  remove)
    if [ -L "$DEST" ]; then rm "$DEST"; echo "Symlink removed."
    elif [ -d "$DEST" ] && [ -f "$DEST/$NAME.toc" ]; then rm -r "$DEST"; echo "Copied folder removed."
    else echo "Nothing to remove."; fi
    ;;
esac

ACC_DIR="$WOW/_retail_/WTF/Account"
echo
echo "After testing, results will be in:"
for d in "$ACC_DIR"/*/; do
  [ -d "$d/SavedVariables" ] && echo "  ${d}SavedVariables/$NAME.lua"
done
