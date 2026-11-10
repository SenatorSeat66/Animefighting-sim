<!-- coderabbit-ai-generated:v1 -->

# Source research and attribution

Research revision: Mihon `524fa53043f2f5b2321ea13027e44f093ab4245c`.

Inspected the official [Mihon repository](https://github.com/mihonapp/mihon), its Apache-2.0 license, `source-api/.../Source.kt`, `source-api/.../model/Page.kt`, and `app/.../extension/util/ExtensionLoader.kt` before implementation. The inspected source contract includes catalogue search, manga updates and page resolution; the loader checks library versions 1.4/1.6 and signing trust. Those are Android/Kotlin plugin contracts. Dart cannot directly load them.

StarReader implements its own Dart adapter contract and UI. No Mihon implementation code was copied into the application. Mihon APK extensions and protobuf backups are unsupported. Native compatibility would require a separately reviewed Android host, API shims, dependency compatibility, trust management and integration tests. An adapter interface alone is not claimed as extension compatibility.

MangaDex integration follows its [public API documentation](https://api.mangadex.org/docs/). Browser bot challenges are reported as source failures. No access controls are bypassed. Remote cover and page images are not bundled in the APK. Users remain responsible for their imported files and permitted personal use.

Manrope font is from the [Google Fonts Manrope directory](https://github.com/google/fonts/tree/main/ofl/manrope), with the original SIL OFL text in `assets/fonts/OFL.txt`. StarReader branding is generated from original geometric shapes by `tools/create_branding.py`; Pillow is a development-only dependency. Screenshots containing the Studio fixture show original verification artwork, not a published manga title.
