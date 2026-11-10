import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/library.dart';
import 'core/extensions.dart';
import 'core/models.dart';
import 'main.dart' show MangaTile, openManga, Empty, guard, message;
import 'reader.dart';

class CatalogueRail extends StatefulWidget {
  final String title, sort;
  const CatalogueRail({required this.title, required this.sort, super.key});
  @override
  State<CatalogueRail> createState() => _CatalogueRailState();
}

class _CatalogueRailState extends State<CatalogueRail> {
  late Future<List<Manga>> request;
  @override
  void initState() {
    super.initState();
    request = fetch();
  }

  Future<List<Manga>> fetch() {
    final selected = context.read<Library>().source;
    // Home rails must not reset Discover's pagination or inherit its filters.
    final source = selected is ExtensionMangaSource
        ? ExtensionMangaSource(selected.info)
        : selected;
    return source.search(sort: widget.sort);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Text(
          widget.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      FutureBuilder<List<Manga>>(
        future: request,
        builder: (c, s) {
          if (s.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Source unavailable. Your offline library is still here.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      request = fetch();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!s.hasData) {
            return const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: s.data!.take(12).length,
              separatorBuilder: (_, i) => const SizedBox(width: 16),
              itemBuilder: (_, i) =>
                  SizedBox(width: 132, child: MangaTile(s.data![i])),
            ),
          );
        },
      ),
    ],
  );
}

class Bookmarks extends StatelessWidget {
  const Bookmarks({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final entries = l.section('bookmarks').keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved pages')),
      body: entries.isEmpty
          ? const Center(
              child: Empty(
                'Keep a favorite moment',
                'Bookmark pages from the reader toolbar.',
              ),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final key = entries[index];
                final split = key.lastIndexOf(':');
                final id = key.substring(0, split);
                final page = int.tryParse(key.substring(split + 1)) ?? 0;
                Chapter? chapter;
                Manga? manga;
                for (final m in l.manga) {
                  final found = l
                      .chapters(m.id)
                      .where((c) => c.id == id)
                      .firstOrNull;
                  if (found != null) {
                    chapter = found;
                    manga = m;
                    break;
                  }
                }
                if (chapter == null || manga == null) {
                  return const SizedBox.shrink();
                }
                final ch = chapter, ma = manga;
                return ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(ma.title),
                  subtitle: Text('Chapter ${ch.number} · Page ${page + 1}'),
                  onTap: () {
                    l.section('progress')[ch.id] = {
                      ...l.progress(ch.id),
                      'page': page,
                      'offset': 0.0,
                    };
                    openReader(context, ma, ch);
                  },
                  trailing: IconButton(
                    tooltip: 'Remove bookmark',
                    onPressed: () =>
                        guard(context, () => l.bookmark(ch.id, page)),
                    icon: const Icon(Icons.close),
                  ),
                );
              },
            ),
    );
  }
}

class ReadingStats extends StatelessWidget {
  const ReadingStats({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final read = l
        .section('progress')
        .values
        .where((v) => v['complete'] == true)
        .length;
    final days = l.section('sessions').keys.toSet();
    int streak = 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    String date(DateTime d) => d.toIso8601String().substring(0, 10);
    if (!days.contains(date(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    while (days.contains(date(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The small habit. The big adventure.',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text(
              '$streak day streak   ·   $read ${read == 1 ? 'chapter' : 'chapters'} finished',
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final d = DateTime(now.year, now.month, now.day - 6 + i);
                final active = days.contains(date(d));
                return Column(
                  children: [
                    Icon(
                      active ? Icons.circle : Icons.circle_outlined,
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 25,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1],
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageLibrary extends StatefulWidget {
  const ManageLibrary({super.key});
  @override
  State<ManageLibrary> createState() => _ManageLibraryState();
}

class _ManageLibraryState extends State<ManageLibrary> {
  final selected = <String>{};
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    bool matches(Manga m) {
      final chapters = l.chapters(m.id);
      return switch (filter) {
        'Unread' => chapters.any((c) => l.progress(c.id)['complete'] != true),
        'Downloaded' => chapters.any(
          (c) => l.section('downloads')[c.id]?['status'] == 'complete',
        ),
        'Completed' =>
          chapters.isNotEmpty &&
              chapters.every((c) => l.progress(c.id)['complete'] == true),
        _ => true,
      };
    }

    final items = l.saved.where(matches).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('${selected.length} selected'),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => selected.addAll(items.map((m) => m.id))),
            child: const Text('Select all'),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 8,
              children: [
                for (final f in ['All', 'Unread', 'Downloaded', 'Completed'])
                  ChoiceChip(
                    label: Text(f),
                    selected: filter == f,
                    onSelected: (_) => setState(() => filter = f),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: items
                  .map(
                    (m) => CheckboxListTile(
                      value: selected.contains(m.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          selected.add(m.id);
                        } else {
                          selected.remove(m.id);
                        }
                      }),
                      title: Text(m.title),
                      subtitle: Text(l.section('library')[m.id]['category']),
                      secondary: IconButton(
                        tooltip: 'Open title',
                        onPressed: () => openManga(context, m),
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (selected.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Move to collection',
                      onSelected: (v) {
                        for (final id in selected) {
                          l.section('library')[id]['category'] = v;
                        }
                        l.persist();
                      },
                      itemBuilder: (_) => l.categories
                          .map((c) => PopupMenuItem(value: c, child: Text(c)))
                          .toList(),
                      child: const Chip(label: Text('Move to collection')),
                    ),
                    ActionChip(
                      label: const Text('Favorite'),
                      onPressed: () {
                        for (final id in selected) {
                          l.section('library')[id]['favorite'] = true;
                        }
                        l.persist();
                      },
                    ),
                    ActionChip(
                      label: const Text('Update'),
                      onPressed: () => guard(context, () async {
                        for (final m in l.saved.where(
                          (m) => selected.contains(m.id),
                        )) {
                          await l.refresh(m);
                        }
                        if (context.mounted) {
                          message(context, 'Selected titles updated');
                        }
                      }),
                    ),
                    ActionChip(
                      label: const Text('Remove'),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Remove selected titles?'),
                            content: const Text(
                              'Reading history and downloaded chapters are retained.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          for (final id in selected) {
                            l.section('library').remove(id);
                          }
                          await l.persist();
                          if (mounted) {
                            setState(selected.clear);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
