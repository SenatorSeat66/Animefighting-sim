import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'core/file_input.dart';
import 'core/licenses.dart';
import 'core/diagnostics.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'core/library.dart';
import 'core/library_query.dart';
import 'ui/title_organization.dart';
import 'ui/chapter_manager.dart';
import 'ui/library_updates_screen.dart';
import 'core/models.dart';
import 'core/storage.dart';
import 'reader.dart';
import 'enhancements.dart';
import 'ui/design.dart';
import 'ui/startup.dart';
import 'ui/source_hub.dart';
import 'ui/reading_room.dart';
import 'ui/global_search.dart';
import 'ui/source_filters.dart';
import 'ui/extension_cover.dart';
import 'core/extensions.dart';
import 'core/mihon_backup.dart';
import 'core/background_downloads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerStarReaderLicenses();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 * 1024 * 1024;
  final library = Library(Storage());
  runApp(
    ChangeNotifierProvider.value(
      value: library,
      child: StarReaderStartup(
        initialize: library.init,
        child: const StarReader(),
      ),
    ),
  );
}

const mint = Color(0xffbdedd0);

class StarReader extends StatelessWidget {
  const StarReader({super.key});
  @override
  Widget build(BuildContext context) {
    final encodedSettings = context.select<Library, String>(
      (l) => jsonEncode(l.settings),
    );
    final s = jsonDecode(encodedSettings) as Map<String, dynamic>;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        (s['imageCacheMb'] as int? ?? 96) * 1024 * 1024;
    final mode = s['theme'] ?? 'dark';
    final accent = Color(s['accent'] as int? ?? mint.toARGB32());
    ThemeData theme(Brightness b) =>
        StarTheme.build(b, accent: accent, amoled: mode == 'amoled');
    return MaterialApp(
      title: 'StarReader',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: mode == 'light' ? ThemeMode.light : ThemeMode.dark,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = (s['textScale'] as num? ?? 1).toDouble();
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(14) / 14 * scale,
            ),
            disableAnimations:
                media.disableAnimations || s['reduceMotion'] == true,
          ),
          child: child!,
        );
      },
      home: s['onboarded'] == true ? const Shell() : const Welcome(),
    );
  }
}

void message(BuildContext context, Object e) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

Future<void> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      message(context, e);
    }
  }
}

void openManga(BuildContext context, Manga m) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => Details(m: m)),
);

class Welcome extends StatelessWidget {
  const Welcome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 64, color: mint),
                  const SizedBox(height: 36),
                  const Text(
                    'A universe of stories.\nA space of your own.',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Meet StarReader',
                    style: TextStyle(color: mint, fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Build your collection. Find your next chapter. Read beautifully, online or off.',
                    style: TextStyle(fontSize: 17, height: 1.7),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No account. No advertising. No analytics.\nAdd your sources, connect to MangaDex, or import your own CBZ files.',
                    style: TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<Library>().setting('onboarded', true),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Enter StarReader'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  final visited = <int>{0};
  @override
  Widget build(BuildContext context) {
    final pages = [
      Home(
        onDiscover: () => setState(() {
          tab = 2;
          visited.add(2);
        }),
      ),
      const Collection(),
      const Discover(),
      const Activity(),
      const Preferences(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width > 850)
              NavigationRail(
                selectedIndex: tab,
                onDestinationSelected: (v) => setState(() {
                  tab = v;
                  visited.add(v);
                }),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.collections_bookmark_outlined),
                    label: Text('Library'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.explore_outlined),
                    label: Text('Discover'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history),
                    label: Text('Activity'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.tune),
                    label: Text('Settings'),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    visited.contains(i) ? pages[i] : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width > 850
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() {
                tab = v;
                visited.add(v);
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.collections_bookmark_outlined),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  label: 'Discover',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'Activity',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

class PageTitle extends StatelessWidget {
  final String eyebrow, title;
  final Widget? action;
  const PageTitle(this.eyebrow, this.title, {this.action, super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class Empty extends StatelessWidget {
  final String title, body;
  final IconData icon;
  final Widget? action;
  const Empty(
    this.title,
    this.body, {
    this.icon = Icons.auto_stories_outlined,
    this.action,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.6),
        ),
        const SizedBox(height: 20),
        ?action,
      ],
    ),
  );
}

class Cover extends StatelessWidget {
  final Manga m;
  final double? width, height;
  const Cover(this.m, {this.width, this.height, super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: width,
      height: height,
      child: m.source == 'local'
          ? LocalCover(m: m)
          : m.cover.isEmpty
          ? ColoredBox(
              color: const Color(0xff293a33),
              child: Center(
                child: Icon(
                  m.source == 'local' ? Icons.menu_book : Icons.image_outlined,
                  color: mint,
                  size: 36,
                ),
              ),
            )
          : m.source.startsWith('ext:')
          ? ExtensionCover(manga: m)
          : Image.network(
              m.cover,
              fit: BoxFit.cover,
              cacheWidth: 400,
              errorBuilder: (_, e, s) => const ColoredBox(
                color: Color(0xff293a33),
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: mint),
                ),
              ),
              loadingBuilder: (_, child, p) => p == null
                  ? child
                  : const ColoredBox(
                      color: Color(0xff26332c),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
    ),
  );
}

class MangaTile extends StatelessWidget {
  final Manga m;
  const MangaTile(this.m, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => openManga(context, m),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(width: double.infinity, child: Cover(m)),
        ),
        const SizedBox(height: 10),
        Text(
          m.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          m.source == 'local' ? 'ON YOUR DEVICE' : m.status.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );
}

class MangaSliverGrid extends StatelessWidget {
  final List<Manga> items;
  const MangaSliverGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Library>().settings;
    final columns = settings['columns'] as int? ?? 3;
    final ratio = (settings['coverRatio'] as num? ?? 2 / 3).toDouble();
    final spacing = (settings['spacing'] as num? ?? 14).toDouble();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.crossAxisExtent > 802
              ? columns + 2
              : columns;
          final width =
              (constraints.crossAxisExtent - spacing * (count - 1)) / count;
          final scaler = MediaQuery.textScalerOf(context);
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              mainAxisExtent:
                  width / ratio +
                  scaler.scale(13) * 2.6 +
                  scaler.scale(9) * 1.5 +
                  18,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 24,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => MangaTile(items[i]),
          );
        },
      ),
    );
  }
}

