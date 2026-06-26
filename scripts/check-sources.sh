#!/usr/bin/env bash
# check-sources.sh — fetch latest upstream versions and compare against source-pins.json
set -e

PINS_FILE="sources/source-pins.json"

_curl() { curl -s --retry 3 --retry-delay 2 "$@" || echo ""; }
_pin()  { jq -r ".${1} // \"unknown\"" "$PINS_FILE" 2>/dev/null || echo "unknown"; }

echo "=== Fetching upstream sources ==="

KSUN_TAG=$(_curl "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" \
  | jq -r '.[0].name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$KSUN_TAG" ] && KSUN_TAG="unknown"
echo "KSU-Next     : $KSUN_TAG"

SUKI_TAG=$(_curl "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
  | jq -r '.tag_name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$SUKI_TAG" ] && SUKI_TAG="unknown"
echo "SukiSU-Ultra : $SUKI_TAG"

SUSFS_TAG=$(_curl "https://api.github.com/repos/sidex15/susfs4ksu-module/tags" \
  | jq -r 'if type=="array" and length>0 then .[0].name else "unknown" end' 2>/dev/null \
  || echo "unknown")
[ -z "$SUSFS_TAG" ] && SUSFS_TAG="unknown"
echo "SUSFS module : $SUSFS_TAG"

VILI_RAW=$(_curl \
  "https://raw.githubusercontent.com/Santhanabalan/android_kernel_xiaomi_sm8350/main/Makefile")
VILI_SUB=$(echo "$VILI_RAW" | awk -F' *= *' \
  '/^VERSION /    {v=$2}
   /^PATCHLEVEL / {p=$2}
   /^SUBLEVEL /   {s=$2}
   END { if(v && p && s) print "v"v"."p"."s; else print "unknown" }')
VILI_SUB="${XIAOMI_SUB:-unknown}"
echo "Vili SM8350: $XIAOMI_SUB"

echo ""
echo "=== Comparing against source-pins.json ==="

PIN_VILI=$(_pin "vili_sublevel")
PIN_KSUN=$(_pin "ksun_tag")
PIN_SUKI=$(_pin "suki_tag")
PIN_SUSFS=$(_pin "susfs_tag")

UPDATES=()
[ "$VILI_SUB"   != "$PIN_VILI"   ] && UPDATES+=("Vili: ${PIN_XIAOMI} → ${VILI_SUB}")
[ "$KSUN_TAG"   != "$PIN_KSUN"   ] && UPDATES+=("KSU-Next: ${PIN_KSUN} → ${KSUN_TAG}")
[ "$SUKI_TAG"   != "$PIN_SUKI"   ] && UPDATES+=("SukiSU: ${PIN_SUKI} → ${SUKI_TAG}")
[ "$SUSFS_TAG"  != "$PIN_SUSFS"  ] && UPDATES+=("SUSFS: ${PIN_SUSFS} → ${SUSFS_TAG}")

if [ ${#UPDATES[@]} -gt 0 ]; then
  echo "Updates detected:"
  for U in "${UPDATES[@]}"; do echo "  • $U"; done
  HAS_UPDATE="true"
  UPDATE_DETAIL=$(printf '%s\n' "${UPDATES[@]}")
else
  echo "All sources up to date."
  HAS_UPDATE="false"
  UPDATE_DETAIL=""
fi

{
  echo "CHECK_KSUN_TAG=$KSUN_TAG"
  echo "CHECK_SUKI_TAG=$SUKI_TAG"
  echo "CHECK_SUSFS_TAG=$SUSFS_TAG"
  echo "CHECK_VILI_SUB=$VILI_SUB"
  echo "HAS_UPDATE=$HAS_UPDATE"
  echo "UPDATE_DETAIL<<EOF"
  echo "$UPDATE_DETAIL"
  echo "EOF"
} >> "${GITHUB_ENV:-/dev/null}"

echo "=== Done ==="
