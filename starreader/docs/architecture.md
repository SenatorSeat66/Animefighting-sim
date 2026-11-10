<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:b3985bf296e2d25450d98511bf29948fb4e8b6a4eb3048030852af427cdbbbbc -->

<!-- coderabbit-ai-generated-section:v1:5f497e9e3835ad41655d93059b12da502ac3d6c3a6203abc997355fe808013f8 -->

# Architecture and persistence contracts

## Application layers

| Layer | Responsibility |
|---|---|
| `core/models.dart`, `core/source.dart` | Manga/chapter contracts and direct MangaDex HTTPS adapter |
| `core/extension_repository.dart`, `core/extensions.dart` | Bounded protobuf catalogue parsing, explicit certificate trust, native bridge, source adapters |
| `core/storage.dart` | SQLite schema 2: atomic JSON `state`, downloaded image BLOB `pages`, separate `cache`; non-destructive v1 migration |
| `core/library.dart`, `library_query.dart` | Persisted library/queue/progress, serial writes, filters and batch operations |
| `core/mihon_backup.dart`, `file_input.dart`, `archive_input*` | Validated metadata migration, bounded file selection and streaming native CBZ input |
| `reader.dart`, `reader_preferences.dart`, `page_cache.dart`, `image_dimensions.dart`, `thumbnail_cache.dart` | Reader state, profiles, bounded page/thumbnail caches and decoding |
| `ui/`, `main.dart` | Reusable design system, responsive screens and lazy visited navigation |
| Android `ExtensionHost` | Signed private APK installation, class loading, source calls, source preferences and manual browser |
| Android `StarReaderApplication`, `DownloadService`, `LibraryUpdateWorker` | Cached Flutter engine, user-started foreground downloads, optional scheduled library checks |

Provider/ChangeNotifier connects state to Flutter. Lists and grids build visible children lazily. Source failures remain visible and do not fabricate catalogue results. Stable extension source IDs are strings across the Dart/platform boundary; protobuf parsing uses BigInt so 64-bit identifiers survive JavaScript web builds.

## Source and extension boundaries

A `MangaSource` provides search, details/chapters, pages and health. Extension manga/chapter URLs and JSON memo survive library persistence, backup and download resumption. Native `Source`/`SourceFactory`, legacy RxJava and suspend API contracts adapt into that Dart interface. Source adapter pagination/filter state is retained until the installed package revision changes. Home discovery has its own adapter so it cannot reset Discover pagination or filters. Installed source construction runs after local startup; slow or failing plugins do not hold the offline library behind a startup spinner. Startup database errors provide retry without clearing data.

