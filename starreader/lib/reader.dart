import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'core/library.dart';
import 'core/image_dimensions.dart';
import 'core/models.dart';
import 'core/reader_preferences.dart';
import 'ui/reader_settings.dart';
import 'main.dart' show message, guard;

void openReader(BuildContext context, Manga manga, Chapter chapter) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Reader(manga: manga, chapter: chapter),
      ),
    );

class Reader extends StatefulWidget {
  final Manga manga;
  final Chapter chapter;
  const Reader({required this.manga, required this.chapter, super.key});
  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> with WidgetsBindingObserver {
  static const channel = MethodChannel('app.starreader/reader');
  late Chapter chapter;
  late Library library;
  late PageController pager;
  final ItemScrollController scroll = ItemScrollController();
  final ItemPositionsListener positions = ItemPositionsListener.create();
  List<String> urls = [];
  int page = 0, generation = 0;
  bool busy = true, chrome = true;
  String error = '';
  late ReaderPreferences preferences;
  String get mode => preferences.mode;
  String get fit => preferences.fit;
  bool get rtl => preferences.rtl;
  bool get spread => preferences.spread;
  double get margin => preferences.margin;
  double brightness = -1, scrollAlignment = 0;
  bool ending = false, reachedEnd = false, saveErrorShown = false;
  final pagePan = <int, bool>{};
  bool get pageNeedsPan =>
      pagePan[page] == true || (spread && pagePan[page + 1] == true);
  final decodedPages = <int>{};
  Color get background => switch (preferences.background) {
    'paper' => const Color(0xffeee5d5),
    'white' => Colors.white,
    'charcoal' => const Color(0xff202020),
    _ => Colors.black,
  };
  Color get foreground => background.computeLuminance() > .5
      ? const Color(0xff25332b)
      : Colors.white;
  Timer? hideTimer, saveTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    library = context.read<Library>();
    chapter = widget.chapter;
    preferences = library.readerPreferences(widget.manga.id);
    pager = PageController();
    positions.itemPositions.addListener(onScroll);
    load();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (!kIsWeb) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'next') {
          go(page + (spread ? 2 : 1));
        } else if (call.method == 'previous') {
          go(page - (spread ? 2 : 1));
        }
      });
      native('configure', {
        'awake': library.settings['awake'] != false,
        'volume': library.settings['volume'] != false,
      });
    }
    scheduleHide();
  }

  Future<void> native(String method, [dynamic arguments]) async {
    if (kIsWeb) {
      return;
    }
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException catch (_) {
      /* Browser and unit-test hosts have no native bridge. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      native('configure', {
        'awake': library.settings['awake'] != false,
        'volume': library.settings['volume'] != false,
      });
      native('brightness', brightness);
      scheduleHide();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      save();
      hideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    hideTimer?.cancel();
    saveTimer?.cancel();
    positions.itemPositions.removeListener(onScroll);
    pager.dispose();
    channel.setMethodCallHandler(null);
    native('reset');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void scheduleHide() {
    hideTimer?.cancel();
    if (!preferences.autoHide) return;
    if (WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .accessibleNavigation) {
      return;
    }
    hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => chrome = false);
      }
    });
  }

  Future<void> load() async {
    final token = ++generation;
    setState(() {
      busy = true;
      error = '';
      urls = [];
      reachedEnd = false;
      decodedPages.clear();
      pagePan.clear();
    });
    try {
      final result = await library.pages(chapter);
      if (!mounted || token != generation) {
        return;
      }
      if (result.isEmpty) {
        throw const FormatException('No pages returned for this chapter');
      }
      page = (library.progress(chapter.id)['page'] as int? ?? 0).clamp(
        0,
        result.length - 1,
      );
      pager.dispose();
      scrollAlignment = (library.progress(chapter.id)['offset'] as num? ?? 0)
          .toDouble()
          .clamp(-10000, 1);
      pager = PageController(initialPage: spread ? page ~/ 2 : page);
      setState(() {
        urls = result;
        busy = false;
      });
      preload();
    } catch (e) {
      if (mounted && token == generation) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  void save() {
    saveTimer?.cancel();
    if (urls.isNotEmpty) {
      library
          .position(
            widget.manga,
            chapter,
            page,
            urls.length,
            offset: mode == 'webtoon' ? scrollAlignment : 0,
            completed: mode == 'webtoon'
                ? reachedEnd
                : decodedPages.contains(urls.length - 1) &&
                      page + (spread ? 1 : 0) >= urls.length - 1,
          )
          .catchError((Object e) {
            if (mounted && !saveErrorShown) {
              saveErrorShown = true;
              message(context, 'Reading position could not be saved: $e');
            }
          });
    }
  }

  void changed(int value) {
    if (value == page) {
      return;
    }
    setState(() => page = value);
    preload();
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 250), save);
  }

  void onScroll() {
    if (mode != 'webtoon' || urls.isEmpty) {
      return;
    }
    final visible =
        positions.itemPositions.value
            .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    final last = visible.where((p) => p.index == urls.length - 1).firstOrNull;
    final dimensions = library.section(
      'pageDimensions',
    )['${chapter.id}:${urls.length - 1}'];
    final viewport = MediaQuery.sizeOf(context);
    final expectedHeight = dimensions is List && dimensions.length == 2
        ? (viewport.width - margin * 2) *
                  (dimensions[1] as num) /
                  (dimensions[0] as num) +
              margin * 2
        : double.infinity;
    // A newly decoded page can briefly publish its old loading-placeholder bounds.
    final measuredHeight = last == null
        ? 0
        : (last.itemTrailingEdge - last.itemLeadingEdge) * viewport.height;
    if (last != null &&
        decodedPages.contains(urls.length - 1) &&
        measuredHeight >= expectedHeight * .95 &&
        last.itemTrailingEdge <= 1.01) {
      reachedEnd = true;
    }
    if (visible.isNotEmpty && visible.first.index < urls.length) {
      final current = visible.first;
      final moved = scrollAlignment != current.itemLeadingEdge;
      scrollAlignment = current.itemLeadingEdge;
      changed(current.index);
      if (moved) {
        saveTimer?.cancel();
        saveTimer = Timer(const Duration(milliseconds: 350), save);
      }
    }
  }

  void preload() {
    if (page + 1 < urls.length && !urls[page + 1].startsWith('local:')) {
      unawaited(
        library
            .readPage(chapter.id, page + 1, urls[page + 1])
            .then<void>((_) {})
            .catchError((Object _) {}),
      );
    }
  }

  void go(int target) {
    if (urls.isEmpty) {
      return;
    }
    if (target >= urls.length) {
      end();
      return;
    }
    if (target < 0) {
      return;
    }
    if (mode == 'webtoon') {
      if (scroll.isAttached) {
        scroll.scrollTo(
          index: target,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
        );
      }
    } else {
      pager.animateToPage(
        spread ? target ~/ 2 : target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    scheduleHide();
  }

  Future<void> next(int direction) async {
    final list = library.chapters(widget.manga.id);
    final index = list.indexWhere((c) => c.id == chapter.id);
    if (index + direction < 0 || index + direction >= list.length) {
      message(context, 'No further chapter in this language');
      return;
    }
    save();
    setState(() => chapter = list[index + direction]);
    await load();
  }

  Future<void> end() async {
    if (ending) return;
    ending = true;
    try {
      if (urls.isNotEmpty) {
        save();
        library.section('progress')[chapter.id]['complete'] = true;
        await library.persist();
        if (!mounted) {
          return;
        }
      }
      setState(() => chrome = true);
      hideTimer?.cancel();
      await showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Another chapter, another world.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      library.chapters(widget.manga.id).lastOrNull?.id ==
                          chapter.id
                      ? null
                      : () {
                          Navigator.pop(c);
                          next(1);
                        },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next chapter'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.pop(context);
                  },
                  child: const Text('Back to this story'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      ending = false;
      if (mounted) scheduleHide();
    }
  }

  void resetMode() {
    final current = page;
    pager.dispose();
    pager = PageController(initialPage: spread ? current ~/ 2 : current);
    setState(() {});
  }

  Future<void> options() async {
    hideTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReaderSettingsPanel(
        preferences: preferences,
        brightness: brightness,
        onChanged: (next) {
          final rebuild = next.mode != mode || next.spread != spread;
          if (rebuild || next.fit != fit) pagePan.clear();
          setState(() => preferences = next);
          guard(
            context,
            () => library.saveReaderPreferences(widget.manga.id, next),
          );
          if (rebuild) resetMode();
        },
        onDefault: (next) =>
            library.saveReaderPreferences(widget.manga.id, next, global: true),
        onReset: () async {
          await library.resetReaderPreferences(widget.manga.id);
          return library.readerPreferences(widget.manga.id);
        },
        onBrightness: (v) {
          brightness = v;
          native('brightness', v);
        },
      ),
    );
    scheduleHide();
  }

  Future<void> selectChapter() async {
    hideTimer?.cancel();
    final list = library.chapters(widget.manga.id);
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => ListView.builder(
        itemCount: list.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return const ListTile(title: Text('Jump to chapter'));
          final ch = list[i - 1];
          return ListTile(
            selected: ch.id == chapter.id,
            title: Text('Chapter ${ch.number}'),
            subtitle: Text(ch.title),
            onTap: () {
              Navigator.pop(c);
              save();
              chapter = ch;
              load();
            },
          );
        },
      ),
    );
    scheduleHide();
  }

  Widget imagePage(int i, {bool continuous = false}) => ReaderImage(
    key: ValueKey('${chapter.id}:$i:$continuous:$fit'),
    chapter: chapter.id,
    index: i,
    url: urls[i],
    library: library,
    continuous: continuous,
    fit: fit,
    margin: margin,
    doubleTapScale: preferences.doubleTapScale,
    errorColor: foreground,
    pagingAxis: continuous
        ? null
        : mode == 'vertical'
        ? Axis.vertical
        : Axis.horizontal,
    onPanModeChanged: (active) {
      if (mounted && pagePan[i] != active) setState(() => pagePan[i] = active);
    },
    onLoaded: () {
      decodedPages.add(i);
      if (mode == 'webtoon') onScroll();
      if (i == page) save();
    },
    onTap: (x) {
      final edge = preferences.tapZones == 'wideCenter' ? .15 : .25;
      if (preferences.tapZones != 'disabled' && x < edge) {
        go(page + (rtl ? 1 : -1) * (spread ? 2 : 1));
      } else if (preferences.tapZones != 'disabled' && x > 1 - edge) {
        go(page + (rtl ? -1 : 1) * (spread ? 2 : 1));
      } else {
        setState(() => chrome = !chrome);
        scheduleHide();
      }
    },
  );
  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) {
        save();
      }
    },
    child: Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, color: foreground, size: 40),
                          const SizedBox(height: 20),
                          Text(
                            error,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: foreground),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : mode == 'webtoon'
                ? ScrollablePositionedList.builder(
                    key: ValueKey('${chapter.id}:$mode'),
                    itemScrollController: scroll,
                    itemPositionsListener: positions,
                    physics: pageNeedsPan
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    initialScrollIndex: page,
                    initialAlignment: scrollAlignment,
                    itemCount: urls.length + 1,
                    itemBuilder: (_, i) => i == urls.length
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: FilledButton(
                              onPressed: end,
                              child: const Text('Chapter complete →'),
                            ),
                          )
                        : imagePage(i, continuous: true),
                  )
                : PageView.builder(
                    key: ValueKey('${chapter.id}:$mode:$spread'),
                    controller: pager,
                    physics: pageNeedsPan
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    scrollDirection: mode == 'vertical'
                        ? Axis.vertical
                        : Axis.horizontal,
                    reverse: mode == 'paged' && rtl,
                    itemCount: spread ? (urls.length / 2).ceil() : urls.length,
                    onPageChanged: (i) => changed(spread ? i * 2 : i),
                    itemBuilder: (_, i) => spread
                        ? Row(
                            textDirection: rtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            children: [
                              Expanded(child: imagePage(i * 2)),
                              if (i * 2 + 1 < urls.length)
                                Expanded(child: imagePage(i * 2 + 1)),
                            ],
                          )
                        : imagePage(i),
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ReaderChrome(
              visible: chrome,
              fromTop: true,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xee0b1410),
                      Color(0xbb0b1410),
                      Color(0x000b1410),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Close reader',
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .09,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.manga.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'CHAPTER ${chapter.number.isEmpty ? '—' : chapter.number}',
                                style: const TextStyle(
                                  color: Color(0xffb8cbbf),
                                  fontSize: 9,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bookmark page',
                          onPressed: urls.isEmpty
                              ? null
                              : () => guard(context, () async {
                                  await library.bookmark(chapter.id, page);
                                  if (mounted) setState(() {});
                                }),
                          color: Colors.white,
                          disabledColor: Colors.white30,
                          icon: Icon(
                            library
                                    .section('bookmarks')
                                    .containsKey('${chapter.id}:$page')
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reader settings',
                          onPressed: options,
                          color: Colors.white,
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (urls.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: _ReaderChrome(
                visible: chrome,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xf218261f),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xff354a3d)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 25,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 15, 18, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_stories_outlined,
                                  color: Color(0xffbde9d1),
                                  size: 15,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  pageNeedsPan
                                      ? 'PAN TO EXPLORE'
                                      : mode == 'webtoon'
                                      ? 'CONTINUOUS'
                                      : spread
                                      ? 'DOUBLE PAGE'
                                      : 'READING',
                                  style: const TextStyle(
                                    color: Color(0xffb8cbbf),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${page + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  ' / ${urls.length}',
                                  style: const TextStyle(
                                    color: Color(0xffb8cbbf),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16,
                                ),
                                activeTrackColor: const Color(0xffbde9d1),
                                inactiveTrackColor: const Color(0xff43594b),
                                thumbColor: const Color(0xffbde9d1),
                              ),
                              child: Slider(
                                value: page.toDouble(),
                                max: (urls.length - 1)
                                    .clamp(1, 100000)
                                    .toDouble(),
                                semanticFormatterCallback: (value) =>
                                    'Page ${value.round() + 1} of ${urls.length}',
                                onChanged: urls.length == 1
                                    ? null
                                    : (v) => go(v.round()),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: 'Previous chapter',
                                  onPressed:
                                      library
                                              .chapters(widget.manga.id)
                                              .indexWhere(
                                                (c) => c.id == chapter.id,
                                              ) >
                                          0
                                      ? () => next(-1)
                                      : null,
                                  color: Colors.white,
                                  disabledColor: Colors.white24,
                                  icon: const Icon(Icons.skip_previous_rounded),
                                ),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: selectChapter,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xffdce9df),
                                    ),
                                    icon: const Icon(
                                      Icons.list_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Chapters',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Finish chapter',
                                  onPressed: end,
                                  color: const Color(0xffbde9d1),
                                  icon: const Icon(Icons.task_alt_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Next chapter',
                                  onPressed:
                                      library
                                              .chapters(widget.manga.id)
                                              .lastOrNull
                                              ?.id !=
                                          chapter.id
                                      ? () => next(1)
                                      : null,
                                  color: Colors.white,
                                  disabledColor: Colors.white24,
                                  icon: const Icon(Icons.skip_next_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!chrome && urls.isNotEmpty)
            Positioned(
              right: 20,
              bottom: 18,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${page + 1} / ${urls.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReaderChrome extends StatelessWidget {
  final bool visible, fromTop;
  final Widget child;
  const _ReaderChrome({
    required this.visible,
    required this.child,
    this.fromTop = false,
  });
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : Offset(0, fromTop ? -.12 : .12),
          duration: duration,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            child: child,
          ),
        ),
      ),
    );
  }
}

class ReaderImage extends StatefulWidget {
  final String chapter, url, fit;
  final int index;
  final Library library;
  final bool continuous;
  final double margin, doubleTapScale;
  final ValueChanged<double> onTap;
  final VoidCallback? onLoaded;
  final Axis? pagingAxis;
  final ValueChanged<bool>? onPanModeChanged;
  final Color errorColor;
  const ReaderImage({
    required this.chapter,
    required this.url,
    required this.index,
    required this.library,
    required this.continuous,
    required this.fit,
    required this.margin,
    this.doubleTapScale = 2.5,
    required this.onTap,
    this.onLoaded,
    this.pagingAxis,
    this.onPanModeChanged,
    this.errorColor = Colors.white70,
    super.key,
  });
  @override
  State<ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends State<ReaderImage> {
  late Future<Uint8List> bytes;
  int decodeWidth = 1024, decodeHeight = 1024;
  double naturalWidth = 1024, naturalHeight = 0;
  final transform = TransformationController();
  TapDownDetails? tap;
  bool reportedFrame = false;
  bool oversizedAlongPagingAxis = false;
  bool? lastPanState;
  @override
  void initState() {
    super.initState();
    transform.addListener(reportPanMode);
    reportPanMode();
    final size = widget.library.section(
      'pageDimensions',
    )['${widget.chapter}:${widget.index}'];
    if (size is List && size.length == 2) {
      naturalWidth = (size[0] as num).toDouble();
      naturalHeight = (size[1] as num).toDouble();
    }
    bytes = load();
  }

  Future<Uint8List> load() async {
    final result = await widget.library.readPage(
      widget.chapter,
      widget.index,
      widget.url,
    );
    await measure(result);
    return result;
  }

  Future<void> measure(Uint8List bytes) async {
    final size = ImageDimensions.read(bytes);
    naturalWidth = size.width.toDouble();
    naturalHeight = size.height.toDouble();
    final target = size.decoded();
    decodeWidth = target.width;
    decodeHeight = target.height;
    rememberDimensions();
  }

  void rememberDimensions() {
    final dimensions = widget.library.section('pageDimensions');
    dimensions['${widget.chapter}:${widget.index}'] = [
      naturalWidth,
      naturalHeight,
    ];
    while (dimensions.length > 5000) {
      dimensions.remove(dimensions.keys.first);
    }
  }

  @override
  void dispose() {
    transform.removeListener(reportPanMode);
    transform.dispose();
    super.dispose();
  }

  void reportPanMode() {
    final active =
        oversizedAlongPagingAxis || transform.value.getMaxScaleOnAxis() > 1.01;
    if (lastPanState == active) return;
    lastPanState = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPanModeChanged?.call(active);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => Padding(
      padding: EdgeInsets.all(widget.margin),
      child: GestureDetector(
        excludeFromSemantics: true,
        onTapDown: (d) => tap = d,
        onTap: () => widget.onTap(
          (tap?.localPosition.dx ?? box.maxWidth / 2) / box.maxWidth,
        ),
        onDoubleTap: () {
          if (transform.value.getMaxScaleOnAxis() > 1) {
            transform.value = Matrix4.identity();
          } else {
            final p = tap?.localPosition ?? Offset.zero;
            transform.value = Matrix4.identity()
              ..translateByDouble(
                -p.dx * (widget.doubleTapScale - 1),
                -p.dy * (widget.doubleTapScale - 1),
                0,
                1,
              )
              ..scaleByDouble(
                widget.doubleTapScale,
                widget.doubleTapScale,
                1,
                1,
              );
          }
        },
        child: InteractiveViewer(
          transformationController: transform,
          constrained: widget.fit == 'contain' || widget.continuous,
          boundaryMargin: const EdgeInsets.all(40),
          minScale: 1,
          maxScale: 5,
          panEnabled: true,
          child: FutureBuilder<Uint8List>(
            future: bytes,
            builder: (_, snapshot) {
              final viewportWidth = math.max(
                1.0,
                box.maxWidth - widget.margin * 2,
              );
              final viewportHeight = box.maxHeight.isFinite
                  ? math.max(1.0, box.maxHeight - widget.margin * 2)
                  : 400.0;
              if (snapshot.hasError) {
                return SizedBox(
                  width: viewportWidth,
                  height: widget.continuous ? 300 : viewportHeight,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: widget.errorColor,
                        ),
                        Text(
                          'Page ${widget.index + 1} could not load',
                          style: TextStyle(color: widget.errorColor),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            bytes = load();
                          }),
                          child: const Text('Retry page'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return SizedBox(
                  width: viewportWidth,
                  height: widget.continuous
                      ? (naturalHeight > 0
                            ? (box.maxWidth - widget.margin * 2) *
                                  naturalHeight /
                                  naturalWidth
                            : 400)
                      : viewportHeight,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              double? pageWidth, pageHeight;
              if (widget.continuous || widget.fit == 'width') {
                pageWidth = viewportWidth;
                pageHeight = viewportWidth * naturalHeight / naturalWidth;
              } else if (widget.fit == 'height') {
                pageHeight = viewportHeight;
                pageWidth = viewportHeight * naturalWidth / naturalHeight;
              } else if (widget.fit == 'original') {
                pageWidth = naturalWidth;
                pageHeight = naturalHeight;
              }
              oversizedAlongPagingAxis =
                  !widget.continuous &&
                  (widget.pagingAxis == Axis.horizontal
                      ? (pageWidth ?? viewportWidth) > viewportWidth + 1
                      : widget.pagingAxis == Axis.vertical &&
                            (pageHeight ?? viewportHeight) >
                                viewportHeight + 1);
              reportPanMode();
              final image = Image.memory(
                snapshot.data!,
                semanticLabel: 'Page ${widget.index + 1}',
                height: pageHeight,
                frameBuilder: (_, child, frame, _) {
                  if (frame != null && !reportedFrame) {
                    reportedFrame = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.onLoaded?.call();
                    });
                  }
                  return child;
                },
                width: pageWidth,
                fit: BoxFit.contain,
                cacheWidth: decodeWidth,
                cacheHeight: decodeHeight,
                gaplessPlayback: true,
                errorBuilder: (_, e, s) => Center(
                  child: Text(
                    'This image cannot be decoded',
                    style: TextStyle(color: widget.errorColor),
                  ),
                ),
              );
              if (widget.continuous || widget.fit == 'contain') return image;
              // The canvas can exceed the viewport, so width/height fitting
              // keeps the entire page reachable by panning instead of cropping.
              return SizedBox(
                width: math.max(viewportWidth, pageWidth!),
                height: math.max(viewportHeight, pageHeight!),
                child: Center(child: image),
              );
            },
          ),
        ),
      ),
    ),
  );
}
