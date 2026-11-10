import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'archive_input.dart';
import 'archive_decoder.dart';
import 'extensions.dart';
import 'page_cache.dart';
import 'image_dimensions.dart';
import 'thumbnail_cache.dart';
import 'background_downloads.dart';
import 'library_updates.dart';
import 'source.dart';
import 'storage.dart';
import 'reader_preferences.dart';

class Library extends ChangeNotifier {
  final Storage storage;
  final MangaSource _defaultSource;
  late final ExtensionManager extensions = ExtensionManager(storage)
    ..addListener(() {
      final revision = jsonEncode(
        extensions.installed
            .map(
              (e) => {
                'package': e.package,
                'version': e.version,
                'code': e.code,
                'sources': e.sources.map((s) => s.toJson()).toList(),
              },
            )
            .toList(),
      );
      if (_sourcesRevision != revision) {
        _sourceCache.clear();
        _sourcesRevision = revision;
      }
      notifyListeners();
    });
  final Map<String, ExtensionMangaSource> _sourceCache = {};
  String _sourcesRevision = '';
  MangaSource get source => extensions.selected.startsWith('ext:')
      ? sourceFor(extensions.selected)
      : _defaultSource;
  MangaSource sourceFor(String id) => id.startsWith('ext:')
      ? _sourceCache.putIfAbsent(id, () => extensions.source(id))
      : _defaultSource;
  Library(
    this.storage, {
    MangaSource? source,
    Future<Uint8List> Function(String)? imageFetcher,
  }) : _defaultSource = source ?? MangaDexSource(),
       imageFetcher = imageFetcher ?? fetchImage;
  final Future<Uint8List> Function(String) imageFetcher;
  final pageCache = PageCache();
  final covers = ThumbnailCache();
  Map<String, dynamic> data = {};
  String? downloadError;
  bool running = false;
  Future<void> _writes = Future.value();
  Map<String, dynamic> section(String key) =>
      data.putIfAbsent(key, () => <String, dynamic>{}) as Map<String, dynamic>;
  Map<String, dynamic> get settings => section('settings');
  List<Manga> get manga =>
      section('manga').values
          .map((v) => Manga.fromJson(Map<String, dynamic>.from(v)))
          .toList();
  List<Manga> get saved =>
      manga.where((m) => section('library').containsKey(m.id)).toList();
  List<String> get categories => List<String>.from(
    data['categories'] ?? ['Reading', 'Plan to read', 'Completed'],
  );
  List<Chapter> chapters(String id) => (section('chapters')[id] as List? ?? [])
      .map((j) => Chapter.fromJson(Map<String, dynamic>.from(j)))
      .toList();
  Map<String, dynamic> progress(String chapter) =>
      Map<String, dynamic>.from(section('progress')[chapter] ?? {});
  Future<void> init() async {
    await storage.open();
    data = await storage.load();
    await extensions.init();
    BackgroundDownloads.listen(pauseAllDownloads);
    for (final job in section('downloads').values) {
      if (job['status'] == 'downloading') {
        job['status'] = 'paused';
      }
    }
    if (kIsWeb) {
      section('downloads').clear();
    }
    await LibraryUpdates.bind(
      (id) => updateLibrary(requestId: id),
      cancelUpdate,
    );
  }

