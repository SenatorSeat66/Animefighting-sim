<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:84b80db6195b0f9202e8ab7aa1a494a7726ed6a7d77c2e4ffcea0780604f19e7 -->

<!-- coderabbit-ai-generated-section:v1:ae3b796e4850a070875b9a002cf4c9e56a47b64d4b3662ebf57715b80a40dae7 -->

# StarReader 0.2.0

An independent Flutter manga reader for Android, with an original reading-room interface and a native Mihon extension host. This application lives in `starreader/`; the repository's Unity project is separate.

## Read, collect, discover

- Add a Mihon protobuf extension repository, explicitly trust its publisher certificate, install signed extensions, choose a source, and search real catalogues. Source settings, filters, language selection, update detection and manual website login are available.
- A direct MangaDex adapter and local CBZ import work independently of extensions. Cross-source search queries selected installed sources with bounded concurrency.
- SQLite persists collections, tags, notes, favorites, history, page bookmarks, reader profiles, download jobs and offline page bytes. The library supports selection, batch actions, multiple collections, progress/source/download filters, sorting and duplicate-title detection.
- A custom immersive reader supports horizontal/vertical paging, continuous/webtoon reading, RTL, spreads, pinch/double-tap zoom, scaling, margins, backgrounds, tap zones, brightness, keep-awake, volume navigation and exact continuous reading-position restoration.
- Persistent downloads support priorities, pause/resume/retry, batch selection and an Android foreground notification. Optional WorkManager library checks discover fresh chapters on a 6/12/24/72-hour schedule, subject to Android scheduling.
- Light, dark and AMOLED themes, accent colors, original typography, responsive layouts, grid density/ratios/spacing, enlarged text and reduced motion.
- Validated StarReader metadata backup/restore and standard Mihon/Tachiyomi protobuf metadata import. Original CBZs and downloaded page bytes are not included in metadata backups.

See [feature coverage and limitations](docs/coverage.md), [architecture](docs/architecture.md), [extension setup and licensing](docs/sources.md), and [release and migration notes](docs/release-0.2.0.md). Compatibility is tested against a published extension, not guaranteed for every extension or website.

## Android build

Verified toolchain: Flutter stable **3.47.9**, Dart **3.13.7**, JDK **21.0.13**, Android platform package **platforms;android-37.0**, Build Tools **36.0.0**, NDK **28.2.13676358**, CMake **3.22.1**, Gradle **9.3.1**. Compile SDK 37, target SDK 36, minimum SDK 24 (Android 7). Native code targets **arm64-v8a** only. QuickJS is built from the included source with the NDK; no separately downloaded engine binary is used.

Install Flutter and Android tooling, accept Android SDK licenses, and run `flutter doctor -v`. Flutter generates the ignored local Gradle wrapper/platform configuration during normal project setup. Preserve `pubspec.lock` and the pinned Android dependency versions.

Create a private release keystore with Android `keytool`. Put the following properties outside this repository:

```properties
storeFile=/absolute/private/path/starreader-release.jks
storePassword=YOUR_PRIVATE_PASSWORD
keyAlias=starreader
keyPassword=YOUR_PRIVATE_PASSWORD
```

```sh
export STARREADER_SIGNING_PROPERTIES=/absolute/private/path/release.properties
bash tools/build_release.sh
```

The script runs dependency resolution, analysis, Flutter tests and release APK/AAB builds. It then normalizes App Bundle manifest ordering without changing signed entry contents and verifies its JAR signature; Python3 and the JDK `jarsigner` command are required. Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

Release signing fails when the private configuration is missing; it never falls back to the debug key. The release key for this task is retained in the private sandbox signing directory, outside Git and public release assets. Keep a secure private copy for future updates.

## Development and verification

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --concurrency=2
flutter run
# Browser UI preview:
flutter build web --release
python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web
# Optional live direct-source diagnostic:
dart run tools/probe_source.dart
```

[Native verification](docs/verification.md) describes JVM contract tests, the source-built JavaScript runtime and release artifact checks. Android device testing is left to the release recipient; compilation and JVM tests do not establish device performance.

Android is the offline persistence target. The web preview stores metadata in browser storage and page bytes in memory; refreshing loses imported/downloaded web pages. Native extension execution, background work and Android reader controls are unavailable in the browser. Source websites may reject browser traffic; errors are displayed without bypassing access restrictions.

## Privacy and licenses

No advertising, telemetry or tracking SDK. Files are selected through the system picker; no broad storage permission is requested. Internet, foreground data-sync service, wake-lock and optional notification permissions support reading and downloads. WorkManager contributes normal network/boot scheduling permissions. Automatic Android backup is disabled.

Extensions are executable third-party code running with the app's privileges. Trust only publishers you accept. Repository URLs and certificate trust require explicit user action; backups do not silently install or trust extensions. Source requests disclose your IP address to the source. Source settings and cookies remain in private app storage; exported metadata is unencrypted and may include reading history.

Original StarReader code and geometric artwork: Apache-2.0. Mihon/Tachiyomi API code and QuickJS bindings retain their license notices. QuickJS is MIT; Manrope and Newsreader are SIL OFL. See `LICENSE`, `assets/licenses/`, `assets/provenance.json`, `third_party/quickjs/` and the in-app license viewer. No manga catalogue artwork is bundled.


<!-- /coderabbit-ai-generated:v1 -->