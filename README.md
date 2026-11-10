<!-- coderabbit-ai-generated:v1 -->

# Shadow Fighting

Unity **6000.0.85f2** Android combat prototype. **No APK has been produced.** Unity activation currently blocks project import, runtime verification, and Android compilation. This repository is a work in progress, not a polished release or a completed three-hour build.

## Current source

- Four enemy configurations with different anticipation, reach, and combo rhythms.
- Vitality, posture, timed guard/deflection, sweep jumps, thrust step counters, finishers, and a fire cooldown.
- Landscape touch controls, desktop controls, pause/resume, unlock persistence, and a short illustrated rules lesson.
- Five original Blender cutout characters with twelve poses each, four original landscape renders, and two original synthesized impact sounds.
- Editable `.blend` sources and reproducible generation scripts in `Tools/`.

The current visual assets and pose animation are prototype art. The lesson is explanatory screens, not an interactive tutorial. Fire has a combat effect and pose but lacks a dedicated flame animation. Music, richer animation, accessibility options, physical-device input verification, performance tuning, and game balancing are still outstanding.

## Run and build

1. Activate Unity 6000.0.85f2 through Unity Hub. Install its Android Build Support and matching SDK, NDK, and JDK.
2. Open this repository as a Unity project. Allow package import. Enter Play mode in an empty scene; the runtime bootstrap creates the game.
3. Desktop controls: A/D movement, J strike, K guard, Space jump, L step, I fire, Escape pause.
4. Build with the **Shadow Fighting → Build Android APK** editor menu, or:

```sh
UNITY_EDITOR=/path/to/Editor/Unity bash Tools/build-android.sh
```

The output path is `Builds/ShadowFighting.apk`. The build currently uses Unity's default Android signing setup; configure an owner-controlled signing key before a production release.

## Checks

```sh
UNITY_EDITOR=/path/to/Editor/Unity python3 Tools/check-source.py
bash -n Tools/build-android.sh Tools/release-apk.sh
```

The source checker compiles against installed Unity assemblies and runs engine-independent combat tests. It does **not** verify package import, rendering, touch controls, or Android execution.

## Regenerate original assets

```sh
blender -b --threads 2 --python Tools/create_art.py -- "$PWD"
# Pack each set of 12 rendered frames from /tmp/shadow-art/ into a 4×3 atlas with FFmpeg.
blender -b --threads 2 --python Tools/create_arenas.py -- "$PWD"
python3 Tools/create_audio.py
```

Blender 5.0.1 and FFmpeg were used in the sandbox. The authoring scripts write model sources into `Tools/` and game textures/audio into `Assets/Resources/`.

## Delivery gates

The user's requested APK is approximately 450 MB of genuine content. Current source art is much smaller; no padding is present. Before release, import and run in Unity, build successfully, verify APK signing, install and exercise the exact APK on Android, verify its actual size, and publish through the authenticated owner's GitHub account. `Tools/release-apk.sh` checks a tested artifact hash, confirmation of signature/device verification, and a 425–475 million byte range before uploading. That size range is a working interpretation of “around 450 MB,” not a measured result.

See [combat reference](docs/combat-reference.md) for observations, review coverage, and the differences between visible evidence and original game rules.
