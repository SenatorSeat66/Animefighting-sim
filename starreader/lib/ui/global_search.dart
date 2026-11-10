import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/extensions.dart';
import '../core/library.dart';
import '../core/models.dart';
import '../main.dart' show MangaTile, Sources;
import 'design.dart';

class GlobalSearch extends StatefulWidget {
  final String query;
  const GlobalSearch({this.query = '', super.key});
  @override
  State<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<GlobalSearch> {
  late final TextEditingController input = TextEditingController(
    text: widget.query,
  );
  final Map<String, List<Manga>> results = {};
  final Map<String, String> errors = {};
  final Set<String> loading = {};
  List<MangaSource> providers = [];
  int generation = 0, completed = 0;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) scheduleMicrotask(search);
  }

  @override
  void dispose() {
    generation++;
    input.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (input.text.trim().isEmpty) return;
    final token = ++generation, query = input.text.trim();
    final library = context.read<Library>(),
        manager = context.read<Library>().extensions;
    final language = library.settings['language'] ?? 'en';
    providers = [
      library.sourceFor('mangadex'),
      ...manager.sources
          .where(
            (s) =>
                (s.language == language || s.language == 'all') &&
                !manager.excludedFromSearch.contains(s.id),
          )
          .map(ExtensionMangaSource.new),
    ];
    setState(() {
      results.clear();
      errors.clear();
      loading.clear();
      completed = 0;
      busy = true;
    });
    var cursor = 0;
    Future<void> worker() async {
      while (mounted && generation == token && cursor < providers.length) {
        final source = providers[cursor++];
        setState(() => loading.add(source.id));
        try {
          final found = await source
              .search(query: query)
              .timeout(const Duration(seconds: 60));
          if (mounted && generation == token) {
            setState(() => results[source.id] = found);
          }
        } catch (e) {
          if (mounted && generation == token) {
            setState(
              () => errors[source.id] = e is TimeoutException
                  ? 'This source took too long. Try it on its own.'
                  : e.toString(),
            );
          }
        } finally {
          if (mounted && generation == token) {
            setState(() {
              loading.remove(source.id);
              completed++;
            });
          }
        }
      }
    }

    await Future.wait([worker(), worker()]);
    if (mounted && generation == token) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.read<Library>().settings['language'] ?? 'en';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Across your sources'),
        actions: [
          IconButton(
            tooltip: 'Manage sources',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const Sources()),
            ),
            icon: const Icon(Icons.hub_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('ONE SEARCH, MORE POSSIBILITIES'),
                const SizedBox(height: 12),
                TextField(
                  controller: input,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => search(),
                  decoration: InputDecoration(
                    hintText: 'What would you like to read?',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Search all sources',
                      onPressed: search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Searches your $language and multilingual sources. Exclude individual sources from their menu in My sources.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (providers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$completed of ${providers.length} sources checked',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (busy)
                        TextButton(
                          onPressed: () => setState(() {
                            generation++;
                            busy = false;
                            loading.clear();
                          }),
                          child: const Text('Stop'),
                        ),
                    ],
                  ),
                  if (busy)
                    LinearProgressIndicator(
                      value: completed / providers.length,
                    ),
                ],
              ],
            ),
          ),
          if (providers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.travel_explore, size: 54),
                  SizedBox(height: 18),
                  Text(
                    'A title, an author, a new obsession.\nStart with a search above.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final source in providers)
            if (results.containsKey(source.id) ||
                errors.containsKey(source.id) ||
                loading.contains(source.id)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        source is ExtensionMangaSource
                            ? '${source.name} · ${source.info.language.toUpperCase()}'
                            : source.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (loading.contains(source.id))
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: () async {
                          await context.read<Library>().extensions.select(
                            source.id,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Browse'),
                      ),
                  ],
                ),
              ),
              if (errors[source.id] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    errors[source.id]!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else if (results[source.id]?.isEmpty == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'No matches on this source.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else if (results[source.id]?.isNotEmpty == true)
                SizedBox(
                  height: 262,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: results[source.id]!.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (_, i) => SizedBox(
                      width: 140,
                      child: MangaTile(results[source.id]![i]),
                    ),
                  ),
                ),
            ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
