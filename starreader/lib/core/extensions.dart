import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'extension_repository.dart';
import 'models.dart';
import 'storage.dart';

class ExtensionBridge {
  static const channel = MethodChannel('app.starreader/extensions');
  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<T?> call<T>(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!available) {
      throw UnsupportedError(
        'Mihon extensions run in the Android app. Repository browsing is available here.',
      );
    }
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Extension operation failed');
    }
  }

  static String imageToken(Map<String, dynamic> page) =>
      'extimg:${base64Url.encode(utf8.encode(jsonEncode(page)))}';
  static Future<Uint8List> image(String token) async {
    final page = jsonDecode(
      utf8.decode(base64Url.decode(token.substring(7))),
    ) as Map<String, dynamic>;
    final bytes = await call<Uint8List>('image', page);
    if (bytes == null) throw const FormatException('Source returned no image');
    return bytes;
  }
}

class InstalledExtension {
  final String package, name, version, certificate, error;
  final int code;
  final List<ExtensionSourceInfo> sources;
  const InstalledExtension({
    required this.package,
    required this.name,
    required this.version,
    required this.certificate,
    required this.code,
    required this.sources,
    this.error = '',
  });
  factory InstalledExtension.fromJson(Map<String, dynamic> j) =>
      InstalledExtension(
        package: j['package'],
        name: j['name'],
        version: j['version'] ?? '',
        certificate: j['certificate'] ?? '',
        code: j['code'] ?? 0,
        error: j['error'] ?? '',
        sources: (j['sources'] as List? ?? [])
            .map(
              (s) => ExtensionSourceInfo.fromJson(Map<String, dynamic>.from(s)),
            )
            .toList(),
      );
}

class ExtensionManager extends ChangeNotifier {
  final Storage storage;
  ExtensionManager(this.storage);
  List<ExtensionRepository> repositories = [];
  List<InstalledExtension> installed = [];
  final Map<String, String> errors = {};
  final Set<String> busyPackages = {};
  bool refreshing = false, loadingInstalled = false;
  String selected = 'mangadex';
  final Set<String> excludedFromSearch = {};
  Future<void> toggleGlobalSearch(String id) async {
    if (!excludedFromSearch.remove(id)) excludedFromSearch.add(id);
    await save();
    notifyListeners();
  }

