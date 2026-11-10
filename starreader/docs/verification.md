<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ea419310e57ac4485cb06de7cc02d0cac61867b39b3c539332faae12d6862e53 -->

# Verification for StarReader 0.2.0

Verification date: 2026-11-10. Android device/emulator installation, launch, gestures, permission prompts and performance testing were explicitly left to the recipient. No device test is represented as passed.

## Executed checks

| Check | Observed result |
|---|---|
| `flutter analyze` | Passed, no issues after correcting one missing-braces lint |
| `flutter test --concurrency=2` | 50 tests passed |
| Native `:app:testDebugUnitTest` | 14 tests passed, zero failures/errors/skips, with the actual host JNI library and published extension JAR configured |
| Published extension live HTTP probe | MangaDex v1.6.4 loaded 62 sources and 12 filters; fetched 20 catalogue titles, 8 chapters, 12 pages and a 511,937-byte first image |
| Flutter release web build | Passed; phone 430×932 and tablet 1024×900 layouts inspected in shared Chromium |
| Browser interactions | Real local CBZ import/read, favorites, reader mode changes/resume, repository URL/trust/catalogue/search, history, downloads, themes, tags/notes, chapter batch read/unread, JSON backup export/merge and diagnostics export |
| Browser MangaDex requests | HTTP 403, shown as a recoverable source error; native extension HTTP probe succeeded |

Flutter coverage includes SQLite migration, metadata validation, source certificate rotation, 64-bit source IDs, chapter identity isolation, downloads/resume, CBZ preflight/checksum cleanup, header dimensions and bounded decoding, zoom/pan gesture ownership, long-strip restoration/completion, lazy large libraries/queues/history, startup recovery and enlarged text. Native coverage includes legacy Rx/suspend compatibility, published source API loading, source preference errors, QuickJS modern syntax/bytecode/callbacks/memory/time limits, foreground download lifecycle, WorkManager schedules and system-bar behavior on API 24/35/36 through Robolectric.

The combined native pass first exposed a test fixture retaining a previous Robolectric Application through a singleton. Resetting that test fixture restored isolation; the complete rerun passed. Earlier reader tests also found and fixed premature long-strip completion and narrow-toolbar overflow. These are recorded repairs, not hidden failures.

After the final copy/contrast/accent-picker changes, `flutter analyze` passed and `flutter test test/release_ui_test.dart test/refinement_test.dart test/widget_test.dart --concurrency=2` passed all 21 affected tests; the remaining 50-test baseline and native checks are reused when inputs are unchanged. Release assets include the final machine-readable test/artifact reports and checksums.

## Reproduce native tests without a device

Use the README toolchain and private signing configuration. Run a Flutter Android build first so Flutter prepares the ignored Gradle wrapper and generated Android files. On a Linux host with CMake, a C/C++ compiler and JDK 21:

```sh
cmake -S android/app/src/main/cpp -B /tmp/starreader-quickjs-host -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/starreader-quickjs-host --parallel 2
export STARREADER_QUICKJS_HOST_LIB=/tmp/starreader-quickjs-host
export STARREADER_EXTENSION_JAR=/absolute/path/tachiyomi-all.mangadex-v1.6.4.jar
android/gradlew -p android :app:testDebugUnitTest
```

The published fixture is available from the [Keiyoushi extension release](https://github.com/keiyoushi/extensions/releases/download/d9420cd/tachiyomi-all.mangadex-v1.6.4.jar). Verify its SHA-256 before running it:

`6bba080add3f0ce25622523996bec22bd4828d6fecfbd2b816d420d8af49cb86`

The corresponding APK SHA-256 is `611bd20d91cdd4152b6d976081cc0cd4651208f7a153ddbef133f4ebba1688c3`; its publisher certificate matches the repository certificate. No extension APK or manga pages are bundled with StarReader.

To opt into the network probe:

```sh
STARREADER_LIVE_EXTENSION_PROBE=1 android/gradlew -p android :app:testDebugUnitTest --tests '*ExtensionContractTest' --rerun-tasks
```

Without the two fixture environment variables, the QuickJS/published-JAR tests explicitly skip. Such a run is not equivalent to the 14-test zero-skip release run. Robolectric API 36 needs the test-only `java.base/jdk.internal.access` module opening already configured in Gradle. The host library executes the same vendored C/C++ engine on x86-64; this does not prove ARM64 JNI behavior on a phone.

## Release artifact inspection

```sh
python3 tools/verify_release.py build/app/outputs/flutter-apk/app-release.apk \
  --build-tools "$ANDROID_SDK_ROOT/build-tools/36.0.0" \
  --certificate 12213f4c89365461a009f6dd6a7b534f44390ee341e800f386e6a574d29ad5f1
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
```

The verifier checks release metadata, absence of the debuggable flag/debug certificate, APK v2 signature, ARM64-only libraries, QuickJS presence, ELF load alignment and 16 KiB ZIP alignment. A self-signed release certificate is expected for an independently distributed Android app. The final ARM64 APK passed all verifier checks. The App Bundle passed `jarsigner -verify`, certificate comparison and [Google bundletool 1.18.3](https://github.com/google/bundletool/releases/tag/1.18.3) `validate`. AGP initially placed the JAR manifest late in the ZIP; `tools/normalize_bundle.py` moved it first while comparing SHA-256 for all 542 entry contents. The JarInputStream ordering warning disappeared and the original signature remained valid. Expected self-signed-certificate/no-timestamp warnings remain. Artifact verification does not replace installation testing.

## Visual evidence and limits

Screenshots show actual Flutter browser screens with original geometric CBZ verification artwork clearly labeled as test art. The artwork is not a catalogue title and is not preloaded in the application. Native extension installation, source preference Activities, system bars, notifications and background lifecycle are not available in the web preview. Browser page bytes are in memory; Android uses SQLite persistence.

No physical-device 60/90/120 FPS claim, long-session memory/leak certification, universal extension compatibility, external tracker/cloud backup support, or complete translation/accessibility audit is made. See [coverage](coverage.md) and [migration notes](release-0.2.0.md).


<!-- /coderabbit-ai-generated:v1 -->