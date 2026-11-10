import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/library.dart';
import '../core/models.dart';
import '../main.dart' show guard, message;

class ChapterManager extends StatefulWidget {
  final Manga manga;
  final String? initial;
  const ChapterManager({required this.manga, this.initial, super.key});
  @override
  State<ChapterManager> createState() => _ChapterManagerState();
}

class _ChapterManagerState extends State<ChapterManager> {
  late final Set<String> selected = {
    if (widget.initial != null) widget.initial!,
  };
  String query = '';
  bool unread = false, descending = false, working = false;
  @override
  Widget build(BuildContext context) {
    final library = context.watch<Library>();
    final all = library.chapters(widget.manga.id);
    var visible = all
        .where(
          (c) =>
              (!unread || library.progress(c.id)['complete'] != true) &&
              '${c.number} ${c.title}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    if (descending) visible = visible.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('${selected.length} selected'),
        actions: [
          IconButton(
            tooltip: 'Clear selection',
            onPressed: () => setState(selected.clear),
            icon: const Icon(Icons.deselect),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Chapter number or title',
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Unread'),
                  selected: unread,
                  onSelected: (v) => setState(() => unread = v),
                ),
                ActionChip(
                  label: const Text('Select listed'),
                  onPressed: () =>
                      setState(() => selected.addAll(visible.map((c) => c.id))),
                ),
                ActionChip(
                  label: const Text('Next 10 unread'),
                  onPressed: () => setState(
                    () => selected.addAll(
                      all
                          .where(
                            (c) => library.progress(c.id)['complete'] != true,
                          )
                          .take(10)
                          .map((c) => c.id),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: descending ? 'Oldest first' : 'Newest first',
                  onPressed: () => setState(() => descending = !descending),
                  icon: Icon(descending ? Icons.south : Icons.north),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final c = visible[i];
                final read = library.progress(c.id)['complete'] == true;
                return CheckboxListTile(
                  value: selected.contains(c.id),
                  onChanged: working
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            selected.add(c.id);
                          } else {
                            selected.remove(c.id);
                          }
                        }),
                  title: Text('Chapter ${c.number}'),
                  subtitle: Text(
                    c.title.isEmpty ? '${c.pages} pages' : c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: Icon(
                    read ? Icons.check_circle_outline : Icons.article_outlined,
                    color: read ? Theme.of(context).colorScheme.primary : null,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: selected.isEmpty || working
                        ? null
                        : () => run(() async {
                            await library.enqueueBatch(
                              widget.manga,
                              all.where((c) => selected.contains(c.id)),
                            );
                            if (context.mounted) {
                              message(
                                context,
                                'Selected chapters added to downloads',
                              );
                            }
                          }),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download'),
                  ),
                  OutlinedButton(
                    onPressed: selected.isEmpty || working
                        ? null
                        : () => mark(true),
                    child: const Text('Mark read'),
                  ),
                  TextButton(
                    onPressed: selected.isEmpty || working
                        ? null
                        : () => mark(false),
                    child: const Text('Mark unread'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => working = true);
    await guard(context, action);
    if (mounted) setState(() => working = false);
  }

  Future<void> mark(bool read) => run(() async {
    final library = context.read<Library>();
    for (final c
        in library
            .chapters(widget.manga.id)
            .where((c) => selected.contains(c.id))) {
      library.section('progress')[c.id] = {
        'page': read ? (c.pages - 1).clamp(0, 100000) : 0,
        'total': c.pages,
        'complete': read,
        'time': DateTime.now().toIso8601String(),
      };
    }
    await library.persist();
    if (mounted) {
      message(
        context,
        read
            ? 'Selected chapters marked as read'
            : 'Selected chapters marked as unread',
      );
    }
  });
}