class Home extends StatelessWidget {
  final VoidCallback onDiscover;
  const Home({required this.onDiscover, super.key});
  @override
  Widget build(BuildContext context) => ReadingRoom(onDiscover: onDiscover);
}

class Discover extends StatefulWidget {
  const Discover({super.key});
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  final input = TextEditingController();
  List<Manga> items = [];
  String sort = 'followedCount', status = '', error = '';
  bool busy = false, more = true;
  int generation = 0;
  String loadedSourceId = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sourceId = context.watch<Library>().source.id;
    if (sourceId != loadedSourceId) {
      loadedSourceId = sourceId;
      sort = 'followedCount';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final token = ++generation;
    final provider = context.read<Library>().source;
    setState(() {
      busy = true;
      error = '';
      if (!append) {
        items = [];
      }
    });
    try {
      final result = await provider.search(
        query: input.text.trim(),
        offset: append ? items.length : 0,
        sort: sort,
        status: status,
      );
      if (mounted && token == generation) {
        setState(() {
          items = [...items, ...result];
          more = provider is ExtensionMangaSource
              ? provider.hasMore
              : result.length == 30;
        });
      }
    } catch (e) {
      if (mounted && token == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && token == generation) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTitle(
                'FIND SOMETHING EXTRAORDINARY',
                'Discover',
                action: IconButton(
                  tooltip: 'Sources',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const Sources()),
                    );
                  },
                  icon: const Icon(Icons.hub_outlined),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.watch<Library>().source.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (context.read<Library>().source is ExtensionMangaSource)
                      TextButton.icon(
                        onPressed: () async {
                          final source =
                              context.read<Library>().source
                                  as ExtensionMangaSource;
                          await editSourceFilters(context, source);
                          if (mounted) load();
                        },
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Filters'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: input,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => load(),
                  decoration: InputDecoration(
                    hintText: 'Search manga titles',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: load,
                      tooltip: 'Search',
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => GlobalSearch(query: input.text.trim()),
                      ),
                    ),
                    icon: const Icon(Icons.travel_explore, size: 18),
                    label: const Text('Search across your sources'),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(24),
                child: Row(
                  spacing: 10,
                  children: [
                    for (final entry in {
                      'followedCount': 'Popular',
                      if (context.read<Library>().source
                              is! ExtensionMangaSource ||
                          (context.read<Library>().source
                                  as ExtensionMangaSource)
                              .info
                              .latest)
                        'updatedAt': 'Recently updated',
                      if (context.read<Library>().source
                          is! ExtensionMangaSource)
                        'createdAt': 'New releases',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: sort == entry.key,
                        onSelected: (_) {
                          sort = entry.key;
                          load();
                        },
                      ),
                    if (context.read<Library>().source is! ExtensionMangaSource)
                      FilterChip(
                        label: const Text('Completed'),
                        selected: status == 'completed',
                        onSelected: (v) {
                          status = v ? 'completed' : '';
                          load();
                        },
                      ),
                  ],
                ),
              ),
              if (error.isNotEmpty)
                Empty(
                  'Could not reach the source',
                  error,
                  icon: Icons.cloud_off_outlined,
                  action: FilledButton(
                    onPressed: load,
                    child: const Text('Try again'),
                  ),
                ),
            ],
          ),
        ),
        MangaSliverGrid(items),
        SliverToBoxAdapter(
          child: Column(
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!busy && items.isEmpty && error.isEmpty)
                const Empty(
                  'No matches yet',
                  'Try another title or remove a filter.',
                ),
              if (!busy && more && items.isNotEmpty)
                Center(
                  child: TextButton(
                    onPressed: () => load(append: true),
                    child: const Text('Load more stories'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    ),
  );
}

class Collection extends StatefulWidget {
  const Collection({super.key});
  @override
  State<Collection> createState() => _CollectionState();
}

class _CollectionState extends State<Collection> {
  String filter = 'All',
      query = '',
      sort = 'Title',
      readingState = 'All',
      sourceFilter = 'All';
  bool updating = false;
  Future<void> import() async {
    await guard(context, () async {
      final f = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cbz'],
        withReadStream: true,
      );
      if (f == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      message(context, 'Importing archive…');
      final selected = f.files.single;
      final library = context.read<Library>();
      if (!kIsWeb && selected.path != null) {
        await library.importCbzPath(selected.name, selected.path!);
      } else {
        await library.importCbz(
          selected.name,
          await readPickedBytes(selected, maxBytes: 250 * 1024 * 1024),
        );
      }
      if (mounted) {
        message(context, 'Volume added to your library');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final list = LibraryQuery(
      query: query,
      collection: filter,
      state: readingState,
      source: sourceFilter,
      sort: sort,
    ).apply(l);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTitle(
                'COLLECT THE STORIES YOU LOVE',
                'Your library',
                action: IconButton(
                  onPressed: import,
                  tooltip: 'Import CBZ',
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search your collection',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(24),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final c in ['All', 'Favorites', ...l.categories])
                      ChoiceChip(
                        label: Text(c),
                        selected: filter == c,
                        onSelected: (_) => setState(() => filter = c),
                      ),
                    ActionChip(
                      label: const Text('+ Collection'),
                      onPressed: () => newCategory(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${list.length} ${list.length == 1 ? 'title' : 'titles'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Manage library',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ManageLibrary(),
                        ),
                      ),
                      icon: const Icon(Icons.checklist),
                    ),

                    PopupMenuButton<String>(
                      tooltip: 'Sort library',
                      onSelected: (v) => setState(() => sort = v),
                      itemBuilder: (_) =>
                          [
                                'Title',
                                'Recently added',
                                'Last read',
                                'Most unread',
                              ]
                              .map(
                                (v) => PopupMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      child: SizedBox(
                        width: 120,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sort, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sort,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Update library chapters',
                      onPressed: updating
                          ? null
                          : () async {
                              setState(() => updating = true);
                              await guard(context, () async {
                                final report = await l.updateLibrary();
                                if (context.mounted) {
                                  message(
                                    context,
                                    report['busy'] == true
                                        ? 'A library check is already running'
                                        : '${report['newChapters']} new chapters · ${report['failed']} titles need attention',
                                  );
                                }
                              });
                              if (mounted) {
                                setState(() => updating = false);
                              }
                            },
                      icon: updating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final state in [
                      'All',
                      'Unread',
                      'In progress',
                      'Finished',
                      'Downloaded',
                      'Duplicates',
                    ])
                      FilterChip(
                        label: Text(state == 'All' ? 'Any progress' : state),
                        selected: readingState == state,
                        onSelected: (_) => setState(() => readingState = state),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'Filter by source',
                      onSelected: (v) => setState(() => sourceFilter = v),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'All',
                          child: Text('All sources'),
                        ),
                        for (final id in l.saved.map((m) => m.source).toSet())
                          PopupMenuItem(
                            value: id,
                            child: Text(
                              id == 'local'
                                  ? 'On this device'
                                  : l.sourceFor(id).name,
                            ),
                          ),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.hub_outlined, size: 16),
                        label: Text(
                          sourceFilter == 'All'
                              ? 'All sources'
                              : sourceFilter == 'local'
                              ? 'On this device'
                              : l.sourceFor(sourceFilter).name,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (list.isEmpty)
                Empty(
                  'Room for your favorites',
                  'Save titles from Discover or bring your own CBZ collection.',
                  action: OutlinedButton.icon(
                    onPressed: import,
                    icon: const Icon(Icons.add),
                    label: const Text('Import a CBZ'),
                  ),
                ),
            ],
          ),
        ),
        MangaSliverGrid(list),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }
}

Future<void> newCategory(BuildContext context) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('New collection'),
      content: TextField(
        controller: controller,
        maxLength: 40,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'A name for your collection',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (value != null && value.isNotEmpty && context.mounted) {
    final l = context.read<Library>();
    l.data['categories'] = {...l.categories, value}.toList();
    await l.persist();
  }
}

class Details extends StatefulWidget {
  final Manga m;
  const Details({required this.m, super.key});
  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  bool busy = false;
  String error = '';
  bool unread = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = '';
    });
    await guard(context, () async {
      try {
        await context.read<Library>().refresh(widget.m);
      } catch (e) {
        if (mounted) {
          setState(() => error = e.toString());
        }
      }
    });
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final m = l.manga.where((m) => m.id == widget.m.id).firstOrNull ?? widget.m;
    final saved = l.section('library').containsKey(m.id);
    final chapters = l.chapters(m.id);
    final visible = chapters
        .where((c) => !unread || l.progress(c.id)['complete'] != true)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('About this story'),
        actions: [
          IconButton(
            tooltip: 'Select chapters',
            onPressed: chapters.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ChapterManager(manga: m),
                    ),
                  ),
            icon: const Icon(Icons.checklist_rounded),
          ),
          IconButton(
            tooltip: 'Refresh chapters',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Cover(m, width: 122, height: 182),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.source == 'local'
                                ? 'LOCAL LIBRARY'
                                : l.sourceFor(m.source).name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 2,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            m.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(m.author),
                          const SizedBox(height: 10),
                          Text(
                            m.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: chapters.isEmpty
                            ? null
                            : () {
                                final h = l.section('history')[m.id];
                                final c = h == null
                                    ? chapters.first
                                    : Chapter.fromJson(
                                        Map<String, dynamic>.from(h['chapter']),
                                      );
                                openReader(context, m, c);
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          l.section('history').containsKey(m.id)
                              ? 'Continue'
                              : 'Start reading',
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: saved ? 'Remove from library' : 'Add to library',
                      onPressed: () => guard(context, () => l.toggle(m)),
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                      ),
                    ),
                    if (saved)
                      IconButton(
                        tooltip: 'Favorite',
                        onPressed: () => guard(context, () async {
                          l.section('library')[m.id]['favorite'] =
                              l.section('library')[m.id]['favorite'] != true;
                          await l.persist();
                        }),
                        icon: Icon(
                          l.section('library')[m.id]['favorite'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                  ],
                ),
              ),
              if (saved)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.folder_special_outlined),
                  title: Text(
                    (l.section('library')[m.id]['collections'] as List? ??
                            [l.section('library')[m.id]['category']])
                        .join(' · '),
                  ),
                  subtitle: const Text('Collections, tags & private notes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => TitleOrganization(manga: m),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: m.tags
                      .take(10)
                      .map(
                        (t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  m.description.isEmpty
                      ? 'No synopsis supplied by this source.'
                      : m.description,
                  style: const TextStyle(height: 1.7),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${chapters.length} ${chapters.length == 1 ? 'chapter' : 'chapters'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Unread'),
                      selected: unread,
                      onSelected: (v) => setState(() => unread = v),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Chapter actions',
                      onSelected: (v) => guard(context, () async {
                        if (v == 'download') {
                          await l.enqueueBatch(m, visible);
                        } else {
                          for (final c in visible) {
                            l.section('progress')[c.id] = {
                              'page': 0,
                              'total': c.pages,
                              'complete': v == 'read',
                              'time': DateTime.now().toIso8601String(),
                            };
                          }
                          await l.persist();
                        }
                      }),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'download',
                          child: Text('Download listed chapters'),
                        ),
                        PopupMenuItem(
                          value: 'read',
                          child: Text('Mark listed as read'),
                        ),
                        PopupMenuItem(
                          value: 'unread',
                          child: Text('Mark listed as unread'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error.isNotEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Text(error)),
              if (!busy && chapters.isEmpty)
                const Empty(
                  'No chapters in this language',
                  'Try another chapter language in Sources, then refresh.',
                ),
            ],
          ),
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final c = visible[index];
              final read = l.progress(c.id)['complete'] == true;
              final job = l.section('downloads')[c.id];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 5,
                ),
                leading: Icon(
                  read ? Icons.check_circle_outline : Icons.article_outlined,
                  color: read ? mint : null,
                ),
                title: Text(
                  'Chapter ${c.number}',
                  style: TextStyle(color: read ? Colors.grey : null),
                ),
                subtitle: Text(
                  c.title.isEmpty
                      ? '${c.pages} pages · ${c.language}'
                      : c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => openReader(context, m, c),
                onLongPress: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChapterManager(manga: m, initial: c.id),
                  ),
                ),
                trailing: IconButton(
                  tooltip: job?['status'] == 'complete'
                      ? 'Downloaded'
                      : 'Download chapter',
                  onPressed: job?['status'] == 'complete'
                      ? null
                      : () => guard(context, () => l.enqueue(m, c)),
                  icon: Icon(
                    job?['status'] == 'complete'
                        ? Icons.offline_pin_outlined
                        : Icons.download_outlined,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }
}

class Activity extends StatelessWidget {
  const Activity({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final entries = l.section('history').entries.toList()
      ..sort(
        (a, b) => (DateTime.tryParse(b.value['time']) ?? DateTime(1970))
            .compareTo(DateTime.tryParse(a.value['time']) ?? DateTime(1970)),
      );
    final titles = {for (final m in l.manga) m.id: m};
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              PageTitle(
                'EVERY CHAPTER COUNTS',
                'Your journey',
                action: IconButton(
                  tooltip: 'Downloads',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const Downloads()),
                  ),
                  icon: const Icon(Icons.download_outlined),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.download_done_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Download manager'),
                subtitle: const Text('Queue, offline chapters & storage'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const Downloads()),
                ),
              ),
              const ReadingStats(),
              ListTile(
                leading: const Icon(Icons.bookmarks_outlined),
                title: const Text('Saved pages'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const Bookmarks()),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Reading history',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              if (entries.isEmpty)
                const Empty(
                  'A fresh beginning',
                  'Your reading history appears as you explore chapters.',
                ),
            ],
          ),
        ),
        SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            final m = titles[e.key];
            if (m == null) {
              return const SizedBox.shrink();
            }
            final c = Chapter.fromJson(
              Map<String, dynamic>.from(e.value['chapter']),
            );
            final time = DateTime.tryParse(e.value['time'])?.toLocal();
            final date = time == null
                ? 'Unknown date'
                : MaterialLocalizations.of(context).formatMediumDate(time);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 10,
              ),
              leading: Cover(m, width: 48, height: 68),
              title: Text(m.title, maxLines: 2),
              subtitle: Text(
                'Ch. ${c.number} · Page ${(e.value['page'] as int) + 1}\n$date',
              ),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => openReader(context, m, c),
            );
          },
        ),
      ],
    );
  }
}

