#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${STARREADER_SIGNING_PROPERTIES:?Set the path to your private release signing properties file}"
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
flutter build appbundle --release --target-platform android-arm64
