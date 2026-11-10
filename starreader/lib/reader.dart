import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'core/library.dart';
import 'core/models.dart';
import 'main.dart' show message;

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

class _ReaderState extends State<Reader> {
  static const channel = MethodChannel('app.starreader/reader');
  late Chapter chapter;
  late Library library;
  late PageController pager;
  final ItemScrollController scroll = ItemScrollController();
  final ItemPositionsListener positions = ItemPositionsListener.create();
  List<String> urls = [];
  int page = 0, generation = 0;
  bool busy = true, chrome = true, spread = false;
  String error = '', mode = 'paged', fit = 'contain';
  bool rtl = false;
  double brightness = -1, margin = 0;
  Color background = Colors.black;
  Timer? hideTimer, saveTimer;
  @override
  void initState() {
    super.initState();
    library = context.read<Library>();
    chapter = widget.chapter;
    mode = library.settings['readerMode'] ?? 'paged';
    rtl = library.settings['rtl'] == true;
    pager = PageController();
    positions.itemPositions.addListener(onScroll);
    load();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
  void dispose() {
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
      pager = PageController(initialPage: page);
      setState(() {
        urls = result;
        busy = false;
      });
      save();
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
      library.position(widget.manga, chapter, page, urls.length);
    }
  }

  void changed(int value) {
    if (value == page) {
      return;
    }
    setState(() => page = value);
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
    if (visible.isNotEmpty && visible.first.index < urls.length) {
      changed(visible.first.index);
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
          duration: const Duration(milliseconds: 250),
        );
      }
    } else {
      pager.animateToPage(
        spread ? target ~/ 2 : target,
        duration: const Duration(milliseconds: 220),
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
                onPressed: () {
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
  }

  void resetMode() {
    final current = page;
    pager.dispose();
    pager = PageController(initialPage: spread ? current ~/ 2 : current);
    setState(() {});
    scheduleHide();
  }

  Future<void> options() async {
    hideTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your reading space',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in {
                        'paged': 'Horizontal',
                        'vertical': 'Vertical pages',
                        'webtoon': 'Continuous',
                      }.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: mode == e.key,
                          onSelected: (_) {
                            mode = e.key;
                            spread = false;
                            library.setting('readerMode', mode);
                            resetMode();
                            update(() {});
                          },
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Right to left'),
                    value: rtl,
                    onChanged: (v) {
                      setState(() => rtl = v);
                      library.setting('rtl', v);
                      update(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Double-page spread'),
                    subtitle: const Text('Best on a tablet or in landscape'),
                    value: spread,
                    onChanged: mode == 'webtoon'
                        ? null
                        : (v) {
                            spread = v;
                            resetMode();
                            update(() {});
                          },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: fit,
                    decoration: const InputDecoration(
                      labelText: 'Page scaling',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'contain',
                        child: Text('Fit page'),
                      ),
                      DropdownMenuItem(
                        value: 'width',
                        child: Text('Fit width'),
                      ),
                      DropdownMenuItem(
                        value: 'height',
                        child: Text('Fit height'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => fit = v!);
                      update(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Page margin'),
                  Slider(
                    value: margin,
                    max: 40,
                    onChanged: (v) {
                      setState(() => margin = v);
                      update(() {});
                    },
                  ),
                  const Text('Reader background'),
                  Row(
                    children: [
                      for (final color in [
                        Colors.black,
                        const Color(0xff202020),
                        const Color(0xffeee5d5),
                        Colors.white,
                      ])
                        IconButton(
                          tooltip: 'Background color',
                          onPressed: () {
                            setState(() => background = color);
                            update(() {});
                          },
                          icon: Icon(Icons.circle, color: color),
                        ),
                    ],
                  ),
                  if (!kIsWeb) ...[
                    const Text('Screen brightness'),
                    Slider(
                      value: brightness < 0 ? 0.5 : brightness,
                      min: .02,
                      max: 1,
                      onChanged: (v) {
                        brightness = v;
                        native('brightness', v);
                        update(() {});
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        brightness = -1;
                        native('brightness', -1.0);
                        update(() {});
                      },
                      child: const Text('Use system brightness'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Pinch to zoom · Double-tap to magnify\nTap center for controls · Tap edges to turn pages',
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    scheduleHide();
  }

  Future<void> selectChapter() async {
    hideTimer?.cancel();
    final list = library.chapters(widget.manga.id);
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => ListView(
        children: [
          const ListTile(title: Text('Jump to chapter')),
          ...list.map(
            (ch) => ListTile(
              selected: ch.id == chapter.id,
              title: Text('Chapter ${ch.number}'),
              subtitle: Text(ch.title),
              onTap: () {
                Navigator.pop(c);
                save();
                chapter = ch;
                load();
              },
            ),
          ),
        ],
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
    onTap: (x) {
      if (x < .25) {
        go(page + (rtl ? 1 : -1) * (spread ? 2 : 1));
      } else if (x > .75) {
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
                          const Icon(
                            Icons.cloud_off,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            error,
                            style: const TextStyle(color: Colors.white),
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
                    initialScrollIndex: page,
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
          if (chrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .88),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Close reader',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
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
                                ),
                              ),
                              Text(
                                'CHAPTER ${chapter.number}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bookmark page',
                          onPressed: urls.isEmpty
                              ? null
                              : () {
                                  library.bookmark(chapter.id, page);
                                  setState(() {});
                                },
                          icon: Icon(
                            library
                                    .section('bookmarks')
                                    .containsKey('${chapter.id}:$page')
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reader settings',
                          onPressed: options,
                          icon: const Icon(Icons.tune, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (chrome && urls.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .9),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '${page + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Expanded(
                              child: Slider(
                                value: page.toDouble(),
                                max: (urls.length - 1)
                                    .clamp(1, 100000)
                                    .toDouble(),
                                onChanged: (v) => go(v.round()),
                              ),
                            ),
                            Text(
                              '${urls.length}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'Previous chapter',
                              onPressed: () => next(-1),
                              icon: const Icon(
                                Icons.skip_previous,
                                color: Colors.white,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: selectChapter,
                              icon: const Icon(Icons.list),
                              label: const Text('Chapters'),
                            ),
                            TextButton(
                              onPressed: end,
                              child: const Text('Finish'),
                            ),
                            IconButton(
                              tooltip: 'Next chapter',
                              onPressed: () => next(1),
                              icon: const Icon(
                                Icons.skip_next,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class ReaderImage extends StatefulWidget {
  final String chapter, url, fit;
  final int index;
  final Library library;
  final bool continuous;
  final double margin;
  final ValueChanged<double> onTap;
  const ReaderImage({
    required this.chapter,
    required this.url,
    required this.index,
    required this.library,
    required this.continuous,
    required this.fit,
    required this.margin,
    required this.onTap,
    super.key,
  });
  @override
  State<ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends State<ReaderImage> {
  late Future<Uint8List> bytes;
  int decodeWidth = 1024;
  final transform = TransformationController();
  TapDownDetails? tap;
  @override
  void initState() {
    super.initState();
    bytes = load();
  }

  Future<Uint8List> load() async {
    final local = await widget.library.storage.page(
      widget.chapter,
      widget.index,
    );
    if (local != null) {
      await measure(local);
      return local;
    }
    if (widget.url.startsWith('local:')) {
      throw const FormatException(
        'Offline page is missing. Import or download this chapter again.',
      );
    }
    final result = await Library.fetchImage(widget.url);
    await measure(result);
    return result;
  }

  Future<void> measure(Uint8List bytes) async {
    if (kIsWeb) {
      decodeWidth = 1024;
      return;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final scale = math.min(
          1.0,
          math.sqrt(8000000 / (descriptor.width * descriptor.height)),
        );
        decodeWidth = math
            .min(2048, (descriptor.width * scale).floor())
            .clamp(1, 2048);
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
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
              ..translateByDouble(-p.dx, -p.dy, 0, 1)
              ..scaleByDouble(2, 2, 1, 1);
          }
        },
        child: InteractiveViewer(
          transformationController: transform,
          minScale: 1,
          maxScale: 5,
          panEnabled: true,
          child: FutureBuilder<Uint8List>(
            future: bytes,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(
                  height: widget.continuous ? 300 : null,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                        ),
                        Text(
                          'Page ${widget.index + 1} could not load',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () => setState(() => bytes = load()),
                          child: const Text('Retry page'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return SizedBox(
                  height: widget.continuous ? 400 : null,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Image.memory(
                snapshot.data!,
                width: widget.continuous ? box.maxWidth : null,
                fit: widget.continuous
                    ? BoxFit.fitWidth
                    : widget.fit == 'width'
                    ? BoxFit.fitWidth
                    : widget.fit == 'height'
                    ? BoxFit.fitHeight
                    : BoxFit.contain,
                cacheWidth: decodeWidth,
                gaplessPlayback: true,
                errorBuilder: (_, e, s) => const Center(
                  child: Text(
                    'This image cannot be decoded',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
