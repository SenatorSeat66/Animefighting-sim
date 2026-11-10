import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/library.dart';
import '../core/library_updates.dart';
import '../core/models.dart';
import '../main.dart' show Cover, guard, openManga;
import '../reader.dart';
import 'design.dart';

class LibraryUpdatesScreen extends StatelessWidget {
  const LibraryUpdatesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>();
    final state = l.section('updateState');
    final updates = l.section('updates').values.toList()
      ..sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));
    final failures = Map<String, dynamic>.from(state['failures'] ?? {});
    final time = DateTime.tryParse(state['time'] ?? '')?.toLocal();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fresh chapters'),
        actions: [
          IconButton(
            tooltip: 'Update preferences',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const UpdatePreferences(),
            ),
            icon: const Icon(Icons.tune),
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
                const Eyebrow('YOUR STORIES KEEP GOING'),
                const SizedBox(height: 12),
                Text(
                  'Something to look\nforward to.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  time == null
                      ? 'Check your library for new chapters. Your sources stay in your control.'
                      : 'Last checked ${time.month}/${time.day} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · ${state['checked']}/${state['total']} titles',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: l.updatingLibrary
                            ? null
                            : () => guard(context, () async {
                                await l.updateLibrary();
                              }),
                        icon: const Icon(Icons.sync),
                        label: Text(
                          l.updatingLibrary
                              ? '${l.updateDone} of ${l.updateTotal} titles'
                              : 'Check for new chapters',
                        ),
                      ),
                    ),
                    if (l.updatingLibrary)
                      IconButton(
                        tooltip: 'Stop after this title',
                        onPressed: l.stopLibraryUpdate,
                        icon: const Icon(Icons.stop_circle_outlined),
                      ),
                  ],
                ),
                if (l.updatingLibrary) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: l.updateTotal == 0
                        ? null
                        : l.updateDone / l.updateTotal,
                  ),
                ],
              ],
            ),
          ),
          if (failures.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: ExpansionTile(
                leading: Icon(
                  Icons.cloud_off_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '${failures.length} ${failures.length == 1 ? 'title needs' : 'titles need'} attention',
                ),
                subtitle: const Text('Successful titles were still updated'),
                children: [
                  for (final e in failures.entries)
                    ListTile(
                      title: Text(
                        l.manga
                                .where((m) => m.id == e.key)
                                .firstOrNull
                                ?.title ??
                            'Title unavailable',
                      ),
                      subtitle: Text(e.value.toString(), maxLines: 3),
                      onTap: () {
                        final m = l.manga
                            .where((m) => m.id == e.key)
                            .firstOrNull;
                        if (m != null) openManga(context, m);
                      },
                    ),
                ],
              ),
            ),
          if (updates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const OrbitArt(size: 130),
                  const SizedBox(height: 16),
                  Text(
                    'A little anticipation.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New chapters from your saved titles will gather here after a library check.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final update in updates.take(300))
            Builder(
              builder: (context) {
                final c = Chapter.fromJson(
                  Map<String, dynamic>.from(update['chapter']),
                );
                final m = l.manga.where((m) => m.id == c.mangaId).firstOrNull;
                if (m == null) return const SizedBox.shrink();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  leading: Cover(m, width: 44, height: 66),
                  title: Text(
                    m.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Chapter ${c.number} · ${c.title}',
                    maxLines: 2,
                  ),
                  trailing: Icon(
                    l.progress(c.id)['complete'] == true
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                  ),
                  onTap: () => openReader(context, m, c),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class UpdatePreferences extends StatelessWidget {
  const UpdatePreferences({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.watch<Library>(), s = context.watch<Library>().settings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A rhythm for your library',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              LibraryUpdates.available
                  ? 'Android checks when your network and battery allow. Timing can shift with battery saver. Large libraries continue in the next batch.'
                  : 'Scheduled checks run in the Android app. You can check manually here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: s['updateHours'] as int? ?? 0,
              decoration: const InputDecoration(
                labelText: 'Check for chapters',
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Only when I ask')),
                DropdownMenuItem(value: 6, child: Text('Every 6 hours')),
                DropdownMenuItem(value: 12, child: Text('Every 12 hours')),
                DropdownMenuItem(value: 24, child: Text('Every day')),
                DropdownMenuItem(value: 72, child: Text('Every 3 days')),
              ],
              onChanged: LibraryUpdates.available
                  ? (v) => guard(context, () => l.setting('updateHours', v))
                  : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Unmetered networks only'),
              subtitle: const Text('Usually Wi-Fi'),
              value: s['updateWifi'] != false,
              onChanged: LibraryUpdates.available
                  ? (v) => guard(context, () => l.setting('updateWifi', v))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('New chapter notifications'),
              value: s['updateNotify'] == true,
              onChanged: LibraryUpdates.available
                  ? (v) => guard(context, () => l.setting('updateNotify', v))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
