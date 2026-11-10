import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'source.dart';
import 'storage.dart';

class Library extends ChangeNotifier {
  final Storage storage;
  final MangaSource source;
  Library(
    this.storage, {
    MangaSource? source,
    Future<Uint8List> Function(String)? imageFetcher,
  }) : source = source ?? MangaDexSource(),
       imageFetcher = imageFetcher ?? fetchImage;
  final Future<Uint8List> Function(String) imageFetcher;
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
    for (final job in section('downloads').values) {
      if (job['status'] == 'downloading') {
        job['status'] = 'paused';
      }
    }
    if (kIsWeb) {
      section('downloads').clear();
    }
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
    settings[key] = value;
    await persist();
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
    final list = await source.chapters(
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
    return source.pages(c.id);
  }

  Future<void> position(Manga m, Chapter c, int page, int total) async {
    section('sessions')[DateTime.now().toIso8601String().substring(0, 10)] =
        true;
    section('manga')[m.id] = m.toJson();
    section('progress')[c.id] = {
      'page': page,
      'total': total,
      'complete': progress(c.id)['complete'] == true || page >= total - 1,
      'time': DateTime.now().toIso8601String(),
    };
    section('history')[m.id] = {
      'chapter': c.toJson(),
      'page': page,
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

  Future<void> enqueue(Manga m, Chapter c) async {
    await remember(m);
    final old = section('downloads')[c.id];
    if (old?['status'] == 'complete' || old?['status'] == 'downloading') {
      return;
    }
    section('downloads')[c.id] = {
      'chapter': c.toJson(),
      'status': 'queued',
      'done': old?['done'] ?? 0,
      'total': old?['total'] ?? c.pages,
    };
    await persist();
    unawaited(runQueue());
  }

  Future<void> pause(String id) async {
    section('downloads')[id]['status'] = 'paused';
    await persist();
  }

  Future<void> removeDownload(String id) async {
    await pause(id);
    // Wait for the in-flight page to finish before deleting its storage.
    while (active == id) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await storage.deletePages(id);
    section('downloads').remove(id);
    await persist();
  }

  String? active;
  Future<void> runQueue() async {
    if (running) {
      return;
    }
    running = true;
    try {
      while (true) {
        final entry = section('downloads').entries
            .where((e) => e.value['status'] == 'queued')
            .firstOrNull;
        if (entry == null) {
          break;
        }
        final job = entry.value;
        active = entry.key;
        job['status'] = 'downloading';
        await persist();
        try {
          final urls = await source.pages(entry.key);
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
    } finally {
      running = false;
      active = null;
      notifyListeners();
    }
  }

  static bool isImage(Uint8List b) =>
      b.length > 12 &&
      ((b[0] == 0xff && b[1] == 0xd8) ||
          (b[0] == 137 && b[1] == 80 && b[2] == 78 && b[3] == 71) ||
          (ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
              ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') ||
          ascii.decode(b.sublist(0, 3), allowInvalid: true) == 'GIF');
  static Future<Uint8List> fetchImage(String url) async {
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
    final archive = ZipDecoder().decodeBytes(bytes);
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
        final b = Uint8List.fromList(files[i].content);
        if (!isImage(b)) {
          throw const FormatException('Invalid image in archive');
        }
        await storage.putPage(id, i, b);
      }
    } catch (_) {
      await storage.deletePages(id);
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
    await toggle(m);
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
            ['local', 'mangadex'].contains(m.source),
        'title',
      );
      require(
        m.cover.isEmpty ||
            (Uri.tryParse(m.cover)?.scheme == 'https' &&
                Uri.tryParse(m.cover)?.host == 'uploads.mangadex.org'),
        'cover URL',
      );
    }
    for (final value in (candidate['library'] as Map? ?? {}).values) {
      require(
        value is Map &&
            value['category'] is String &&
            value['favorite'] is bool &&
            value['added'] is String,
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
        'readerMode' => ['paged', 'vertical', 'webtoon'].contains(entry.value),
        'language' => ['en', 'ja', 'es', 'pt-br', 'fr'].contains(entry.value),
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
    ]) {
      final target = Map<String, dynamic>.from(merged[key] ?? {});
      target.addAll(Map<String, dynamic>.from(candidate[key] ?? {}));
      merged[key] = target;
    }
    if (candidate['categories'] != null) {
      merged['categories'] = {
        ...categories,
        ...List<String>.from(candidate['categories']),
      }.toList();
    }
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
