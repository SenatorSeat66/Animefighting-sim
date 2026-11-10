<!-- coderabbit-ai-generated:v1 -->

# Architecture and data contracts

## Modules

- `core/models.dart`: immutable manga/chapter records and the `MangaSource` adapter contract.
- `core/source.dart`: MangaDex HTTPS API adapter; pagination, metadata mapping, chapter language filtering, page URL resolution, timeouts and explicit HTTP failures.
- `core/storage.dart`: SQLite schema version 1. `state` holds an atomic JSON metadata snapshot; `pages` stores downloaded image BLOBs keyed by chapter/page. The schema version is managed with SQLite `user_version`. Future relational migrations need an explicit `onUpgrade` migration before increasing the version.
- `core/library.dart`: ChangeNotifier application state, serialized persistence, library operations, progress, download worker, CBZ validation, versioned backup and restore.
- `reader.dart`: lazy Flutter page views/positioned scrolling, image loading, zoom and Android control bridge.
- `main.dart`, `enhancements.dart`: Material 3 based design system, responsive navigation and application screens.
- Android `MainActivity.kt`: only brightness, awake state and volume navigation. Leaving the reader resets these controls.

## Source adapter contract

A `MangaSource` exposes a stable id/name, paginated `search`, ordered `chapters`, ordered HTTPS `pages`, and `health`. Register a new reviewed adapter in the application’s dependency construction. The interface does not execute external code. A source must respect remote access restrictions and return actual metadata; unsupported or missing chapters produce explicit empty states.

MangaDex uses `/manga`, `/manga/{id}/feed` and `/at-home/server/{id}`. Source chapters without actual pages and externally hosted chapters are excluded. Chapter requests are capped at 10,000 entries. The API owns titles, artwork and availability. No authentication or scraping bypass is implemented.

## Download semantics

A single worker processes persistent jobs. State transitions: queued → downloading → complete; downloading → paused/failed. Each completed page is written before progress is advanced. Resume checks stored pages, fetching only missing ones. On restart an in-flight job becomes paused. Deletion pauses a job and waits for its in-flight transfer before removing bytes. Page requests require HTTPS, a successful response, supported image signatures and a 40 MB encoded-size bound. Downloads run while the process is alive; no foreground Android service is claimed.

## Reader memory

Pages are loaded lazily. The shared Flutter image cache is bounded to 96 MB. Android inspects encoded image dimensions before decode and caps decoded pages to 8 million pixels and 2,048 pixels wide. This trades maximum zoom detail for stability on very long pages. Web preview uses a 1,024-pixel decode width because Flutter web does not expose encoded descriptor dimensions. These limits are not a substitute for a measured device stress test.

## Backups and imports

StarReader JSON envelope: `format: starreader`, `version: 1`, `data`. Export excludes downloaded image bytes. Import is capped at 20 MB, checks record types and supported settings, validates cover hosts, and validates the whole candidate before merging. Existing downloads are retained. Collections are merged; matching metadata keys are replaced. Save failures restore in-memory state. Settings are restored only from a validated allowlist.

CBZ import accepts at most 250 MB compressed, 750 MB total expanded images, 1,500 image entries and 40 MB per image. Files are read as bytes and stored in SQLite; archive paths are never extracted to disk. Local imports use naturally sorted image names. Re-importing the same archive creates another local volume; content fingerprint deduplication is not implemented.

## Privacy boundaries

There is no telemetry. No broad storage permission is requested. Database files live in private application storage. JSON backups are unencrypted user exports and may contain reading history. Signing keys remain outside the repository. No arbitrary extension APK or remote script is loaded.
