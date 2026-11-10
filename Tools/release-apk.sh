#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
apk="Builds/ShadowFighting.apk"
: "${APK_DEVICE_VERIFIED:?Set only after installing and exercising this exact APK on Android}"
: "${APK_VERIFIED_SHA256:?Supply the SHA-256 of the APK actually tested on Android}"
[ "$APK_DEVICE_VERIFIED" = yes ]
[ -f "$apk" ]
actual_hash="$(sha256sum "$apk" | cut -d ' ' -f 1)"
[ "$actual_hash" = "$APK_VERIFIED_SHA256" ] || { printf 'APK differs from tested artifact\n' >&2; exit 1; }
size="$(stat -c %s "$apk")"
if [ "$size" -lt 425000000 ] || [ "$size" -gt 475000000 ]; then
  printf 'APK is %s bytes; requested approximately 450 MB of genuine content. Release blocked.\n' "$size" >&2
  exit 1
fi
: "${APK_SIGNATURE_VERIFIED:?Verify APK with Android apksigner, then set APK_SIGNATURE_VERIFIED=yes}"
[ "$APK_SIGNATURE_VERIFIED" = yes ]
[ "$(gh api user --jq .login)" = SenatorSeat66 ] || { printf 'Personal GitHub authentication required\n' >&2; exit 1; }
sha256sum "$apk" > Builds/SHA256SUMS
# Supply a reviewed release body file and a new explicit version tag.
: "${RELEASE_TAG:?Set a new release tag}"
: "${RELEASE_NOTES:?Set a path to the reviewed release notes}"
gh release create "$RELEASE_TAG" "$apk" Builds/SHA256SUMS --repo SenatorSeat66/Animefighting-sim --target "$(git rev-parse HEAD)" --title "Shadow Fighting $RELEASE_TAG" --notes-file "$RELEASE_NOTES"