  Future<void> persist() {
    final snapshot = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => storage.save(snapshot));
    notifyListeners();
    return _writes;
  }

  Future<void> setting(String key, dynamic value) async {
    final existed = settings.containsKey(key), old = settings[key];
    settings[key] = value;
    if (key == 'readerMode' || key == 'rtl') {
      final current = readerPreferences('_default').toJson();
      current[key == 'readerMode' ? 'mode' : key] = value;
      section('readerProfiles')['_default'] = current;
    }
    await persist();
    if (['updateHours', 'updateWifi', 'updateNotify'].contains(key)) {
      try {
        await LibraryUpdates.configure(settings);
      } catch (_) {
        if (existed) {
          settings[key] = old;
        } else {
          settings.remove(key);
        }
        await persist();
        rethrow;
      }
    }
  }

  ReaderPreferences readerPreferences(String mangaId) {
    final global = Map<String, dynamic>.from(
      section('readerProfiles')['_default'] ??
          {
            'mode': settings['readerMode'] ?? 'paged',
            'rtl': settings['rtl'] == true,
          },
    );
    final title = Map<String, dynamic>.from(
      section('readerProfiles')[mangaId] ?? {},
    );
    return ReaderPreferences.fromJson({...global, ...title});
  }

  Future<void> saveReaderPreferences(
    String mangaId,
    ReaderPreferences value, {
    bool global = false,
  }) async {
    section('readerProfiles')[global ? '_default' : mangaId] = value.toJson();
    if (global) {
      settings['readerMode'] = value.mode;
      settings['rtl'] = value.rtl;
    }
    await persist();
  }

  Future<void> resetReaderPreferences(String mangaId) async {
    section('readerProfiles').remove(mangaId);
    await persist();
  }

  Future<void> prioritize(String id) async {
    final job = section('downloads')[id];
    if (job == null || job['status'] == 'complete') {
      return;
    }
    final priorities = section('downloads').values
        .map((j) => j['priority'] as int? ?? 0);
    job['priority'] = priorities.fold<int>(0, (a, b) => a > b ? a : b) + 1;
    await persist();
  }

  Future<void> resumeDownload(String id) async {
    final job = section('downloads')[id];
    if (job == null || ['complete', 'downloading'].contains(job['status'])) {
      return;
    }
    job['status'] = 'queued';
    job.remove('error');
    await persist();
    unawaited(runQueue());
  }

  bool updatingLibrary = false;
  int updateDone = 0, updateTotal = 0;
  String? _updateId;
  void cancelUpdate(String id) {
    if (_updateId == id) _updateId = null;
  }

  Future<Map<String, dynamic>> updateLibrary({String? requestId}) async {
    if (updatingLibrary) return {'busy': true};
    final id = requestId ?? 'manual-${DateTime.now().microsecondsSinceEpoch}';
    final titles = saved.where((m) => m.source != 'local').toList();
    updatingLibrary = true;
    _updateId = id;
    updateDone = 0;
    updateTotal = titles.length;
    final failures = <String, String>{};
    int found = 0;
    final timer = Stopwatch()..start();
    final cursor = requestId == null
        ? 0
        : (section('updateState')['cursor'] as int? ?? 0) %
              (titles.isEmpty ? 1 : titles.length);
    notifyListeners();
    try {
      for (int i = 0; i < titles.length; i++) {
        if (_updateId != id ||
            (requestId != null && timer.elapsed.inMinutes >= 5)) {
          break;
        }
        final m = titles[(cursor + i) % titles.length];
        final existing = chapters(m.id).map((c) => c.id).toSet();
        try {
          final latest = await refresh(m);
          if (existing.isNotEmpty) {
            for (final chapter in latest.where(
              (c) => !existing.contains(c.id),
            )) {
              found++;
              section('updates')[chapter.id] = {
                'chapter': chapter.toJson(),
                'time': DateTime.now().toIso8601String(),
              };
            }
          }
        } catch (e) {
          failures[m.id] = e.toString();
        }
        updateDone++;
        section('updateState')['cursor'] = (cursor + i + 1) % titles.length;
        notifyListeners();
      }
      final entries = section('updates');
      while (entries.length > 5000) {
        entries.remove(entries.keys.first);
      }
      section('updateState').addAll({
        'time': DateTime.now().toIso8601String(),
        'checked': updateDone,
        'total': updateTotal,
        'newChapters': found,
        'failures': failures,
        'cancelled': _updateId != id,
      });
      await persist();
      return {
        'newChapters': found,
        'failed': failures.length,
        'checked': updateDone,
      };
    } finally {
      updatingLibrary = false;
      _updateId = null;
      notifyListeners();
    }
  }

  void stopLibraryUpdate() {
    _updateId = null;
  }

  Future<void> remember(Manga m) async {
    section('manga')[m.id] = m.toJson();
    await persist();
  }

  Future<void> toggle(Manga m) async {
    section('manga')[m.id] = m.toJson();
    if (section('library').containsKey(m.id)) {
      section('library').remove(m.id);
    } else {
      section('library')[m.id] = {
        'category': 'Reading',
        'favorite': false,
        'added': DateTime.now().toIso8601String(),
      };
    }
    await persist();
  }

  Future<List<Chapter>> refresh(Manga m) async {
    if (m.source == 'local') {
      return chapters(m.id);
    }
    final provider = sourceFor(m.source);
    if (provider is ExtensionMangaSource) {
      final result = await provider.update(m);
      // Keep the original library identity even if a source normalizes its URL.
      final updated = Manga.fromJson({...result.$1.toJson(), 'id': m.id});
      section('chapters')[m.id] = result.$2.map((c) => c.toJson()).toList();
      await remember(updated);
      return result.$2;
    }
    final list = await provider.chapters(
      m.id,
      language: settings['language'] ?? 'en',
    );
    section('chapters')[m.id] = list.map((c) => c.toJson()).toList();
    await remember(m);
    return list;
  }

  Future<List<String>> pages(Chapter c) async {
    final job = section('downloads')[c.id];
    if (job?['status'] == 'complete' || c.id.startsWith('local-')) {
      return List.generate(job?['total'] as int? ?? c.pages, (i) => 'local:$i');
    }
    return onlinePages(c);
  }

  Future<List<String>> onlinePages(Chapter c) {
    final provider = sourceFor(
      c.id.startsWith('ext:') ? c.id.split(':').take(2).join(':') : 'mangadex',
    );
    return provider is ExtensionMangaSource
        ? provider.pageList(c)
        : provider.pages(c.id);
  }

  Future<Uint8List> readPage(String chapter, int index, String url) =>
      pageCache.get('$chapter/$index', () async {
        final local = await storage.page(chapter, index);
        if (local != null) return local;
        if (url.startsWith('local:')) {
          throw const FormatException(
            'Offline page is missing. Import or download this chapter again.',
          );
        }
        return imageFetcher(url);
      });

  Future<void> position(
    Manga m,
    Chapter c,
    int page,
    int total, {
    double offset = 0,
    bool? completed,
  }) async {
    section('sessions')[DateTime.now().toIso8601String().substring(0, 10)] =
        true;
    section('manga')[m.id] = m.toJson();
    section('progress')[c.id] = {
      'page': page,
      'offset': offset,
      'total': total,
      'complete':
          progress(c.id)['complete'] == true ||
          (completed ?? page >= total - 1),
      'time': DateTime.now().toIso8601String(),
    };
    section('history')[m.id] = {
      'chapter': c.toJson(),
      'page': page,
      'offset': offset,
      'total': total,
      'time': DateTime.now().toIso8601String(),
    };
    await persist();
  }

  Future<void> bookmark(String chapter, int page) async {
    final key = '$chapter:$page';
    if (section('bookmarks').containsKey(key)) {
      section('bookmarks').remove(key);
    } else {
      section('bookmarks')[key] = true;
    }
    await persist();
  }

  Future<void> enqueue(Manga m, Chapter c) => enqueueBatch(m, [c]);
  Future<void> enqueueBatch(Manga m, Iterable<Chapter> chapters) async {
    final batch = chapters.toList();
    if (batch.any((c) => c.mangaId != m.id)) {
      throw const FormatException('Chapter belongs to a different title');
    }
    section('manga')[m.id] = m.toJson();
    bool changed = false;
    for (final c in batch) {
      final old = section('downloads')[c.id];
      if (old?['status'] == 'complete' || old?['status'] == 'downloading') {
        continue;
      }
      section('downloads')[c.id] = {
        'chapter': c.toJson(),
        'status': 'queued',
        'done': old?['done'] ?? 0,
        'total': old?['total'] ?? c.pages,
        'priority': old?['priority'] ?? 0,
        'queuedAt': old?['queuedAt'] ?? DateTime.now().microsecondsSinceEpoch,
      };
      changed = true;
    }
    if (!changed) return;
    await persist();
    unawaited(runQueue());
  }

  Future<void> pauseAllDownloads() async {
    for (final job in section('downloads').values) {
      if (['queued', 'downloading'].contains(job['status'])) {
        job['status'] = 'paused';
      }
    }
    await persist();
  }

  Future<void> resumeAllDownloads() async {
    for (final job in section('downloads').values) {
      if (['paused', 'failed'].contains(job['status'])) {
        job['status'] = 'queued';
        job.remove('error');
      }
    }
    await persist();
    unawaited(runQueue());
  }

  Future<void> pause(String id) async {
    final job = section('downloads')[id];
    if (job == null || job['status'] == 'complete') {
      return;
    }
    job['status'] = 'paused';
    await persist();
  }

  Future<void> removeDownload(String id) async {
    await pause(id);
    // Wait for the in-flight page to finish before deleting its storage.
    while (active == id) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await storage.deletePages(id);
    pageCache.clear();
    covers.clear();
    section('downloads').remove(id);
    await persist();
  }

  String? active;
  Future<void> runQueue() async {
    if (running ||
        !section('downloads').values.any((j) => j['status'] == 'queued')) {
      return;
    }
    downloadError = null;
    running = true;
    try {
      try {
        await BackgroundDownloads.start();
      } catch (e) {
        downloadError =
            'Background service unavailable; keep StarReader open. $e';
      }
      while (true) {
        final queued =
            section('downloads').entries
                .where((e) => e.value['status'] == 'queued')
                .toList()
              ..sort((a, b) {
                final priority = (b.value['priority'] as int? ?? 0).compareTo(
                  a.value['priority'] as int? ?? 0,
                );
                return priority != 0
                    ? priority
                    : (a.value['queuedAt'] as int? ?? 0).compareTo(
                        b.value['queuedAt'] as int? ?? 0,
                      );
              });
        final entry = queued.firstOrNull;
        if (entry == null) {
          break;
        }
        final job = entry.value;
        active = entry.key;
        job['status'] = 'downloading';
        job.remove('error');
        final currentChapter = Chapter.fromJson(
          Map<String, dynamic>.from(job['chapter']),
        );
        final title =
            manga
                .where((m) => m.id == currentChapter.mangaId)
                .firstOrNull
                ?.title ??
            currentChapter.title;
        await persist();
        try {
          final urls = await onlinePages(
            Chapter.fromJson(Map<String, dynamic>.from(job['chapter'])),
          );
          job['total'] = urls.length;
          if (urls.isEmpty) {
            throw const FormatException('Chapter has no readable pages');
          }
          for (int i = 0; i < urls.length; i++) {
            if (job['status'] != 'downloading') {
              break;
            }
            if (await storage.page(entry.key, i) == null) {
              final bytes = await imageFetcher(urls[i]);
              if (job['status'] != 'downloading') {
                break;
              }
              await storage.putPage(entry.key, i, bytes);
            }
            job['done'] = i + 1;
            await persist();
            try {
              await BackgroundDownloads.update(
                title,
                i + 1,
                urls.length,
                section('downloads').values
                    .where(
                      (j) => ['queued', 'downloading'].contains(j['status']),
                    )
                    .length,
              );
            } catch (_) {
              /* Foreground reading remains available if notifications are restricted. */
            }
          }
          if (job['status'] == 'downloading') {
            job['status'] = 'complete';
          }
        } catch (e) {
          if (job['status'] == 'downloading') {
            job['status'] = 'failed';
            job['error'] = e.toString();
          }
          downloadError = e.toString();
        }
        active = null;
        await persist();
      }
    } catch (e) {
      downloadError = 'Queue stopped: $e';
      if (active != null) {
        final job = section('downloads')[active];
        if (job != null && job['status'] == 'downloading') {
          job['status'] = 'failed';
          job['error'] = e.toString();
        }
      }
    } finally {
      try {
        await BackgroundDownloads.stop();
      } catch (_) {}
      running = false;
      active = null;
      notifyListeners();
    }
  }

  static bool isImage(Uint8List bytes) {
    try {
      ImageDimensions.read(bytes);
      return true;
    } on FormatException {
      return false;
    }
  }

  static Future<Uint8List> fetchImage(String url) async {
    if (url.startsWith('extimg:')) {
      final bytes = await ExtensionBridge.image(url);
      if (!isImage(bytes)) {
        throw const FormatException('Source returned an invalid image');
      }
      return bytes;
    }
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') {
      throw const FormatException('HTTPS required');
    }
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Image HTTP ${response.statusCode}');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        builder.add(chunk);
        if (builder.length > 40 * 1024 * 1024) {
          throw const FormatException('Page exceeds 40 MB safety limit');
        }
      }
      final bytes = builder.takeBytes();
      if (!isImage(bytes)) {
        throw const FormatException('Unsupported or invalid image');
      }
      return bytes;
    } finally {
      client.close();
    }
  }

  Future<void> importCbz(String name, Uint8List bytes) async {
    if (bytes.length > 250 * 1024 * 1024) {
      throw const FormatException('Archive exceeds 250 MB');
    }
    await _importArchive(name, decodeCbz(InputMemoryStream(bytes)));
  }

  Future<void> importCbzPath(String name, String path) async {
    final input = await openArchivePath(path);
    try {
      await _importArchive(name, input.archive);
    } finally {
      await input.close();
    }
  }

  Future<void> _importArchive(String name, Archive archive) async {
    final files =
        archive.files
            .where(
              (f) =>
                  f.isFile &&
                  RegExp(
                    r'\.(png|jpe?g|webp|gif)$',
                    caseSensitive: false,
                  ).hasMatch(f.name),
            )
            .toList()
          ..sort((a, b) => naturalCompare(a.name, b.name));
    if (files.isEmpty ||
        files.length > 1500 ||
        files.fold<int>(0, (n, f) => n + f.size) > 750 * 1024 * 1024 ||
        files.any((f) => f.size > 40 * 1024 * 1024)) {
      throw const FormatException(
        'Archive contains no images or exceeds safe import limits',
      );
    }
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    try {
      for (int i = 0; i < files.length; i++) {
        final b = files[i].content;
        if (!isImage(b)) {
          throw const FormatException('Invalid image in archive');
        }
        await storage.putPage(id, i, b);
        files[i].clear();
      }
    } catch (_) {
      await storage.deletePages(id);
      pageCache.clear();
      covers.clear();
      rethrow;
    }
    final m = Manga(
      id: id,
      title: name.replaceFirst(RegExp(r'\.cbz$', caseSensitive: false), ''),
      source: 'local',
      description: 'Imported from your own CBZ archive. Stored privately on this device.',
    );
    final c = Chapter(
      id: id,
      mangaId: id,
      title: 'Local volume',
      number: '1',
      pages: files.length,
    );
    section('chapters')[id] = [c.toJson()];
    section('downloads')[id] = {
      'chapter': c.toJson(),
      'status': 'complete',
      'done': files.length,
      'total': files.length,
    };
    try {
      await toggle(m);
    } catch (_) {
      section('chapters').remove(id);
      section('downloads').remove(id);
      section('manga').remove(id);
      section('library').remove(id);
      await storage.deletePages(id);
      rethrow;
    }
  }

  static int naturalCompare(String a, String b) {
    final re = RegExp(r'\d+|\D+');
    final x = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final y = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (int i = 0; i < x.length && i < y.length; i++) {
      final n = int.tryParse(x[i]), m = int.tryParse(y[i]);
      final c = n != null && m != null ? n.compareTo(m) : x[i].compareTo(y[i]);
      if (c != 0) {
        return c;
      }
    }
    return x.length.compareTo(y.length);
  }

  String backup() => jsonEncode({
    'format': 'starreader',
    'version': 1,
    'data': {...data, 'downloads': {}},
  });
  Future<void> restore(String raw) async {
    if (utf8.encode(raw).length > 20 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 20 MB');
    }
    final j = jsonDecode(raw);
    if (j is! Map ||
        j['format'] != 'starreader' ||
        j['version'] != 1 ||
        j['data'] is! Map) {
      throw const FormatException('Not a supported StarReader backup');
    }
    final candidate = Map<String, dynamic>.from(j['data']);
    for (final key in [
      'manga',
      'library',
      'chapters',
      'history',
      'settings',
      'progress',
      'bookmarks',
    ]) {
      if (candidate[key] != null && candidate[key] is! Map<String, dynamic>) {
        throw FormatException('Invalid $key');
      }
    }
    for (final m in (candidate['manga'] as Map? ?? {}).values) {
      Manga.fromJson(Map<String, dynamic>.from(m));
    }
    for (final list in (candidate['chapters'] as Map? ?? {}).values) {
      for (final c in list as List) {
        Chapter.fromJson(Map<String, dynamic>.from(c));
      }
    }
    void require(bool valid, String name) {
      if (!valid) {
        throw FormatException('Invalid backup $name');
      }
    }

    for (final e in (candidate['manga'] as Map? ?? {}).entries) {
      final m = Manga.fromJson(Map<String, dynamic>.from(e.value));
      require(
        e.key == m.id &&
            m.id.isNotEmpty &&
            m.title.length <= 2000 &&
            (['local', 'mangadex'].contains(m.source) ||
                RegExp(r'^ext:[0-9]+$').hasMatch(m.source)),
        'title',
      );
      require(
        m.cover.isEmpty ||
            (Uri.tryParse(m.cover)?.scheme == 'https' &&
                (Uri.tryParse(m.cover)?.host == 'uploads.mangadex.org' ||
                    m.source.startsWith('ext:'))),
        'cover URL',
      );
    }
    void validateMetadata(Map<String, dynamic> metadata) {
      require(
        metadata.isEmpty ||
            (metadata['url'] is String &&
                (metadata['url'] as String).length <= 8192),
        'source URL',
      );
      if (metadata['memo'] != null) {
        require(
          metadata['memo'] is String &&
              (metadata['memo'] as String).length <= 1024 * 1024,
          'source memo',
        );
        require(
          jsonDecode(metadata['memo']) is Map<String, dynamic>,
          'source memo object',
        );
      }
    }

    for (final value in (candidate['manga'] as Map? ?? {}).values) {
      final m = Manga.fromJson(Map<String, dynamic>.from(value));
      require(
        !m.source.startsWith('ext:') || m.id.startsWith('${m.source}:'),
        'source identity',
      );
      validateMetadata(m.metadata);
    }
    for (final list in (candidate['chapters'] as Map? ?? {}).values) {
      for (final value in list as List) {
        validateMetadata(
          Chapter.fromJson(Map<String, dynamic>.from(value)).metadata,
        );
      }
    }
    for (final value in (candidate['library'] as Map? ?? {}).values) {
      require(
        value is Map &&
            value['category'] is String &&
            value['favorite'] is bool &&
            value['added'] is String &&
            (value['collections'] == null ||
                (value['collections'] is List &&
                    (value['collections'] as List).every(
                      (v) => v is String && v.length <= 40,
                    ))) &&
            (value['notes'] == null ||
                (value['notes'] is String && value['notes'].length <= 10000)) &&
            (value['tags'] == null ||
                (value['tags'] is List &&
                    value['tags'].length <= 30 &&
                    (value['tags'] as List).every(
                      (t) => t is String && t.length <= 40,
                    ))),
        'library entry',
      );
    }
    for (final value in (candidate['progress'] as Map? ?? {}).values) {
      require(
        value is Map &&
            value['page'] is int &&
            value['page'] >= 0 &&
            value['total'] is int &&
            value['total'] >= 0 &&
            value['complete'] is bool &&
            value['time'] is String,
        'progress',
      );
    }
    for (final value in (candidate['history'] as Map? ?? {}).values) {
      require(
        value is Map &&
            value['chapter'] is Map &&
            value['page'] is int &&
            value['page'] >= 0 &&
            value['total'] is int &&
            value['time'] is String &&
            DateTime.tryParse(value['time']) != null,
        'history',
      );
      Chapter.fromJson(Map<String, dynamic>.from(value['chapter']));
    }
    for (final entry in (candidate['bookmarks'] as Map? ?? {}).entries) {
      require(
        entry.value is bool && RegExp(r'^.+:[0-9]+$').hasMatch(entry.key),
        'bookmark',
      );
    }
    final restoredSettings = Map<String, dynamic>.from(
      candidate['settings'] ?? {},
    );
    for (final entry in restoredSettings.entries) {
      final valid = switch (entry.key) {
        'theme' => ['dark', 'light', 'amoled'].contains(entry.value),
        'accent' =>
          entry.value is int && entry.value >= 0 && entry.value <= 0xffffffff,
        'columns' => [2, 3, 4].contains(entry.value),
        'imageCacheMb' => [32, 64, 96, 128].contains(entry.value),
        'coverRatio' => [2 / 3, .75, 1.0].contains(entry.value),
        'spacing' => [8, 14, 20].contains(entry.value),
        'textScale' => [1.0, 1.15, 1.3].contains(entry.value),
        'reduceMotion' || 'updateWifi' || 'updateNotify' => entry.value is bool,
        'updateHours' => [0, 6, 12, 24, 72].contains(entry.value),
        'readerMode' => ['paged', 'vertical', 'webtoon'].contains(entry.value),
        'language' =>
          entry.value is String &&
              RegExp(r'^[a-z]{2,3}(-[a-z]{2,4})?$').hasMatch(entry.value),
        'rtl' || 'awake' || 'volume' || 'onboarded' => entry.value is bool,
        _ => false,
      };
      require(valid, 'setting ${entry.key}');
    }
    if (candidate['categories'] != null) {
      require(
        candidate['categories'] is List &&
            (candidate['categories'] as List).isNotEmpty &&
            (candidate['categories'] as List).every(
              (v) => v is String && v.isNotEmpty && v.length <= 40,
            ),
        'categories',
      );
    }
    for (final key in ['sessions', 'readerProfiles']) {
      require(
        candidate[key] == null || candidate[key] is Map<String, dynamic>,
        key,
      );
    }
    for (final e in (candidate['sessions'] as Map? ?? {}).entries) {
      require(
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(e.key) &&
            DateTime.tryParse(e.key) != null &&
            e.value is bool,
        'reading session',
      );
    }
    for (final prefs in (candidate['readerProfiles'] as Map? ?? {}).values) {
      require(ReaderPreferences.isValid(prefs), 'reader preferences');
    }
    final previous = data;
    final merged = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    for (final key in [
      'manga',
      'library',
      'chapters',
      'history',
      'progress',
      'bookmarks',
      'settings',
      'sessions',
      'readerProfiles',
    ]) {
      final target = Map<String, dynamic>.from(merged[key] ?? {});
      final values = Map<String, dynamic>.from(candidate[key] ?? {});
      if (key == 'settings') {
        values.removeWhere(
          (key, _) =>
              ['updateHours', 'updateWifi', 'updateNotify'].contains(key),
        );
      }
      target.addAll(values);
      merged[key] = target;
    }
    if (candidate['categories'] != null) {
      merged['categories'] = {
        ...categories,
        ...List<String>.from(candidate['categories']),
      }.toList();
    }
    // Preserve live queue references: a restore can finish while a page is in flight.
    merged['downloads'] = section('downloads');
    data = merged;
    try {
      await persist();
    } catch (_) {
      data = previous;
      notifyListeners();
      rethrow;
    }
  }
}
