#!/usr/bin/env bash
# Upload the current SwagBag version to CurseForge.
#
#   scripts/release.sh [--type alpha|beta|release] [--dry-run] [--yes]
#
# What it does, in order (it stops at the first problem):
#   1. checks you are on main with nothing uncommitted (untracked files are ignored)
#   2. runs scripts/check.sh (syntax, luacheck, forbidden tokens, TOC, every test)
#   3. reads the version from SwagBag/SwagBag.toc and its notes from CHANGELOG.md ("## <version>")
#   4. builds dist/SwagBag-<version>.zip from the committed code (git archive)
#   5. reads the CurseForge token from the macOS Keychain (service "swagbag-curseforge"),
#      never from a file, an argument or the environment, and never prints it
#   6. maps the TOC's "## Interface:" numbers to CurseForge's Retail game versions
#   7. shows what it will upload and asks you to type "upload" (--yes skips the question)
#   8. uploads, prints the new file id, and tags the commit v<version> locally (nothing is pushed)
# --dry-run does steps 1-7 (the Keychain and the game-version lookup included) and uploads nothing.
#
# The project id comes from the TOC line "## X-Curse-Project-ID: <number>".
# Save the token once, in Terminal:  security add-generic-password -a "$USER" -s swagbag-curseforge -w
set -euo pipefail

SITE="https://wow.curseforge.com"
RETAIL_TYPE=517
KEYCHAIN_SERVICE="swagbag-curseforge"
TYPE="beta"
DRY=0
YES=0

while [ $# -gt 0 ]; do
	case "$1" in
		--type) TYPE="${2:-}"; shift 2 ;;
		--dry-run) DRY=1; shift ;;
		--yes) YES=1; shift ;;
		-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1 (try --help)"; exit 2 ;;
	esac
done
case "$TYPE" in alpha|beta|release) ;; *) echo "--type must be alpha, beta or release"; exit 2 ;; esac

cd "$(dirname "$0")/.."
fail() { echo "STOPPED: $*"; exit 1; }

# 1. A clean main ---------------------------------------------------------------------------------
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fail "not on main (git checkout main first)"
[ -z "$(git status --porcelain --untracked-files=no)" ] || fail "uncommitted changes; commit or stash them first"

# 2. Every check ----------------------------------------------------------------------------------
echo "Running scripts/check.sh ..."
scripts/check.sh > /tmp/swagbag-release-check.log 2>&1 || { tail -20 /tmp/swagbag-release-check.log; fail "checks failed (full log: /tmp/swagbag-release-check.log)"; }
tail -1 /tmp/swagbag-release-check.log

# 3. Version, project, changelog ------------------------------------------------------------------
TOC="SwagBag/SwagBag.toc"
VERSION="$(sed -n 's/^## Version:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$TOC" | head -1)"
PROJECT="$(sed -n 's/^## X-Curse-Project-ID:[[:space:]]*\([0-9]*\).*/\1/p' "$TOC" | head -1)"
INTERFACES="$(sed -n 's/^## Interface:[[:space:]]*//p' "$TOC" | head -1 | tr -d ' \r')"
[ -n "$VERSION" ] || fail "no ## Version in $TOC"
[ -n "$PROJECT" ] || fail "no '## X-Curse-Project-ID: <number>' line in $TOC"
[ -n "$INTERFACES" ] || fail "no ## Interface in $TOC"

[ -f CHANGELOG.md ] || fail "CHANGELOG.md is missing"
NOTES="$(awk -v v="## $VERSION" '
	$0 == v || index($0, v " ") == 1 { on = 1; next }
	on && /^## / { exit }
	on { print }
' CHANGELOG.md)"
[ -n "$(printf '%s' "$NOTES" | tr -d '[:space:]')" ] || fail "CHANGELOG.md has no notes under '## $VERSION'"

if git rev-parse -q --verify "refs/tags/v$VERSION" > /dev/null; then
	[ "$(git rev-list -n1 "v$VERSION")" = "$(git rev-parse HEAD)" ] || fail "tag v$VERSION already exists on another commit: bump the version first"
fi

# 4. The zip --------------------------------------------------------------------------------------
mkdir -p dist
ZIP="dist/SwagBag-$VERSION.zip"
git archive --format=zip -o "$ZIP" HEAD SwagBag
echo "Built $ZIP ($(unzip -l "$ZIP" | tail -1 | awk '{print $2}') files)"

