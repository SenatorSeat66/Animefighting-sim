import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/extension_repository.dart';
import '../core/extensions.dart';
import '../core/library.dart';
import '../main.dart' show guard, message;
import 'design.dart';

class SourceHub extends StatefulWidget {
  const SourceHub({super.key});
  @override
  State<SourceHub> createState() => _SourceHubState();
}

class _SourceHubState extends State<SourceHub> {
  String query = '', language = 'en';
  bool includeAdult = false, adding = false;
  late ExtensionManager manager;
  @override
  void initState() {
    super.initState();
    manager = context.read<Library>().extensions;
    if (ExtensionBridge.available) manager.reloadInstalled();
  }

  Future<void> add([String? initial]) async {
    final input = TextEditingController(text: initial ?? '');
    final url =
        initial ??
        await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Add a repository'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paste a Mihon extension repository index URL.'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: input,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Repository URL',
                      hintText: 'https://…/index.pb',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, input.text),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
    input.dispose();
    if (url == null || url.trim().isEmpty || !mounted) return;
    setState(() => adding = true);
    try {
      final repo = await ExtensionRepository.fetch(url);
      if (!mounted) return;
      final trust = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Add ${repo.name}?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${repo.packages.length} ${repo.packages.length == 1 ? 'extension' : 'extensions'} · ${Uri.parse(repo.url).host}',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Extensions run code inside StarReader and can access app data. Only install from publishers you trust. StarReader checks every APK against this publisher’s signing certificate.',
                ),
                const SizedBox(height: 18),
                const Eyebrow('PUBLISHER CERTIFICATE · SHA-256'),
                const SizedBox(height: 8),
                SelectableText(
                  repo.certificate,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Trust & add'),
            ),
          ],
        ),
      );
      if (trust == true) {
        await manager.add(repo);
        if (mounted) {
          message(
            context,
            '${repo.name} added. Open Extensions to install a source.',
          );
        }
      }
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> select(String id) async {
    await manager.select(id);
    if (mounted) {
      message(context, 'Source selected. Discover will use it.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: manager,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Your story connections'),
            actions: [
              IconButton(
                tooltip: 'Refresh extensions',
                onPressed: manager.refreshing || manager.loadingInstalled
                    ? null
                    : () => guard(context, () async {
                        await Future.wait([
                          manager.refresh(),
                          if (ExtensionBridge.available)
                            manager.reloadInstalled(),
                        ]);
                      }),
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Add repository',
                onPressed: adding ? null : () => add(),
                icon: const Icon(Icons.add_link_rounded),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'My sources'),
                Tab(text: 'Extensions'),
                Tab(text: 'Repositories'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (adding || manager.refreshing || manager.loadingInstalled)
                const LinearProgressIndicator(minHeight: 2),
              if (manager.errors['installed'] != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    manager.errors['installed']!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    mySources(context),
                    catalogue(context),
                    repositories(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget mySources(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final list = manager.sources;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('A WORLD TO EXPLORE'),
                    const SizedBox(height: 10),
                    const Text(
                      'Stories start here.',
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 30,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose where you read. Your library stays together.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 70, height: 80, child: OrbitArt()),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Eyebrow('BUILT IN'),
        const SizedBox(height: 12),
        sourceTile(
          context,
          id: 'mangadex',
          title: 'MangaDex',
          subtitle: 'Multilingual · direct API',
          icon: Icons.auto_stories_outlined,
          actions: [
            const PopupMenuItem(
              value: 'language',
              child: Text('Chapter language'),
            ),
            PopupMenuItem(
              value: 'health',
              child: const Text('Check connection'),
            ),
          ],
          onMenu: (v) => guard(context, () async {
            if (v == 'language') {
              await chooseLanguage();
              return;
            }
            await context.read<Library>().sourceFor('mangadex').health();
            if (context.mounted) message(context, 'MangaDex is responding.');
          }),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: Eyebrow('EXTENSION SOURCES')),
            Text(
              manager.loadingInstalled
                  ? 'Loading…'
                  : '${list.length} available',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (manager.loadingInstalled && list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Getting your installed sources ready. Local reading is available now.',
            ),
          ),
        if (list.isEmpty && !manager.loadingInstalled)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.extension_outlined, size: 28),
                  const SizedBox(height: 16),
                  const Text(
                    'Bring your sources with you',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add a repository, install an extension, then choose a source here. Compatible Mihon APIs 1.4 and 1.6 are supported on Android.',
                  ),
                  const SizedBox(height: 16),
                  if (manager.repositories.isEmpty)
                    OutlinedButton.icon(
                      onPressed: adding
                          ? null
                          : () => add(ExtensionRepository.keiyoushi),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Add Keiyoushi'),
                    )
                  else
                    Builder(
                      builder: (inner) => OutlinedButton.icon(
                        onPressed: () =>
                            DefaultTabController.of(inner).animateTo(1),
                        icon: const Icon(Icons.extension_outlined),
                        label: const Text('Browse extensions'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        for (final s in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: sourceTile(
              context,
              id: 'ext:${s.id}',
              title: s.name,
              subtitle:
                  '${s.language.toUpperCase()} · ${Uri.tryParse(s.url)?.host ?? ''}',
              icon: Icons.public_rounded,
              actions: [
                PopupMenuItem(
                  value: 'global',
                  child: Text(
                    manager.excludedFromSearch.contains(s.id)
                        ? 'Include in global search'
                        : 'Exclude from global search',
                  ),
                ),
                const PopupMenuItem(
                  value: 'health',
                  child: Text('Check connection'),
                ),
                if (s.settings)
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Source settings'),
                  ),
                if (s.url.isNotEmpty)
                  const PopupMenuItem(
                    value: 'browser',
                    child: Text('Open website / sign in'),
                  ),
              ],
              onMenu: (v) => guard(context, () async {
                if (v == 'global') {
                  await manager.toggleGlobalSearch(s.id);
                } else if (v == 'health') {
                  await manager.source(s.id).health();
                  if (context.mounted) {
                    message(context, '${s.name} is responding.');
                  }
                } else {
                  await ExtensionBridge.call(v, {'source': s.id});
                }
              }),
            ),
          ),
        if (!ExtensionBridge.available)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'Extension installation and reading are available in the Android app. You can explore repositories in this preview.',
            ),
          ),
      ],
    );
  }

  Future<void> chooseLanguage() async {
    final library = context.read<Library>();
    final languages = {
      'en': 'English',
      'ja': 'Japanese',
      'es': 'Spanish',
      'es-la': 'Spanish (Latin America)',
      'pt-br': 'Portuguese (Brazil)',
      'pt': 'Portuguese',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'ko': 'Korean',
      'zh': 'Chinese',
      'zh-hk': 'Chinese (Traditional)',
      'ru': 'Russian',
      'id': 'Indonesian',
      'vi': 'Vietnamese',
      'th': 'Thai',
      'ar': 'Arabic',
      'tr': 'Turkish',
      'pl': 'Polish',
      'uk': 'Ukrainian',
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'MangaDex chapter language',
                style: Theme.of(c).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final e in languages.entries)
                    ListTile(
                      title: Text(e.value),
                      trailing: (library.settings['language'] ?? 'en') == e.key
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => Navigator.pop(c, e.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await library.setting('language', selected);
      if (mounted) {
        message(
          context,
          'Chapter language updated. Refresh a title to load its chapters.',
        );
      }
    }
  }

  Widget sourceTile(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<PopupMenuEntry<String>> actions,
    required void Function(String) onMenu,
  }) {
    final selected = manager.selected == id;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => select(id),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
            PopupMenuButton<String>(
              tooltip: '$title actions',
              itemBuilder: (_) => actions,
              onSelected: onMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget catalogue(BuildContext context) {
    final packages = manager.packages
        .where(
          (p) =>
              (includeAdult || p.content < 3) &&
              (language == 'all' ||
                  p.sources.any(
                    (s) => s.language == language || s.language == 'all',
                  )) &&
              (p.name.toLowerCase().contains(query.toLowerCase()) ||
                  p.sources.any(
                    (s) => s.name.toLowerCase().contains(query.toLowerCase()),
                  )),
        )
        .toList();
    final languages =
        manager.packages
            .expand((p) => p.sources.map((s) => s.language))
            .toSet()
            .toList()
          ..sort();
    if (!languages.contains(language) && language != 'all') {
      languages.add(language);
    }
    final installed = {for (final i in manager.installed) i.package: i};
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Find an extension or source',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: language,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                          isDense: true,
                        ),
                        items: ['all', ...languages.where((l) => l != 'all')]
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(
                                  l == 'all'
                                      ? 'All languages'
                                      : l.toUpperCase(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => language = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Show 18+'),
                      selected: includeAdult,
                      onSelected: (v) => setState(() => includeAdult = v),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${packages.length} ${packages.length == 1 ? 'extension' : 'extensions'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (manager.repositories.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.travel_explore, size: 48),
                  const SizedBox(height: 20),
                  const Text('Your next source is a connection away.'),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: adding
                        ? null
                        : () => add(ExtensionRepository.keiyoushi),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Keiyoushi repository'),
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.builder(
            itemCount: packages.length,
            itemBuilder: (c, i) {
              final p = packages[i], existing = installed[p.package];
              final update = existing != null && existing.code < p.code;
              final busy = manager.busyPackages.contains(p.package);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(c)
                                    .colorScheme
                                    .surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                existing != null
                                    ? Icons.extension_rounded
                                    : Icons.extension_outlined,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${p.languages} · v${p.version}',
                                    style: Theme.of(c).textTheme.bodySmall,
                                  ),
                                  if (p.content >= 2)
                                    Text(
                                      p.content == 3
                                          ? 'Adult content'
                                          : 'Mixed content',
                                      style: Theme.of(c).textTheme.bodySmall,
                                    ),
                                  if (!p.supported)
                                    Text(
                                      'API ${p.api} is not supported',
                                      style: TextStyle(
                                        color: Theme.of(c).colorScheme.error,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (busy)
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else if (existing != null && !update)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.check_circle_outline),
                              )
                            else
                              IconButton.filledTonal(
                                tooltip: update
                                    ? 'Update ${p.name}'
                                    : 'Install ${p.name}',
                                onPressed:
                                    !ExtensionBridge.available ||
                                        !p.supported ||
                                        manager.loadingInstalled
                                    ? null
                                    : () => guard(c, () async {
                                        await manager.install(p);
                                        if (c.mounted) {
                                          message(
                                            c,
                                            '${p.name} ${update ? 'updated' : 'installed'}. Choose it in My sources.',
                                          );
                                        }
                                      }),
                                icon: Icon(
                                  update
                                      ? Icons.upgrade_rounded
                                      : Icons.download_rounded,
                                ),
                              ),
                          ],
                        ),
                        if (existing?.error.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              existing!.error,
                              style: TextStyle(
                                color: Theme.of(c).colorScheme.error,
                              ),
                            ),
                          ),
                        if (existing != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => removeExtension(existing),
                              child: const Text('Remove'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Future<void> removeExtension(InstalledExtension extension) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${extension.name}?'),
        content: const Text(
          'Your library and downloaded chapters will stay. Online chapters need this extension to be reinstalled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await guard(context, () => manager.uninstall(extension.package));
    }
  }

  Widget repositories(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Make it your own.',
        style: TextStyle(fontFamily: 'Newsreader', fontSize: 34),
      ),
      const SizedBox(height: 12),
      const Text(
        'Repositories publish extensions. You choose which publishers to trust and which sources to install.',
      ),
      const SizedBox(height: 24),
      for (final repo in manager.repositories)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          repo.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (_) => guard(
                          context,
                          () => manager.removeRepository(repo.url),
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove repository'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${repo.packages.length} ${repo.packages.length == 1 ? 'extension' : 'extensions'} · trusted publisher',
                  ),
                  const SizedBox(height: 14),
                  SelectableText(
                    repo.url,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  const Eyebrow('SIGNING CERTIFICATE'),
                  const SizedBox(height: 8),
                  SelectableText(
                    repo.certificate,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                  if (manager.errors[repo.url] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        manager.errors[repo.url]!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      FilledButton.icon(
        onPressed: adding ? null : () => add(),
        icon: const Icon(Icons.add_link),
        label: const Text('Add repository'),
      ),
      if (manager.repositories.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton(
            onPressed: adding ? null : () => add(ExtensionRepository.keiyoushi),
            child: const Text('Use Keiyoushi'),
          ),
        ),
      const SizedBox(height: 24),
      Text(
        'Extensions are installed privately inside StarReader. APK certificates are checked on installation and each launch. Source availability depends on the website and extension; compatibility is not universal.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (manager.installed.any((i) => i.error.isNotEmpty)) ...[
        const SizedBox(height: 24),
        const Eyebrow('EXTENSIONS THAT NEED ATTENTION'),
        for (final i in manager.installed.where((i) => i.error.isNotEmpty))
          ListTile(
            title: Text(i.name),
            subtitle: Text(i.error),
            trailing: IconButton(
              tooltip: 'Remove ${i.name}',
              onPressed: () => removeExtension(i),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    ],
  );
}