Extension manga IDs contain the source ID and encoded manga URL. Chapter IDs additionally contain the encoded chapter URL, matching Mihon’s per-manga URL uniqueness contract ([upstream chapter schema](https://github.com/mihonapp/mihon/blob/524fa53043f2f5b2321ea13027e44f093ab4245c/data/src/main/sqldelight/tachiyomi/data/chapter.sq)). The native host and metadata importer share equivalent identity tests. Two titles may use the same relative chapter URL without sharing progress or downloaded pages.

Extension APKs are downloaded over HTTPS with a 64 MB bound. Android PackageManager verifies APK signatures; the host compares the signer SHA-256 against the explicitly trusted repository certificate, checks package identity, extension feature, API 1.4/1.6, minimum Android version and downgrade constraints. Certificate changes require new trust. APKs are private and made read-only for Android 14 dynamic-code rules. Installation uses a recoverable previous-file copy and rolls back a failed load. Extensions are not isolated from the host's privileges. Native libraries packaged inside arbitrary extension APKs and every host-specific API are not supported.

The shared network layer supplies source headers, cookies, OkHttp interceptors, rate limiting and a 24 MB HTTP cache. Manual WebView interaction can establish normal website sessions. It does not automate challenges or bypass access controls. The native JavaScript helper and `app.cash.quickjs` API use source-built QuickJS without its filesystem/network modules, with a 64 MiB runtime heap, 1 MiB JS stack and 20-second execution deadline. These limits apply to JavaScript execution, not to arbitrary extension Kotlin code.

## Download contract

One worker processes persistent jobs by priority and FIFO order. Each valid page is stored before advancing progress. Resume checks existing pages and only requests missing ones. In-flight jobs become paused after process restart. Deletion pauses/waits for an active transfer before removing bytes. Queue writes and batch operations are serialized; disk failures release the running flag and surface an error.

A user-started Android data-sync foreground service displays progress and a Pause action. A bounded renewable wake lock supports active transfers. Android service timeouts pause the queue; the service is not automatically restarted after process death. Force-stop, storage pressure, network failure and OS power policies can interrupt work. Background completion is not promised under every device policy.

Optional WorkManager checks use connected or unmetered networking and battery-not-low constraints. Cadences are 6/12/24/72 hours, not exact alarms. Each Dart scan is time-bounded and rotates a persisted cursor across large libraries. Per-source failures are retained while other titles continue. Notifications require user opt-in and Android permission. Restoring a metadata backup preserves the receiving device's schedule and notification settings.

## Reader and image memory

Encoded images are bounded to 40 MB per page. PNG/JPEG/GIF/WebP dimensions are read from headers without a second full decode. Original dimensions are limited to 64 million pixels, width 65,536, height 262,144 and aspect ratio 1,000; images beyond these bounds are rejected before display. Dimensions outside supported bounds are rejected; the Flutter codec validates actual pixel content on display. Decode targets are at most 2,048 pixels wide, 8,192 pixels high and 8 million pixels, preserving aspect ratio. Original-size mode refers to layout; decode caps still apply. Extreme strips may lose fine detail when scaled down.

The encoded page cache and Flutter decoded cache are bounded. Decoded cache settings allow 32/64/96/128 MB. Cover generation permits two concurrent input/decode operations and keeps an 8 MB compressed thumbnail cache, so grid widgets retain small thumbnails instead of entire chapter pages. Lazy paging/scrolling and limited preloading avoid loading a whole chapter.

Continuous mode stores page index, relative scroll offset and measured dimensions. The last long strip is marked complete only after decoded content reaches its bottom, not when it first appears. Paged mode requires the last decoded page. Profiles can be global defaults or per-title overrides. Reader pause saves position; activity resume restores brightness/awake controls. Width/height/original fitting uses a pannable canvas; active zoom or a page wider than its paging axis reserves drags for the image instead of accidentally turning pages. Reset zoom restores paging.

Android fullscreen uses `WindowInsetsControllerCompat`, including target SDK 36, where legacy Flutter immersive flags are insufficient. System bars can be temporarily revealed by swiping and are restored on reader exit. See the [Android immersive-mode guide](https://developer.android.com/develop/ui/views/layout/immersive). These are implementation bounds, not measured device FPS or leak guarantees.

## Backups and CBZ

StarReader JSON envelope: `format: starreader`, `version: 1`, `data`. The entire candidate is validated before merge. It includes library metadata, collections, tags, notes, progress, bookmarks and allowed settings, but no image bytes, live download queue, credentials, extension APKs or publisher trust. Existing local download records remain intact. Save failure rolls back the in-memory candidate. Maximum input is 20 MB.

Mihon/Tachiyomi import accepts standard gzip protobuf metadata, bounded to 20 MB compressed, 64 MB unpacked, 10,000 titles and 150,000 chapters. It previews counts before merge and preserves remote source IDs, chapter metadata, categories, history and progress. Unsupported local entries are skipped. Users install/trust matching sources separately. Encrypted backups, every fork-specific field and external trackers are unsupported. Very large conversions can exceed the StarReader merge limit and are rejected explicitly.

Native CBZ import streams the archive file rather than reading the whole compressed archive into RAM, verifies ZIP CRCs, naturally orders image names, and stores image BLOBs in private SQLite. Limits: 250 MB compressed, 750 MB expanded, 10,000 total entries, 1,500 image entries, 40 MB per image. Central-directory preflight rejects symlinks, encrypted archives and oversized image entries before decoding; CRC corruption aborts the import. Paths are never extracted to disk. A failed import removes its inserted pages and metadata. Reimporting creates another volume; content-hash deduplication is not implemented.


<!-- /coderabbit-ai-generated:v1 -->