# 5. The token (Keychain only) --------------------------------------------------------------------
TOKEN="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)" \
	|| fail "no CurseForge token in the Keychain. In Terminal run: security add-generic-password -a \"\$USER\" -s $KEYCHAIN_SERVICE -w"
# curl reads the header from stdin (-K -), so the token never shows in the process list.
cf() { printf 'header = "X-Api-Token: %s"\n' "$TOKEN" | curl -sS -K - "$@"; }

# 6. Game versions --------------------------------------------------------------------------------
VERSIONS_JSON="$(cf "$SITE/api/game/wow/versions" || true)"
if ! printf '%s' "$VERSIONS_JSON" | jq -e 'type == "array"' > /dev/null 2>&1; then
	VERSIONS_JSON="$(cf "$SITE/api/game/versions" || true)"
fi
printf '%s' "$VERSIONS_JSON" | jq -e 'type == "array"' > /dev/null 2>&1 \
	|| fail "CurseForge did not list its game versions (is the token right?): $(printf '%s' "$VERSIONS_JSON" | head -c 300)"

IDS=()
NAMES=()
IFS=',' read -r -a IFACES <<< "$INTERFACES"
for i in "${IFACES[@]}"; do
	[ -n "$i" ] || continue
	name="$(printf '%d.%d.%d' "$((10#${i:0:${#i}-4}))" "$((10#${i: -4:2}))" "$((10#${i: -2:2}))")"
	id="$(printf '%s' "$VERSIONS_JSON" | jq -r --arg n "$name" --argjson t "$RETAIL_TYPE" \
		'map(select(.gameVersionTypeID == $t and .name == $n)) | max_by(.id) | .id // empty')"
	if [ -z "$id" ]; then
		echo "Note: CurseForge has no Retail version named $name; it is left out."
		continue
	fi
	IDS+=("$id")
	NAMES+=("$name")
done
[ "${#IDS[@]}" -gt 0 ] || fail "none of the TOC's game versions ($INTERFACES) exist on CurseForge yet"
GAME_IDS="$(printf '%s\n' "${IDS[@]}" | jq -s -c 'unique')"

# 7. Show and ask ---------------------------------------------------------------------------------
echo
echo "Ready to upload to CurseForge project $PROJECT:"
echo "  File:          $ZIP"
echo "  Display name:  SwagBag $VERSION"
echo "  Release type:  $TYPE"
echo "  Game versions: ${NAMES[*]}"
echo "  Changelog:"
printf '%s\n' "$NOTES" | sed 's/^/    /'
echo

if [ "$DRY" = 1 ]; then
	echo "Dry run: nothing was uploaded."
	exit 0
fi
if [ "$YES" != 1 ]; then
	read -r -p "Type 'upload' to send it: " answer
	[ "$answer" = "upload" ] || fail "nothing was uploaded"
fi

# 8. Upload ---------------------------------------------------------------------------------------
METADATA="$(jq -n -c --arg c "$NOTES" --arg d "SwagBag $VERSION" --arg t "$TYPE" --argjson g "$GAME_IDS" \
	'{changelog: $c, changelogType: "markdown", displayName: $d, releaseType: $t, gameVersions: $g}')"
RESULT="$(mktemp)"
STATUS="$(printf '%s' "$METADATA" | {
	printf 'header = "X-Api-Token: %s"\n' "$TOKEN" > "$RESULT.cfg"
	curl -sS -K "$RESULT.cfg" -w '%{http_code}' -o "$RESULT" -F "metadata=<-" -F "file=@$ZIP" \
		"$SITE/api/projects/$PROJECT/upload-file"
	rm -f "$RESULT.cfg"
})" || true
rm -f "$RESULT.cfg"

if [ "$STATUS" = "200" ] && ! grep -q errorMessage "$RESULT"; then
	FILE_ID="$(jq -r '.id // empty' "$RESULT")"
	rm -f "$RESULT"
	git tag -f "v$VERSION" > /dev/null
	echo "Uploaded: SwagBag $VERSION ($TYPE), CurseForge file id $FILE_ID. Tagged v$VERSION locally."
	echo "CurseForge reviews new files before they go live; that usually takes minutes to hours."
else
	echo "Upload FAILED (HTTP $STATUS):"
	cat "$RESULT"; echo
	rm -f "$RESULT"
	exit 1
fi
