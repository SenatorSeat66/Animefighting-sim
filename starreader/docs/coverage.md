<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:72f288c8c0866077ce8b25ebdd2b4cd0beef4e25b40ae205d0aaab3a3b57e240 -->

# Feature coverage and remaining limits

Version 0.2.0 expands the foundation into a working Android reader with real extension execution. It does not claim every feature from the original platform brief is complete.

| Area | Implemented | Remaining limits |
|---|---|---|
| Home | Continue reading, fresh chapters, recent/favorite rails, source connections, stats and real discovery content | No recommendation model or drag-to-reorder dashboard |
| Library | Multiple collections, tags, notes, favorites, search, progress/source/download/duplicate-title filters, sorting, lazy configurable grids, batch operations | No content-hash duplicate detection or external tracker sync |
| Extensions | Protobuf repositories, explicit certificate trust, signed private APK install/update/remove, API 1.4/1.6 host, preferences, filters, health, manual browser, QuickJS | Not every source/host API; no arbitrary plugin native-library extraction; Android only |
| Discover | Built-in and extension search/pagination, source filters, cross-source search, source language selection, details and chapter selection | Available filters/metadata depend on each source; no guaranteed website availability |
| Reader | Horizontal/vertical paged, continuous/webtoon, RTL, spreads, zoom/pan, width/height/original layout, backgrounds/margins, tap-zone presets, bookmarks, slider, chapter chooser/end, persisted offsets/profiles, Android brightness/awake/volume | No arbitrary tap-zone editor, transition-effect collection, tiled full-resolution strips or seamless cross-chapter prefetch |
| Downloads | Persistent priority queue, pause/resume/retry, batch selection, real page progress, offline pages, foreground notification and storage deletion | No external storage destination chooser, no unconditional background survival; Wi-Fi schedule policy applies to library checks, not download queue |
| History/stats | Recent reading, resume, completed count, streak and activity | No measured reading-time analytics or goals |
| Personalization | Light/dark/AMOLED, accents, Manrope/Newsreader, grid columns/ratios/spacing, enlarged text, reduced motion, cache size | No arbitrary font import or navigation editor |
| Updates | Manual and optional WorkManager schedules, fresh-chapter feed, failures, optional notifications | OS-controlled timing; no automatic chapter download policy |
| Import/backup | Validated StarReader metadata merge, standard Mihon/Tachiyomi metadata import, streaming native CBZ | No downloaded bytes/credentials/trust in backup; no encrypted/cloud backup, CBR/PDF or full fork-specific migration |
| Accessibility | Semantics, scalable text, responsive phone/tablet navigation, large-text regression tests | English UI; no complete screen-reader audit, translated catalogues or fold-posture-specific behavior |
| Performance | Lazy views, bounded input/decode/cache, thumbnail pool, sequential downloads | No device FPS, 90/120 Hz certification, prolonged physical-device memory/leak measurements |

No fake catalogue titles or simulated downloads are bundled. Empty and error states explain unavailable data. Browser screenshots demonstrate Flutter layout and local reader behavior; they do not prove Android plugin lifecycle behavior. Android installation, launch, permission prompts and physical-device reading tests are explicitly left to the user.


<!-- /coderabbit-ai-generated:v1 -->