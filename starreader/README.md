<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0fc6e7f6bda3fb6082c0469df800fcac4c2d767ff6baca60864f93184cbb464e -->

# StarReader

An independent Flutter manga reader for Android. This project lives in `starreader/`; the repository’s Unity project is separate.

## Working features

- MangaDex catalogue search, popular/new/updated sorting, status filtering, language selection, chapter lists and source health checks.
- Private SQLite storage for library metadata, categories, favorites, progress, history, bookmarks and downloaded image bytes.
- CBZ import with natural page ordering, bounded file sizes and archive validation; local covers use the first page.
- Download queue with pause, resume, retry, batch enqueue and deletion. Interrupted transfers resume from completed pages.
- Horizontal and vertical paged reader, continuous webtoon scrolling, right-to-left direction, double-page spreads, pinch/double-tap zoom, page slider, chapter chooser, bookmarks and saved position.
- Android immersive mode, screen brightness, keep-awake and volume-key navigation.
- Light/dark/AMOLED themes, accent colors, grid density, batch library management, reading streaks, statistics and metadata backup/restore.

This is a first release with documented gaps, not complete Mihon feature parity. See [coverage and limitations](docs/coverage.md) and [architecture](docs/architecture.md).

## Build

Verified toolchain: Flutter stable 3.47.9, Dart 3.13.7, JDK 21, Android platform 36, Build Tools 36.0.0, NDK 28.2.13676358. Gradle may also install platform 35 for plugins and CMake 3.22.1. Use `flutter doctor -v` to check your installation.

Create your own private release keystore using Android `keytool`. Store the properties below outside this repository. Never commit or publicly upload the keystore or passwords.

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

Outputs: `build/app/outputs/flutter-apk/app-release.apk` and `build/app/outputs/bundle/release/app-release.aab`. The APK targets ARM64 only. The signing configuration fails if private release properties are absent; it does not silently use a debug key.

The task’s signing key is retained privately at `$HOME/.local/share/starreader-signing/`. Preserve this directory securely to sign compatible updates. It is excluded from source archives and releases.

## Development and tests

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run
# Optional browser preview, with browser-specific limitations documented below:
flutter build web --release
python3 -m http.server 8080 --directory build/web
# Live API diagnostic, no account or credentials:
dart run tools/probe_source.dart
```

Android is the intended persistent offline target. The web preview stores metadata in browser storage and page bytes in memory; refreshing loses imported/downloaded web page bytes. Browser traffic may receive a MangaDex bot challenge. StarReader respects source restrictions and reports the failure.

## Privacy and licensing

No analytics, advertising, account system or tracking SDK. Android uses only Internet permission; files are selected through the system picker. Automatic Android backup is disabled. MangaDex requests disclose the device IP to the source; covers and pages remain subject to their owners’ rights.

Original code and geometric StarReader artwork: Apache-2.0. Manrope: SIL Open Font License, included in `assets/fonts/OFL.txt`. Flutter Material icons are distributed through Flutter’s bundled licenses. Runtime manga artwork is retrieved from sources; no manga catalogue artwork is bundled or claimed as original. Read [source research and attribution](docs/sources.md).


<!-- /coderabbit-ai-generated:v1 -->