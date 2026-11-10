<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1a15b50143733bc13f8dd609f7f89370d541523fb167c5fee8abdc3479c094d9 -->

# Extensions, sources and attribution

## Add the requested repository

1. Open **Sources → Repositories**.
2. Add `https://github.com/keiyoushi/extensions/raw/repo/index.pb`, or use the Keiyoushi shortcut.
3. Review the publisher and certificate, then explicitly trust it if acceptable.
4. Open **Extensions**, select the language, find an extension, and install it.
5. Open **My sources**, select an installed source and browse/search. Source filters, source preferences, website access and health checks are available from the source controls.

The GitHub URL is normalized to its raw content URL. The current gzip protobuf catalogue is parsed directly; legacy JSON is not treated as the current protocol. Catalogue/package network failures are visible. Installation and execution require Android; the browser preview can inspect repositories but cannot run Android APKs.

The installer verifies the publisher certificate, package name, version, supported API and minimum Android version. Repository refresh does not silently accept a changed certificate. Updates/removal are available in extension management. Only install third-party code you trust: it executes inside StarReader's process. StarReader is independent of Mihon and Keiyoushi and does not endorse every repository or source.

## Actual compatibility evidence

The host adapts API 1.4/1.6 `Source`, `SourceFactory`, `HttpSource`, filter models, source preferences, RxJava/suspend calls, shared networking/cookies and JavaScript. A JVM contract test loaded the published Keiyoushi MangaDex **v1.6.4** extension JAR, enumerated **62 sources**, read **12 filters**, and exercised a live catalogue, chapters, page list and first image. The corresponding signed APK certificate matched the repository certificate. This is real extension API/network evidence, not an Android APK installation test.

Individual sources can require additional host APIs, unsupported plugin native libraries, account state or website changes. Unsupported linkage and network errors are reported. No claim of universal extension compatibility is made. Website access is a normal manual browser session; automated DRM, authentication or challenge bypass is not implemented.

## Upstream research and reused code

Research and copied API/helper baseline: [Mihon revision 524fa53043f2f5b2321ea13027e44f093ab4245c](https://github.com/mihonapp/mihon/tree/524fa53043f2f5b2321ea13027e44f093ab4245c). Inspected source API, extension loader/trust, source models, backup protobuf and reader behavior. Apache-2.0 API and helper files retain upstream notices. StarReader's Flutter UI, state model, bridge and reader are independently implemented. Adaptations are described in `assets/licenses/Mihon-NOTICE.txt`.

QuickJS engine: [official 2026-06-04 release](https://bellard.org/quickjs/), MIT. Java/JNI binding: [zhanghai/quickjs-java revision 547f5b1597](https://github.com/zhanghai/quickjs-java/tree/547f5b1597), Apache-2.0, retaining the Square API. Engine and binding compile from source. Exact download hashes, licenses and modifications are in `third_party/quickjs/provenance.json` and the adjacent license files. Runtime limits and 16 KiB linker alignment are StarReader adaptations.

The direct MangaDex adapter follows its [public API](https://api.mangadex.org/docs/). Remote artwork remains owned/licensed by its providers; no remote manga art is bundled. Sources can reject requests or remove content. Users retain control over enabled sources and their imported/downloaded files.

## Assets and dependencies

- [Manrope](https://github.com/google/fonts/tree/main/ofl/manrope) and [Newsreader](https://github.com/google/fonts/tree/main/ofl/newsreader): SIL OFL, original license files included.
- Original StarReader geometric branding: `tools/create_branding.py`; Pillow is a development-only tool.
- Original reader fixtures: `tools/create_reader_fixtures.py`, `test/fixtures/`; not application assets. Studio screenshots are labeled verification artwork, not a real manga catalogue entry.
- Native dependency notices: `assets/licenses/`; Flutter package notices are registered automatically, with additional native/font notices in `core/licenses.dart`.
- Full asset provenance: `assets/provenance.json`.


<!-- /coderabbit-ai-generated:v1 -->