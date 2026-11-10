import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'core/library.dart';
import 'core/models.dart';
import 'core/storage.dart';
import 'reader.dart';
import 'enhancements.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 * 1024 * 1024;
  final library = Library(Storage());
  await library.init();
  runApp(
    ChangeNotifierProvider.value(value: library, child: const StarReader()),
  );
}

const mint = Color(0xffbdedd0);

class StarReader extends StatelessWidget {
  const StarReader({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Library>().settings;
    final mode = s['theme'] ?? 'dark';
    final accent = Color(s['accent'] as int? ?? mint.toARGB32());
    ThemeData theme(Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: 'Manrope',
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: b,
        primary: b == Brightness.dark ? accent : const Color(0xff286345),
      ),
      scaffoldBackgroundColor: b == Brightness.dark
          ? (mode == 'amoled' ? Colors.black : const Color(0xff101513))
          : const Color(0xfff5f7f2),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 76),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    return MaterialApp(
      title: 'StarReader',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: mode == 'light' ? ThemeMode.light : ThemeMode.dark,
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
                    'No account. No advertising. No analytics.\nConnect to MangaDex or import your own CBZ files.',
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
  @override
  Widget build(BuildContext context) {
    final pages = [
      Home(onDiscover: () => setState(() => tab = 2)),
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
                onDestinationSelected: (v) => setState(() => tab = v),
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
              child: IndexedStack(index: tab, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width > 850
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() => tab = v),
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

class MangaGrid extends StatelessWidget {
  final List<Manga> items;
  const MangaGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    final columns = context.watch<Library>().settings['columns'] as int? ?? 3;
    return LayoutBuilder(
      builder: (_, box) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: box.maxWidth > 850 ? 6 : columns,
          childAspectRatio: .53,
          crossAxisSpacing: 14,
          mainAxisSpacing: 24,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => MangaTile(items[i]),
      ),
    );
  }
}

class Home extends StatelessWidget {
  final VoidCallback onDiscover;
  const Home({required this.onDiscover, super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final history = l.section('history').entries.toList()
      ..sort((a, b) => (b.value['time'] as String).compareTo(a.value['time']));
    return ListView(
      children: [
        PageTitle(
          'YOUR NEXT CHAPTER STARTS HERE',
          'The reading room',
          action: IconButton(
            tooltip: 'Downloads',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const Downloads()),
            ),
            icon: const Icon(Icons.downloading_outlined),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xff345344), Color(0xff1b3027)],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MAKE TIME FOR A GOOD STORY',
                      style: TextStyle(
                        color: mint,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'One more\nchapter.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onDiscover,
                      icon: const Icon(Icons.north_east, size: 17),
                      label: const Text('Find your next read'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.auto_awesome, size: 72, color: mint),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _stat('${l.saved.length}', 'IN LIBRARY'),
              _stat(
                '${l.section('progress').values.where((p) => p['complete'] == true).length}',
                'CHAPTERS READ',
              ),
              _stat(
                '${l.section('downloads').values.where((p) => p['status'] == 'complete').length}',
                'OFFLINE',
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Continue reading',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        if (history.isEmpty)
          Empty(
            'Your story starts here',
            'Open a chapter and your reading spot will be waiting here.',
            action: TextButton(
              onPressed: onDiscover,
              child: const Text('Explore the catalogue →'),
            ),
          )
        else
          ...history.take(5).map((e) {
            final m = l.manga.where((m) => m.id == e.key).firstOrNull;
            if (m == null) {
              return const SizedBox.shrink();
            }
            final c = Chapter.fromJson(
              Map<String, dynamic>.from(e.value['chapter']),
            );
            return Card(
              margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Cover(m, width: 48, height: 68),
                title: Text(
                  m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Chapter ${c.number} · Page ${(e.value['page'] as int) + 1}',
                ),
                trailing: const Icon(Icons.play_circle_outline, color: mint),
                onTap: () => openReader(context, m, c),
              ),
            );
          }),
        const SizedBox(height: 26),
        if (l.saved.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Your collection',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          MangaGrid(l.saved.reversed.take(6).toList()),
        ],
        const CatalogueRail(
          title: 'Popular on MangaDex',
          sort: 'followedCount',
        ),
        const CatalogueRail(title: 'Recently updated', sort: 'updatedAt'),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _stat(String n, String text) => Expanded(
    child: Column(
      children: [
        Text(
          n,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontSize: 8, letterSpacing: 1.2)),
      ],
    ),
  );
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
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final token = ++generation;
    setState(() {
      busy = true;
      error = '';
      if (!append) {
        items = [];
      }
    });
    try {
      final result = await context.read<Library>().source.search(
        query: input.text.trim(),
        offset: append ? items.length : 0,
        sort: sort,
        status: status,
      );
      if (mounted && token == generation) {
        setState(() {
          items = [...items, ...result];
          more = result.length == 30;
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
    child: ListView(
      children: [
        PageTitle(
          'FIND SOMETHING EXTRAORDINARY',
          'Discover',
          action: IconButton(
            tooltip: 'Sources',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const Sources()),
            ),
            icon: const Icon(Icons.hub_outlined),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(24),
          child: Row(
            spacing: 10,
            children: [
              for (final entry in {
                'followedCount': 'Popular',
                'updatedAt': 'Recently updated',
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
        MangaGrid(items),
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
  );
}

class Collection extends StatefulWidget {
  const Collection({super.key});
  @override
  State<Collection> createState() => _CollectionState();
}

class _CollectionState extends State<Collection> {
  String filter = 'All', query = '', sort = 'Title';
  bool updating = false;
  Future<void> import() async {
    await guard(context, () async {
      final f = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cbz'],
        withData: true,
      );
      if (f == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      message(context, 'Importing archive…');
      await context.read<Library>().importCbz(
        f.files.single.name,
        f.files.single.bytes!,
      );
      if (mounted) {
        message(context, 'Volume added to your library');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final list =
        l.saved
            .where(
              (m) =>
                  m.title.toLowerCase().contains(query.toLowerCase()) &&
                  (filter == 'All' ||
                      (filter == 'Favorites'
                          ? l.section('library')[m.id]['favorite'] == true
                          : l.section('library')[m.id]['category'] == filter)),
            )
            .toList()
          ..sort(
            (a, b) => sort == 'Title'
                ? a.title.compareTo(b.title)
                : (l.section('library')[b.id]['added'] as String).compareTo(
                    l.section('library')[a.id]['added'] as String,
                  ),
          );
    return ListView(
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
              Text('${list.length} titles'),
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
              const Spacer(),
              DropdownButton<String>(
                value: sort,
                items: ['Title', 'Recently added']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => sort = v!),
              ),
              IconButton(
                tooltip: 'Update library chapters',
                onPressed: updating
                    ? null
                    : () async {
                        setState(() => updating = true);
                        await guard(context, () async {
                          for (final m in l.saved) {
                            await l.refresh(m);
                          }
                          if (context.mounted) {
                            message(context, 'Library chapters updated');
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
        MangaGrid(list),
        const SizedBox(height: 30),
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
    final m = widget.m;
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
                            m.source.toUpperCase(),
                            style: const TextStyle(
                              color: mint,
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
                      onPressed: () => l.toggle(m),
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                      ),
                    ),
                    if (saved)
                      IconButton(
                        tooltip: 'Favorite',
                        onPressed: () {
                          l.section('library')[m.id]['favorite'] =
                              l.section('library')[m.id]['favorite'] != true;
                          l.persist();
                        },
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DropdownButton<String>(
                    value:
                        l.categories.contains(
                          l.section('library')[m.id]['category'],
                        )
                        ? l.section('library')[m.id]['category']
                        : l.categories.first,
                    items: l.categories
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      l.section('library')[m.id]['category'] = v;
                      l.persist();
                    },
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
                        '${chapters.length} chapters',
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
                          for (final c in visible) {
                            await l.enqueue(m, c);
                          }
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
                trailing: IconButton(
                  tooltip: job?['status'] == 'complete'
                      ? 'Downloaded'
                      : 'Download chapter',
                  onPressed: job?['status'] == 'complete'
                      ? null
                      : () => l.enqueue(m, c),
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
      ..sort((a, b) => (b.value['time'] as String).compareTo(a.value['time']));
    return ListView(
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
          leading: const Icon(Icons.download_done_outlined, color: mint),
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
        ...entries.map((e) {
          final m = l.manga.where((m) => m.id == e.key).firstOrNull;
          if (m == null) {
            return const SizedBox.shrink();
          }
          final c = Chapter.fromJson(
            Map<String, dynamic>.from(e.value['chapter']),
          );
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 10,
            ),
            leading: Cover(m, width: 48, height: 68),
            title: Text(m.title, maxLines: 2),
            subtitle: Text(
              'Ch. ${c.number} · Page ${(e.value['page'] as int) + 1}\n${(e.value['time'] as String).substring(0, 10)}',
            ),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => openReader(context, m, c),
          );
        }),
      ],
    );
  }
}

class Downloads extends StatelessWidget {
  const Downloads({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final jobs = l.section('downloads').entries.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Pause all',
            onPressed: () {
              for (final e in jobs) {
                if (['queued', 'downloading'].contains(e.value['status'])) {
                  l.pause(e.key);
                }
              }
            },
            icon: const Icon(Icons.pause_circle_outline),
          ),
          IconButton(
            tooltip: 'Resume all',
            onPressed: () {
              for (final e in jobs) {
                if (['paused', 'failed'].contains(e.value['status'])) {
                  e.value['status'] = 'queued';
                }
              }
              l.persist();
              l.runQueue();
            },
            icon: const Icon(Icons.play_circle_outline),
          ),
        ],
      ),
      body: ListView(
        children: [
          FutureBuilder<int>(
            future: l.storage.bytesUsed(),
            builder: (_, s) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${((s.data ?? 0) / 1048576).toStringAsFixed(1)} MB on your device',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Downloads run while StarReader is open. Interrupted jobs can be resumed. Keep the app open until your queue finishes.',
            ),
          ),
          if (jobs.isEmpty)
            const Empty(
              'Take your stories with you',
              'Download chapters from a title’s chapter list to read without a connection.',
              icon: Icons.cloud_download_outlined,
            ),
          ...jobs.map((e) {
            final j = e.value;
            final c = Chapter.fromJson(Map<String, dynamic>.from(j['chapter']));
            final m = l.manga.where((m) => m.id == c.mangaId).firstOrNull;
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
                      'Ch. ${c.number} · ${j['status']} · ${j['done']}/${j['total']} pages',
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
                            tooltip: j['status'] == 'downloading'
                                ? 'Pause'
                                : 'Resume',
                            onPressed: () {
                              if (j['status'] == 'downloading' ||
                                  j['status'] == 'queued') {
                                l.pause(e.key);
                              } else {
                                j['status'] = 'queued';
                                l.persist();
                                l.runQueue();
                              }
                            },
                            icon: Icon(
                              j['status'] == 'downloading'
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Delete downloaded pages',
                          onPressed: () =>
                              guard(context, () => l.removeDownload(e.key)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class Sources extends StatefulWidget {
  const Sources({super.key});
  @override
  State<Sources> createState() => _SourcesState();
}

class _SourcesState extends State<Sources> {
  String health = 'Not checked';
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sources & extensions')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Your connection\nto more stories.',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.language, color: mint),
                    title: Text('MangaDex'),
                    subtitle: Text('Built-in source · API integration'),
                  ),
                  Text(health),
                  TextButton.icon(
                    onPressed: () async {
                      setState(() => health = 'Checking…');
                      try {
                        await l.source.health();
                        if (mounted) {
                          setState(
                            () => health =
                                'Reachable · source responded successfully',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => health = e.toString());
                        }
                      }
                    },
                    icon: const Icon(Icons.network_check),
                    label: const Text('Check connection'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: l.settings['language'] ?? 'en',
                    decoration: const InputDecoration(
                      labelText: 'Chapter language',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                      DropdownMenuItem(value: 'es', child: Text('Spanish')),
                      DropdownMenuItem(
                        value: 'pt-br',
                        child: Text('Portuguese (Brazil)'),
                      ),
                      DropdownMenuItem(value: 'fr', child: Text('French')),
                    ],
                    onChanged: (v) => l.setting('language', v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(20),
              leading: Icon(Icons.folder_open, color: mint),
              title: Text('Local library'),
              subtitle: Text(
                'Import CBZ archives from the Library. Files stay in private app storage.',
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Extension compatibility',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'StarReader has a Dart source adapter interface. Mihon APK extensions require a native Android plugin runtime and are not supported by this release. No extension APKs are installed or executed.\n\nMangaDex availability and chapter languages are controlled by the source. External or unavailable chapters are omitted. Respect each creator’s rights and the source’s terms.',
            style: TextStyle(height: 1.7),
          ),
        ],
      ),
    );
  }
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
                  onSelected: (_) => l.setting('theme', mode),
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
              for (final color in [
                mint,
                const Color(0xffbcb4ff),
                const Color(0xffffc79b),
              ])
                IconButton(
                  tooltip: 'Choose accent',
                  onPressed: () => l.setting('accent', color.toARGB32()),
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
            onChanged: (v) => l.setting('columns', v),
          ),
        ),
        const Divider(indent: 24, endIndent: 24),
        ListTile(
          leading: const Icon(Icons.hub_outlined),
          title: const Text('Sources & languages'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const Sources()),
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
            onChanged: (v) => l.setting('readerMode', v),
          ),
        ),
        SwitchListTile(
          title: const Text('Right-to-left reading'),
          value: s['rtl'] == true,
          onChanged: (v) => l.setting('rtl', v),
        ),
        SwitchListTile(
          title: const Text('Keep screen awake in reader'),
          value: s['awake'] != false,
          onChanged: (v) => l.setting('awake', v),
        ),
        SwitchListTile(
          title: const Text('Volume keys turn pages'),
          subtitle: const Text('While the reader is open'),
          value: s['volume'] != false,
          onChanged: (v) => l.setting('volume', v),
        ),
        const Divider(indent: 24, endIndent: 24),
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
              withData: true,
            );
            if (result == null) {
              return;
            }
            await l.restore(utf8.decode(result.files.single.bytes!));
            if (context.mounted) {
              message(context, 'Backup merged successfully');
            }
          }),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            'Backups contain metadata only. Keep original CBZ files separately and re-download online chapters after moving devices. Mihon protobuf backups are not supported.',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Private by design'),
          subtitle: const Text(
            'No account, analytics, ads or tracking. Network requests go to your selected content source.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('StarReader 1.0.0'),
          subtitle: const Text('An independent reading space'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'StarReader',
            applicationVersion: '1.0.0',
            applicationLegalese: 'Independent application. Not affiliated with Mihon or MangaDex. Manrope font © its authors, SIL Open Font License.',
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
    bytes = chapter == null ? Future.value() : l.storage.page(chapter.id, 0);
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
