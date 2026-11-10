<!-- coderabbit-ai-generated:v1 -->

# Scope and known limitations

This is a functional first release, not the complete production platform described in the initial brief. The following boundaries are explicit.

| Area | Implemented | Outstanding |
|---|---|---|
| Dashboard | Continue reading, library, stats, live popular and updated rails | Personalized recommendations, latest-chapter feed, configurable dashboard |
| Library | Categories, favorites, search, sorting, batch selection/move/favorite/update/remove; unread/downloaded/completed filters | Custom tags, alphabetical grouping, content-based duplicate detection, tracker sync |
| Sources | Live MangaDex adapter, language selection, health check, local CBZ | APK extension installation/runtime, multiple remote source adapters, extension updates |
| Discover | Title search, pagination, popular/new/updated sorts, completed filter, details | Author/artist/genre search filters, cross-source search, alternative-title UI |
| Reader | Horizontal/vertical paged, continuous, RTL, spreads, zoom/pan, scaling, margins/background, immersive controls, brightness/awake/volume keys, bookmarks, position, chapter chooser/end | Original-resolution option, custom tap-zone editor, transition styles, persistent per-title reader overrides, recommendation end cards, seamless cross-chapter prefetch |
| Downloads | Persistent queue, page progress, pause/resume/retry, batch enqueue, offline pages, storage size/deletion | Background service, priorities, Wi-Fi policy, notification progress, storage destination chooser |
| History/stats | Resume, timestamps, completed chapter count, recent activity, streak | Time spent, advanced analytics and goals |
| Settings | Themes, accents, grid columns, reader defaults, backup/restore, licenses | Full typography/spacing editor, navigation customization, cloud backup, update schedules, notifications, privacy lock |
| Accessibility | Flutter semantics, system text scaling, responsive phone/tablet navigation | Complete screen-reader audit, translated UI catalogues, foldable posture-specific layouts |
| Import | Validated StarReader JSON metadata merge, CBZ image import | Mihon protobuf migration, encrypted/full-content backup, EPUB/PDF/CBR |
| Performance | Lazy pages, bounded cache/decode, sequential downloads | Physical mid-range device FPS, sustained memory/leak measurements, 90/120 Hz certification |

Android validation, browser validation and automated checks are recorded separately in the release validation report. Compilation and a signed APK do not establish production readiness or device performance. The web preview is not an offline persistence target: local page bytes are held only for that browser session.