class Downloads extends StatelessWidget {
  const Downloads({super.key});
  String downloadStatus(String state) => switch (state) {
    'downloading' => 'Downloading',
    'queued' => 'In queue',
    'paused' => 'Paused',
    'failed' => 'Needs a retry',
    'complete' => 'Ready offline',
    _ => state,
  };
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final jobs = l.section('downloads').entries.toList()
      ..sort((a, b) {
        int rank(String status) => switch (status) {
          'downloading' => 0,
          'queued' => 1,
          'failed' => 2,
          'paused' => 3,
          _ => 4,
        };
        final status = rank(a.value['status'])
            .compareTo(rank(b.value['status']));
        if (status != 0) return status;
        final priority = (b.value['priority'] as int? ?? 0).compareTo(
          a.value['priority'] as int? ?? 0,
        );
        return priority != 0
            ? priority
            : (a.value['queuedAt'] as int? ?? 0).compareTo(
                b.value['queuedAt'] as int? ?? 0,
              );
      });
    final titles = {for (final m in l.manga) m.id: m};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Pause all',
            onPressed: () => guard(context, l.pauseAllDownloads),
            icon: const Icon(Icons.pause_circle_outline),
          ),
          IconButton(
            tooltip: 'Resume all',
            onPressed: () => guard(context, l.resumeAllDownloads),
            icon: const Icon(Icons.play_circle_outline),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (l.downloadError != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.downloadError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FutureBuilder<int>(
                  future: l.storage.bytesUsed(),
                  builder: (_, s) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${((s.data ?? 0) / 1048576).toStringAsFixed(1)} MB in chapter downloads',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Android keeps active downloads running with a progress notification. You can pause there or here. If Android stops the app, resume your saved queue when you return.',
                  ),
                ),
                if (jobs.isEmpty)
                  const Empty(
                    'Take your stories with you',
                    'Download chapters from a title’s chapter list to read without a connection.',
                    icon: Icons.cloud_download_outlined,
                  ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final e = jobs[index];
              final j = e.value;
              final c = Chapter.fromJson(
                Map<String, dynamic>.from(j['chapter']),
              );
              final m = titles[c.mangaId];
              return Card(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m?.title ?? 'Chapter',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ch. ${c.number} · ${downloadStatus(j['status'])} · ${j['done']}/${j['total']} pages',
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (j['total'] as int) > 0
                            ? (j['done'] as int) / (j['total'] as int)
                            : 0,
                      ),
                      if (j['error'] != null) Text(j['error'], maxLines: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (j['status'] == 'complete')
                            TextButton(
                              onPressed: m == null
                                  ? null
                                  : () => openReader(context, m, c),
                              child: const Text('Read offline'),
                            )
                          else
                            IconButton(
                              tooltip:
                                  [
                                    'downloading',
                                    'queued',
                                  ].contains(j['status'])
                                  ? 'Pause'
                                  : 'Resume',
                              onPressed: () => guard(context, () async {
                                if (j['status'] == 'downloading' ||
                                    j['status'] == 'queued') {
                                  await l.pause(e.key);
                                } else {
                                  await l.resumeDownload(e.key);
                                }
                              }),
                              icon: Icon(
                                ['downloading', 'queued'].contains(j['status'])
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                            ),
                          if (j['status'] != 'complete')
                            IconButton(
                              tooltip: 'Move to front of queue',
                              onPressed: () =>
                                  guard(context, () => l.prioritize(e.key)),
                              icon: const Icon(Icons.vertical_align_top),
                            ),
                          IconButton(
                            tooltip: 'Delete downloaded pages',
                            onPressed: () => guard(context, () async {
                              final remove = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Remove offline pages?'),
                                  content: Text(
                                    m?.source == 'local'
                                        ? 'Keep your original CBZ file so you can import this volume again. Your reading history will stay.'
                                        : 'You can download this chapter again from its source. Your reading history will stay.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Keep pages'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (remove == true) await l.removeDownload(e.key);
                            }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class Sources extends StatelessWidget {
  const Sources({super.key});
  @override
  Widget build(BuildContext context) => const SourceHub();
}

class Preferences extends StatelessWidget {
  const Preferences({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final s = l.settings;
    return ListView(
      children: [
        const PageTitle('MAKE IT YOURS', 'Settings'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 10,
            children: [
              for (final mode in ['light', 'dark', 'amoled'])
                ChoiceChip(
                  label: Text(mode[0].toUpperCase() + mode.substring(1)),
                  selected: (s['theme'] ?? 'dark') == mode,
                  onSelected: (_) =>
                      guard(context, () => l.setting('theme', mode)),
                ),
            ],
          ),
        ),
        ListTile(
          title: const Text('Accent color'),
          subtitle: const Text('A little more you'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, color) in [
                ('Mint', mint),
                ('Lavender', const Color(0xffbcb4ff)),
                ('Apricot', const Color(0xffffc79b)),
              ])
                IconButton(
                  tooltip: '$label accent',
                  isSelected:
                      (s['accent'] ?? mint.toARGB32()) == color.toARGB32(),
                  selectedIcon: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => guard(
                    context,
                    () => l.setting('accent', color.toARGB32()),
                  ),
                  icon: Icon(Icons.circle, color: color),
                ),
            ],
          ),
        ),
        ListTile(
          title: const Text('Library columns'),
          trailing: DropdownButton<int>(
            value: s['columns'] as int? ?? 3,
            items: [2, 3, 4]
                .map((i) => DropdownMenuItem(value: i, child: Text('$i')))
                .toList(),
            onChanged: (v) => guard(context, () => l.setting('columns', v)),
          ),
        ),
        ListTile(
          title: const Text('Cover shape'),
          trailing: DropdownButton<double>(
            value: (s['coverRatio'] as num? ?? 2 / 3).toDouble(),
            items: const [
              DropdownMenuItem(value: 2 / 3, child: Text('Portrait')),
              DropdownMenuItem(value: .75, child: Text('Classic')),
              DropdownMenuItem(value: 1.0, child: Text('Square')),
            ],
            onChanged: (v) => guard(context, () => l.setting('coverRatio', v)),
          ),
        ),
        ListTile(
          title: const Text('Shelf spacing'),
          trailing: DropdownButton<int>(
            value: s['spacing'] as int? ?? 14,
            items: const [
              DropdownMenuItem(value: 8, child: Text('Compact')),
              DropdownMenuItem(value: 14, child: Text('Balanced')),
              DropdownMenuItem(value: 20, child: Text('Airy')),
            ],
            onChanged: (v) => guard(context, () => l.setting('spacing', v)),
          ),
        ),
        ListTile(
          title: const Text('Text size'),
          subtitle: const Text('Works with your Android font size'),
          trailing: DropdownButton<double>(
            value: (s['textScale'] as num? ?? 1).toDouble(),
            items: const [
              DropdownMenuItem(value: 1.0, child: Text('Default')),
              DropdownMenuItem(value: 1.15, child: Text('Larger')),
              DropdownMenuItem(value: 1.3, child: Text('Largest')),
            ],
            onChanged: (v) => guard(context, () => l.setting('textScale', v)),
          ),
        ),
        SwitchListTile(
          title: const Text('Reduce motion'),
          subtitle: const Text('Calmer transitions and page navigation'),
          value: s['reduceMotion'] == true,
          onChanged: (v) => guard(context, () => l.setting('reduceMotion', v)),
        ),
        const Divider(indent: 24, endIndent: 24),
        ListTile(
          leading: const Icon(Icons.hub_outlined),
          title: const Text('Sources & extensions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const Sources()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.update_outlined),
          title: const Text('Library updates'),
          subtitle: Text(
            (s['updateHours'] ?? 0) == 0
                ? 'Check manually or choose a schedule'
                : 'Every ${s['updateHours']} hours',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LibraryUpdatesScreen(),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.auto_stories_outlined),
          title: const Text('Default reading mode'),
          trailing: DropdownButton<String>(
            value: s['readerMode'] ?? 'paged',
            items: const [
              DropdownMenuItem(value: 'paged', child: Text('Horizontal')),
              DropdownMenuItem(
                value: 'vertical',
                child: Text('Vertical pages'),
              ),
              DropdownMenuItem(value: 'webtoon', child: Text('Continuous')),
            ],
            onChanged: (v) => guard(context, () => l.setting('readerMode', v)),
          ),
        ),
        SwitchListTile(
          title: const Text('Right-to-left reading'),
          value: s['rtl'] == true,
          onChanged: (v) => guard(context, () => l.setting('rtl', v)),
        ),
        SwitchListTile(
          title: const Text('Keep screen awake in reader'),
          value: s['awake'] != false,
          onChanged: (v) => guard(context, () => l.setting('awake', v)),
        ),
        SwitchListTile(
          title: const Text('Volume keys turn pages'),
          subtitle: const Text('While the reader is open'),
          value: s['volume'] != false,
          onChanged: (v) => guard(context, () => l.setting('volume', v)),
        ),
        const Divider(indent: 24, endIndent: 24),
        if (BackgroundDownloads.available)
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Download notifications'),
            subtitle: const Text('Manage Android notification controls'),
            onTap: () => guard(
              context,
              () => BackgroundDownloads.channel.invokeMethod<void>(
                'notificationSettings',
              ),
            ),
          ),
        ListTile(
          title: const Text('Reading image memory'),
          subtitle: const Text('A smaller cache uses less RAM'),
          trailing: DropdownButton<int>(
            value: s['imageCacheMb'] as int? ?? 96,
            items: [32, 64, 96, 128]
                .map((v) => DropdownMenuItem(value: v, child: Text('$v MB')))
                .toList(),
            onChanged: (v) =>
                guard(context, () => l.setting('imageCacheMb', v)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clear reading cache'),
          subtitle: const Text('Downloaded chapters stay on your device'),
          onTap: () {
            l.pageCache.clear();
            l.covers.clear();
            PaintingBinding.instance.imageCache.clear();
            message(context, 'Reading cache cleared');
          },
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Export library backup'),
          subtitle: const Text('Metadata, progress, bookmarks & collections'),
          onTap: () => guard(context, () async {
            final raw = l.backup();
            await FilePicker.platform.saveFile(
              dialogTitle: 'Export StarReader backup',
              fileName:
                  'StarReader-${DateTime.now().toIso8601String().substring(0, 10)}.json',
              type: FileType.custom,
              allowedExtensions: ['json'],
              bytes: Uint8List.fromList(utf8.encode(raw)),
            );
          }),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore a backup'),
          subtitle: const Text('Merge a StarReader JSON backup'),
          onTap: () => guard(context, () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['json'],
              withReadStream: true,
            );
            if (result == null) {
              return;
            }
            await l.restore(
              utf8.decode(
                await readPickedBytes(
                  result.files.single,
                  maxBytes: 20 * 1024 * 1024,
                ),
              ),
            );
            if (context.mounted) {
              message(context, 'Backup merged successfully');
            }
          }),
        ),
        ListTile(
          leading: const Icon(Icons.move_to_inbox_outlined),
          title: const Text('Import from Mihon'),
          subtitle: const Text('Library, chapters, history & reading progress'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => guard(context, () async {
            final file = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['tachibk', 'proto', 'gz'],
              withReadStream: true,
            );
            if (file == null || !context.mounted) return;
            final imported = MihonImport.parse(
              await readPickedBytes(
                file.files.single,
                maxBytes: 20 * 1024 * 1024,
              ),
            );
            if (!context.mounted) return;
            final approved = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Bring your library over?'),
                content: Text(
                  '${imported.titles} titles · ${imported.chapters} chapters · ${imported.sourceIds.length} sources\n\nReading progress, chapter bookmarks, collections and history will be merged. Reinstall the matching extensions to read online.\n\nDownloaded pages, source credentials and tracker accounts are not included.${imported.skippedLocal > 0 ? '\n\n${imported.skippedLocal} local or unsupported source entries will be skipped.' : ''}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Import library'),
                  ),
                ],
              ),
            );
            if (approved == true) {
              await l.restore(imported.starReaderBackup);
              if (context.mounted) {
                message(
                  context,
                  '${imported.titles} titles imported. Add their sources in Sources & extensions.',
                );
              }
            }
          }),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            'Backups contain metadata only. Keep original CBZ files separately and re-download online chapters after moving devices. Mihon import supports the standard gzip/protobuf library format. Extension trust and account credentials are never imported.',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Export diagnostics'),
          subtitle: const Text(
            'App and extension versions, without reading history',
          ),
          onTap: () => guard(context, () async {
            final report = const JsonEncoder.withIndent('  ')
                .convert(await diagnostics(l));
            await FilePicker.platform.saveFile(
              fileName: 'StarReader-diagnostics.json',
              type: FileType.custom,
              allowedExtensions: ['json'],
              bytes: Uint8List.fromList(utf8.encode(report)),
            );
          }),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Private by design'),
          subtitle: const Text(
            'StarReader has no account, advertising or analytics. Repositories, extensions and source websites have their own privacy policies.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('StarReader 0.2.0'),
          subtitle: const Text('An independent reading space'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'StarReader',
            applicationVersion: '0.2.0',
            applicationLegalese: 'Independent application. Not affiliated with Mihon or MangaDex. Manrope and Newsreader fonts © their authors, SIL Open Font License. Open-source notices are listed below.',
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class LocalCover extends StatefulWidget {
  final Manga m;
  const LocalCover({required this.m, super.key});
  @override
  State<LocalCover> createState() => _LocalCoverState();
}

class _LocalCoverState extends State<LocalCover> {
  late Future<Uint8List?> bytes;
  @override
  void initState() {
    super.initState();
    final l = context.read<Library>();
    final chapter = l.chapters(widget.m.id).firstOrNull;
    bytes = chapter == null
        ? Future.value()
        : l.covers.get('local:${chapter.id}', () async {
            final page = await l.storage.page(chapter.id, 0);
            if (page == null) {
              throw const FormatException('Local cover is unavailable');
            }
            return page;
          });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (_, s) => s.data == null
        ? const ColoredBox(
            color: Color(0xff293a33),
            child: Center(child: Icon(Icons.menu_book, color: mint)),
          )
        : Image.memory(
            s.data!,
            fit: BoxFit.cover,
            cacheWidth: 400,
            errorBuilder: (_, e, stack) => const Icon(Icons.menu_book),
          ),
  );
}