  List<ExtensionSourceInfo> get sources =>
      installed.expand((e) => e.sources).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  List<ExtensionPackage> get packages {
    final result = <String, ExtensionPackage>{};
    for (final repo in repositories) {
      for (final package in repo.packages) {
        final old = result[package.package];
        if (old == null ||
            (old.certificate == package.certificate &&
                old.code < package.code)) {
          result[package.package] = package;
        }
      }
    }
    return result.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> init() async {
    final raw = await storage.readCache('extensions');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        repositories = (decoded['repositories'] as List)
            .map(
              (j) => ExtensionRepository.fromJson(Map<String, dynamic>.from(j)),
            )
            .toList();
        selected = decoded['selected'] as String? ?? 'mangadex';
        excludedFromSearch.addAll(
          List<String>.from(decoded['excludedFromSearch'] ?? []),
        );
      } catch (_) {
        errors['cache'] =
            'The saved catalogue could not be read. Add the repository again.';
      }
    }
    // Offline reading must not wait for third-party source constructors.
    if (ExtensionBridge.available) unawaited(reloadInstalled());
  }

  Future<void> save() => storage.writeCache(
    'extensions',
    jsonEncode({
      'selected': selected,
      'excludedFromSearch': excludedFromSearch.toList(),
      'repositories': repositories.map((r) => r.toJson()).toList(),
    }),
  );
  Future<void> select(String id) async {
    selected = id;
    await save();
    notifyListeners();
  }

  Future<void> reloadInstalled() async {
    if (loadingInstalled) return;
    loadingInstalled = true;
    notifyListeners();
    try {
      final raw =
          await ExtensionBridge.call<List<dynamic>>('list')
              .timeout(const Duration(seconds: 45)) ??
          [];
      installed = raw
          .map((j) => InstalledExtension.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      errors.remove('installed');
    } catch (e) {
      errors['installed'] = e is TimeoutException
          ? 'Source loading took too long. Your offline library is available; refresh to try again.'
          : e.toString();
    } finally {
      loadingInstalled = false;
      notifyListeners();
    }
  }

  /// The UI obtains explicit trust of the publisher before calling add.
  Future<void> add(ExtensionRepository repository) async {
    final existing = repositories
        .where((r) => r.url == repository.url)
        .firstOrNull;
    if (existing != null && existing.certificate != repository.certificate) {
      throw const FormatException(
        'Repository signing key changed. Remove it and review the new publisher before adding it again.',
      );
    }
    repositories = [
      ...repositories.where((r) => r.url != repository.url),
      repository,
    ];
    await save();
    notifyListeners();
  }

  Future<void> removeRepository(String url) async {
    repositories.removeWhere((r) => r.url == url);
    errors.remove(url);
    await save();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      for (final repo in [...repositories]) {
        try {
          final update = await ExtensionRepository.fetch(repo.url);
          await add(update);
          errors.remove(repo.url);
        } catch (e) {
          errors[repo.url] = e.toString();
        }
      }
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> install(ExtensionPackage package) async {
    if (loadingInstalled) {
      throw StateError('Wait for installed sources to finish loading.');
    }
    if (!busyPackages.add(package.package)) return;
    notifyListeners();
    try {
      if (!package.supported) {
        throw UnsupportedError(
          'Extension API ${package.api} is not supported.',
        );
      }
      final repo = repositories
          .where(
            (r) =>
                r.url == package.repository &&
                r.certificate == package.certificate,
          )
          .firstOrNull;
      if (repo == null) {
        throw StateError(
          'Trust this repository before installing its extensions.',
        );
      }
      await ExtensionBridge.call('install', {
        'package': package.package,
        'url': package.apk,
        'certificate': package.certificate,
        'code': package.code,
      });
      await reloadInstalled();
    } finally {
      busyPackages.remove(package.package);
      notifyListeners();
    }
  }

  Future<void> uninstall(String package) async {
    await ExtensionBridge.call('remove', {'package': package});
    await reloadInstalled();
    if (selected.startsWith('ext:') &&
        !sources.any((s) => 'ext:${s.id}' == selected)) {
      await select('mangadex');
    }
  }

  ExtensionMangaSource source(String id) {
    final value = id.replaceFirst('ext:', '');
    final info =
        sources.where((s) => s.id == value).firstOrNull ??
        ExtensionSourceInfo(
          id: value,
          name: 'Unavailable source',
          language: '',
          url: '',
        );
    return ExtensionMangaSource(info);
  }
}

class ExtensionMangaSource implements MangaSource {
  final ExtensionSourceInfo info;
  ExtensionMangaSource(this.info);
  @override
  String get id => 'ext:${info.id}';
  @override
  String get name => info.name;
  final Map<String, Map<int, int>> _cursors = {};
  bool hasMore = true;
  List<Map<String, dynamic>> appliedFilters = [];
  @override
  Future<List<Manga>> search({
    String query = '',
    int offset = 0,
    String sort = 'followedCount',
    String status = '',
  }) async {
    final key = jsonEncode([query, sort, appliedFilters]);
    final cursors = _cursors.putIfAbsent(key, () => {0: 1});
    if (offset == 0) {
      cursors.clear();
      cursors[0] = 1;
    }
    final page = cursors[offset] ?? 1;
    final result = await ExtensionBridge.call<Map<dynamic, dynamic>>('search', {
      'source': info.id,
      'page': page,
      'query': query,
      'latest': sort != 'followedCount',
      'filters': appliedFilters,
    });
    hasMore = result?['more'] == true;
    final items = (result?['items'] as List? ?? [])
        .map((m) => Manga.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    cursors[offset + items.length] = page + 1;
    return items;
  }

  Future<(Manga, List<Chapter>)> update(Manga manga) async {
    final result = await ExtensionBridge.call<Map<dynamic, dynamic>>('update', {
      'source': info.id,
      'manga': manga.toJson(),
    });
    if (result == null) throw const FormatException('Source returned no manga');
    return (
      Manga.fromJson(Map<String, dynamic>.from(result['manga'])),
      (result['chapters'] as List)
          .map((c) => Chapter.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }

  Future<List<String>> pageList(Chapter chapter) async {
    final list =
        await ExtensionBridge.call<List<dynamic>>('pages', {
          'source': info.id,
          'chapter': chapter.toJson(),
        }) ??
        [];
    return list
        .map((p) => ExtensionBridge.imageToken(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> filters() async =>
      (await ExtensionBridge.call<List<dynamic>>('filters', {
                'source': info.id,
              }) ??
              [])
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
  @override
  Future<List<Chapter>> chapters(
    String mangaId, {
    String language = 'en',
  }) async => (await update(Manga(id: mangaId, title: '', source: id))).$2;
  @override
  Future<List<String>> pages(String chapterId) =>
      pageList(Chapter(id: chapterId, mangaId: '', title: ''));
  @override
  Future<void> health() async {
    await search();
  }
}
