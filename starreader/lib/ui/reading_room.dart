import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/library.dart';
import '../core/models.dart';
import '../main.dart' show Cover, MangaTile, Downloads, Sources;
import '../enhancements.dart' show CatalogueRail, ReadingStats;
import '../reader.dart';
import 'design.dart';
import 'library_updates_screen.dart';

class ReadingRoom extends StatelessWidget {
  final VoidCallback onDiscover;
  const ReadingRoom({required this.onDiscover, super.key});
  @override
  Widget build(BuildContext context) {
    final library = context.watch<Library>();
    final colors = Theme.of(context).colorScheme;
    final history = library.section('history').entries.toList()
      ..sort((a, b) => (b.value['time'] as String).compareTo(a.value['time']));
    final resume = history
        .where((h) => library.manga.any((m) => m.id == h.key))
        .firstOrNull;
    final recent = library.saved.toList()
      ..sort(
        (a, b) => library
            .section('library')[b.id]['added']
            .toString()
            .compareTo(library.section('library')[a.id]['added'].toString()),
      );
    final favorites = library.saved
        .where((m) => library.section('library')[m.id]['favorite'] == true)
        .toList();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 16, 22),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Text(
                      'The reading room',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Downloads',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const Downloads()),
                ),
                icon: const Icon(Icons.downloading_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 650;
              final story = resume == null
                  ? null
                  : library.manga.firstWhere((m) => m.id == resume.key);
              final chapter = resume == null
                  ? null
                  : Chapter.fromJson(
                      Map<String, dynamic>.from(resume.value['chapter']),
                    );
              final page = (resume?.value['page'] as int? ?? 0) + 1;
              final total = resume?.value['total'] as int? ?? 1;
              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: const Color(0xff243c31),
                  border: Border.all(color: const Color(0xff40594b)),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      right: -45,
                      top: -45,
                      width: 270,
                      height: 270,
                      child: Opacity(opacity: .55, child: OrbitArt()),
                    ),
                    Padding(
                      padding: EdgeInsets.all(wide ? 32 : 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Eyebrow(
                                  story == null
                                      ? 'A LITTLE TIME, ANOTHER WORLD'
                                      : 'RIGHT WHERE YOU LEFT OFF',
                                  color: starGold,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  story == null
                                      ? 'Make room for\none more chapter.'
                                      : story.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Newsreader',
                                    fontSize: wide ? 44 : 33,
                                    height: 1.02,
                                    color: const Color(0xfff4f4e9),
                                    letterSpacing: -.7,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  story == null
                                      ? 'A quiet corner for the stories\nyou can’t put down.'
                                      : 'Chapter ${chapter!.number.isEmpty ? chapter.title : chapter.number} · page $page of $total',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xffc0d0c4),
                                    fontSize: 12,
                                    height: 1.65,
                                  ),
                                ),
                                if (story != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 18,
                                      right: 16,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (page / total.clamp(1, 100000))
                                            .clamp(0, 1),
                                        minHeight: 3,
                                        backgroundColor: Colors.white12,
                                        color: starGold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: starMint,
                                    foregroundColor: const Color(0xff173126),
                                  ),
                                  onPressed: story == null
                                      ? onDiscover
                                      : () => openReader(
                                          context,
                                          story,
                                          chapter!,
                                        ),
                                  icon: Icon(
                                    story == null
                                        ? Icons.north_east
                                        : Icons.play_arrow_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    story == null
                                        ? 'Find your next read'
                                        : 'Continue reading',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (story != null && box.maxWidth > 320) ...[
                            const SizedBox(width: 20),
                            Transform.rotate(
                              angle: .055,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 24,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Cover(
                                  story,
                                  width: wide ? 155 : 103,
                                  height: wide ? 220 : 154,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Your reading rhythm')),
                  body: const SingleChildScrollView(child: ReadingStats()),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .7),
                ),
              ),
              child: Row(
                children: [
                  _Metric('${library.saved.length}', 'in your library'),
                  Container(height: 28, width: 1, color: colors.outlineVariant),
                  _Metric(
                    '${library.section('progress').values.where((p) => p['complete'] == true).length}',
                    'chapters read',
                  ),
                  Container(height: 28, width: 1, color: colors.outlineVariant),
                  _Metric(
                    '${library.section('downloads').values.where((p) => p['status'] == 'complete').length}',
                    'ready offline',
                  ),
                ],
              ),
            ),
          ),
        ),
        if (history.length > 1) ...[
          const _Heading('Pick up another story', 'YOUR READING SHELF'),
          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: history.skip(1).take(6).length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final entry = history[i + 1];
                final story = library.manga
                    .where((m) => m.id == entry.key)
                    .firstOrNull;
                if (story == null) return const SizedBox.shrink();
                final chapter = Chapter.fromJson(
                  Map<String, dynamic>.from(entry.value['chapter']),
                );
                return SizedBox(
                  width: 285,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => openReader(context, story, chapter),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Cover(story, width: 52, height: 78),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    story.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Chapter ${chapter.number} · p.${(entry.value['page'] as int) + 1}',
                                    style: Theme.of(c).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Icon(
                Icons.markunread_mailbox_outlined,
                color: colors.primary,
              ),
              title: const Text(
                'Fresh from your library',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                library.section('updates').isEmpty
                    ? 'See what your stories have been up to'
                    : '${library.section('updates').length} new chapters discovered',
              ),
              trailing: const Icon(Icons.arrow_forward, size: 20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LibraryUpdatesScreen(),
                ),
              ),
            ),
          ),
        ),
        if (recent.isNotEmpty) ...[
          const _Heading('Recently added', 'A SHELF OF YOUR OWN'),
          _Shelf(recent.take(12).toList()),
        ],
        if (favorites.isNotEmpty) ...[
          const _Heading('The ones you love', 'YOUR FAVORITES'),
          _Shelf(favorites.take(12).toList()),
        ],
        if (library.extensions.repositories.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: Icon(Icons.travel_explore, color: colors.primary),
                title: const Text(
                  'More worlds to discover',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Add an extension repository and choose your sources.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const Sources()),
                ),
              ),
            ),
          ),
        CatalogueRail(
          key: ValueKey('${library.source.id}:popular'),
          title: 'Popular on ${library.source.name}',
          sort: 'followedCount',
        ),
        CatalogueRail(
          key: ValueKey('${library.source.id}:latest'),
          title: 'Fresh chapters',
          sort: 'updatedAt',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 13,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Your stories. Your pace.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value, label;
  const _Metric(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  final String title, label;
  const _Heading(this.title, this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 7),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

class _Shelf extends StatelessWidget {
  final List<Manga> stories;
  const _Shelf(this.stories);
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 262,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: stories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
      itemBuilder: (_, i) => SizedBox(width: 140, child: MangaTile(stories[i])),
    ),
  );
}
