#!/usr/bin/env bash
# Link the SwagBag addon folder into World of Warcraft (retail).
#   scripts/install.sh            show the plan, ask, then create the symlink
#   scripts/install.sh --yes      same, without asking
#   scripts/install.sh --copy     copy the folder instead of symlinking
#   scripts/install.sh --remove   remove the symlink/copy (SavedVariables are kept)
# Override the game location with:  WOW_DIR="/path/to/World of Warcraft" scripts/install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/SwagBag"
NAME="SwagBag"
MODE="link"
ASSUME_YES=0

for a in "$@"; do
	case "$a" in
		--yes|-y) ASSUME_YES=1 ;;
		--copy) MODE="copy" ;;
		--remove) MODE="remove" ;;
		-h|--help) sed -n '2,7p' "$0"; exit 0 ;;
		*) echo "Unknown option: $a"; exit 2 ;;
	esac
done

CANDIDATES=()
[ -n "${WOW_DIR:-}" ] && CANDIDATES+=("$WOW_DIR")
CANDIDATES+=("/Applications/World of Warcraft" "$HOME/Applications/World of Warcraft")
WOW=""
for c in "${CANDIDATES[@]}"; do
	if [ -d "$c/_retail_/Interface/AddOns" ]; then WOW="$c"; break; fi
done
if [ -z "$WOW" ]; then
	echo "Could not find '<World of Warcraft>/_retail_/Interface/AddOns'. Looked in: ${CANDIDATES[*]}"
	exit 1
fi
ADDONS="$WOW/_retail_/Interface/AddOns"
DEST="$ADDONS/$NAME"

if [ ! -f "$SRC/$NAME.toc" ]; then echo "Addon not found at: $SRC"; exit 1; fi

echo "Game AddOns folder : $ADDONS"
echo "SwagBag source     : $SRC"
case "$MODE" in
	link)   echo "Plan               : create symlink  $DEST  ->  $SRC" ;;
	copy)   echo "Plan               : copy folder to  $DEST" ;;
	remove) echo "Plan               : remove          $DEST  (SavedVariables are NOT touched)" ;;
esac

if [ -e "$ADDONS/SwagBagSpikes" ]; then
	echo "WARNING: the throwaway spike addon is still installed at $ADDONS/SwagBagSpikes."
	echo "         Remove it first:  \"$(dirname "$SRC")/spikes/install.sh\" --remove"
fi

if [ "$MODE" != "remove" ] && [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
	echo "A real folder named $NAME already exists there. Not touching it. Run: scripts/install.sh --remove"
	exit 1
fi
if [ "$MODE" = "link" ] && [ -L "$DEST" ] && [ "$(readlink "$DEST")" = "$SRC" ]; then
	echo "Already installed (symlink points here). Nothing to do."
	exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
	read -r -p "Proceed? [y/N] " ans
	case "$ans" in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 0 ;; esac
fi

case "$MODE" in
	link)   [ -L "$DEST" ] && rm "$DEST"; ln -s "$SRC" "$DEST"; echo "Done. Linked. Restart WoW or /reload." ;;
	copy)   [ -L "$DEST" ] && rm "$DEST"; cp -R "$SRC" "$DEST"; echo "Done. Copied. Restart WoW or /reload." ;;
	remove)
		if [ -L "$DEST" ]; then rm "$DEST"; echo "Symlink removed."
		elif [ -d "$DEST" ] && [ -f "$DEST/$NAME.toc" ]; then rm -r "$DEST"; echo "Copied folder removed."
		else echo "Nothing to remove."; fi
		;;
esac
