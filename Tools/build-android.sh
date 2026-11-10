#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
: "${UNITY_EDITOR:?Set UNITY_EDITOR to an activated Unity 6000.0.85f2 editor executable}"
"$UNITY_EDITOR" -batchmode -nographics -quit -projectPath "$project_dir" -executeMethod ShadowFighting.Editor.BuildAndroid.Build -logFile "$project_dir/Builds-build.log"
