import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/library.dart';
import '../core/models.dart';
import '../main.dart' show guard;

class TitleOrganization extends StatefulWidget {
  final Manga manga;
  const TitleOrganization({required this.manga, super.key});
  @override
  State<TitleOrganization> createState() => _TitleOrganizationState();
}

class _TitleOrganizationState extends State<TitleOrganization> {
  late final TextEditingController notes, tags;
  late final Set<String> collections;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final entry = context.read<Library>().section('library')[widget.manga.id];
    notes = TextEditingController(text: entry['notes'] ?? '');
    tags = TextEditingController(
      text: (entry['tags'] as List? ?? []).join(', '),
    );
    collections = {
      entry['category'] as String,
      ...List<String>.from(entry['collections'] ?? []),
    };
  }

  @override
  void dispose() {
    notes.dispose();
    tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.read<Library>();
    return Scaffold(
      appBar: AppBar(title: const Text('Make it yours')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.manga.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Text('Collections', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in library.categories)
                FilterChip(
                  label: Text(c),
                  selected: collections.contains(c),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      collections.add(c);
                    } else {
                      collections.remove(c);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 28),
          TextField(
            controller: tags,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Your tags',
              hintText: 'Comfort read, great art, weekend',
              helperText:
                  'Separate tags with commas. Search them in your library.',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: notes,
            minLines: 5,
            maxLines: 12,
            maxLength: 10000,
            decoration: const InputDecoration(
              labelText: 'Private reading notes',
              alignLabelWithHint: true,
              hintText: 'A thought to return to…',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: saving
                ? null
                : () => guard(context, () async {
                    setState(() => saving = true);
                    try {
                      final entry = library.section('library')[widget.manga.id];
                      if (entry == null) return;
                      final selected = collections.isEmpty
                          ? [library.categories.first]
                          : collections.toList();
                      entry['category'] = selected.first;
                      entry['collections'] = selected;
                      entry['notes'] = notes.text.trim();
                      entry['tags'] = tags.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .map((s) => s.length > 40 ? s.substring(0, 40) : s)
                          .toSet()
                          .take(30)
                          .toList();
                      await library.persist();
                      if (context.mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  }),
            icon: const Icon(Icons.check),
            label: const Text('Save to my library'),
          ),
        ],
      ),
    );
  }
}
