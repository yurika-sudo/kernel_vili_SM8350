#!/usr/bin/env bash
# release-notes.sh — generate release body
set -e

: "${BUILD_TYPE:-stable}"
: "${RUN_URL:?}"
: "${REPO:?}"
: "${SHA:?}"

SHORT_SHA="${SHA:0:9}"
COMMIT_URL="https://github.com/${REPO}/commit/${SHA}"
BODY=""

if [ "$BUILD_TYPE" = "testing" ]; then
  BODY="${BODY}> [!WARNING]"$'\n'
  BODY="${BODY}> Testing build — debug stripped, perf/sched configs non-default. Expect rough edges."$'\n\n'
fi

BODY="${BODY}**KSU-Next Manager:** [CI Build ↗](${KSUN_MANAGER_URL})"$'\n'
BODY="${BODY}**SukiSU Manager:** [CI Build ↗](${SUKI_MANAGER_URL})"$'\n'
BODY="${BODY}**SUSFS module:** [${SUSFS_VERSION}](${SUSFS_MODULE_URL})"$'\n'
BODY="${BODY}**Kernel base:** \`${KERNEL_VERSION}\`"$'\n\n'

BODY="${BODY}**Variants:** Xiaomi (KSU-Next · SukiSU · NoKSU)"$'\n'
BODY="${BODY}**Device:** Xiaomi Mi 11T Pro (vili)"$'\n'
BODY="${BODY}**ROM:** AOSP / LineageOS-based recommended"$'\n'
BODY="${BODY}**Issues:** [t.me/home_yu_chat](https://t.me/home_yu_chat) · Critical → PM directly"$'\n\n'

BODY="${BODY}> [!IMPORTANT]"$'\n'
BODY="${BODY}> **Manager version must match kernel version.** Can't grant root / manager shows errors? Use the **CI Build** links above — not stable releases. Mismatch = can't grant root."$'\n\n'

BODY="${BODY}**Commit:** [\`${SHORT_SHA}\`](${COMMIT_URL})"$'\n'
BODY="${BODY}📋 **Per-build details:** [Run #${GITHUB_RUN_NUMBER} summary](${RUN_URL})"$'\n'
BODY="${BODY}> Full build logs in \`build-audit-logs-*.zip\` below."

{
  echo "RELEASE_BODY<<EOREL"
  echo "$BODY"
  echo "EOREL"
} >> "${GITHUB_ENV:-/dev/null}"

echo "[OK] Release body generated"
