<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ab91d46629fa76a6a240d562729d1f627094c470803443fa2978d5011c6656f4 -->

<!-- coderabbit-ai-generated-section:v1:ec01252f6930833ac5320885b82dd58a98aeb93c52db040eebefe75ca0a26c64 -->

# StarReader 0.2.0 release and migration

Package `app.starreader.starreader`, version `0.2.0`, build `2`, Android 7+ (API 24), ARM64 only. The earlier published foundation was labeled `1.0.0+1` even though the development request called it the 0.1.0 foundation. This release uses the requested 0.2.0 numbering.

## New signing identity — clean installation required

This release is signed with a **new release key**, as requested. Android will not install it over the differently signed foundation with the same package ID. Before uninstalling the old app:

1. Export its StarReader metadata backup.
2. Keep the original CBZ files. Metadata exports do not contain their image bytes or downloaded chapters.
3. Uninstall the foundation, install this APK, and restore metadata/import original local files as needed.
4. Add and explicitly trust desired extension repositories, install matching sources, and choose update/notification settings on this device.

Uninstalling removes private app data. A metadata restore does not recover deleted page bytes. Keep the new private signing key securely for future compatible releases; it is not included in public release files.

## What changed

- Real Mihon repository management, certificate-checked extension installation and native source execution.
- Current source-built QuickJS API, source settings, manual website sessions, source filters and global search.
- A redesigned reading room, original type pairing, configurable library cards, calmer reader chrome and stronger light/dark contrast.
- Per-title reader profiles, exact long-strip restoration, corrected completion logic, Android 16 fullscreen and bounded header/decode/thumbnail handling.
- Fitted-page panning and zoom gesture arbitration, startup retry, lazy download/history lists, compact imported dates and chapter identity isolation across titles.
- Tags, notes, multiple collections, advanced filters and chapter selection.
- Foreground downloads, optional scheduled chapter checks and fresh-chapter feed.
- SQLite v2 migration, standard Mihon metadata import, bounded streaming CBZ and crash/failure recovery.

See [verification](verification.md) for executed checks and [coverage](coverage.md) for explicit remaining features. Device testing is user-deferred. The browser preview is not an Android runtime or persistent offline target.


<!-- /coderabbit-ai-generated:v1 -->

## Verified release files

- APK: `StarReader-0.2.0-arm64-v8a.apk`, 26051294 bytes (24.84 MiB), Android API24+, ARM64, release build2.
- APK SHA-256: `87ab0a45cfdf685a10224d0edbd757b9bcd79bb21c6e263c95a4f194494f3392`
- App Bundle: 27011802 bytes; SHA-256 `ca1866173feaa8298c19f712c394f40a96f629497649e4dec0e41461acd3d5c5`.
- New signing certificate SHA-256: `12213f4c89365461a009f6dd6a7b534f44390ee341e800f386e6a574d29ad5f1`.
- 50 Flutter tests passed; the final visual-only edits additionally passed21affected UI tests. Native JVM suite:14passed,0skipped. Analysis, APK checks and bundletool validation passed. Device installation/launch remains user-deferred.


<!-- /coderabbit-ai-generated:v1 -->