import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'extension_repository.dart';
import 'extension_identity.dart';
import 'models.dart';

class MihonImport {
  final Map<String, dynamic> data;
  final int titles, chapters, skippedLocal;
  final Set<String> sourceIds;
  const MihonImport(
    this.data,
    this.titles,
    this.chapters,
    this.skippedLocal,
    this.sourceIds,
  );
  String get starReaderBackup =>
      jsonEncode({'format': 'starreader', 'version': 1, 'data': data});

  /// Reads the documented Mihon/Tachiyomi 0.x protobuf backup schema. No code,
  /// repository trust, credentials, source preferences or tracker tokens execute.
  static MihonImport parse(Uint8List input) {
    if (input.length > 20 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 20 MB compressed');
    }
    final bytes = input.length > 2 && input[0] == 31 && input[1] == 139
        ? const GZipDecoder().decodeBytes(
            input,
            verify: true,
            throwOnError: true,
            maxOutputSize: 64 * 1024 * 1024,
          )
        : input;
    final root = ProtoMessage.read(bytes, maxBytes: 64 * 1024 * 1024);
    final entries = root.allBytes(1);
    if (entries.isEmpty || entries.length > 10000) {
      throw const FormatException(
        'No supported manga records, or too many titles',
      );
    }
    final categories = <String, String>{};
    for (final raw in root.allBytes(2)) {
      final c = ProtoMessage.read(raw);
      final name = c.text(1).trim();
      if (name.isEmpty || name.length > 40) {
        throw const FormatException('Collection names must be 1–40 characters');
      }
      categories[c.integer(3).toString()] = name;
    }
    final manga = <String, dynamic>{},
        library = <String, dynamic>{},
        chapters = <String, dynamic>{};
    final progress = <String, dynamic>{},
        history = <String, dynamic>{},
        bookmarks = <String, dynamic>{},
        sessions = <String, dynamic>{};
    var chapterCount = 0, skipped = 0;
    final sources = <String>{};
    String identity(String source, String url) =>
        ExtensionIdentity.manga(source, url);
    String date(BigInt value) {
      if (value <= BigInt.zero) {
        return DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ).toIso8601String();
      }
      if (value > BigInt.from(253402300799999)) {
        throw const FormatException('Invalid backup timestamp');
      }
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toIso8601String();
    }

    Map<String, dynamic> meta(String url, Uint8List? raw) {
      var memo = '{}';
      if (raw != null) {
        if (raw.length > 1024 * 1024) {
          throw const FormatException('Source metadata exceeds 1 MB');
        }
        memo = utf8.decode(raw);
        if (jsonDecode(memo) is! Map) {
          throw const FormatException('Invalid source metadata');
        }
      }
      return {'url': url, 'memo': memo};
    }

    for (final raw in entries) {
      final entry = ProtoMessage.read(raw);
      final sourceNumber = entry.integer(1);
      if (sourceNumber <= BigInt.zero ||
          sourceNumber > BigInt.parse('9223372036854775807')) {
        skipped++;
        continue;
      }
      final source = sourceNumber.toString(),
          url = entry.text(2),
          title = entry.text(3);
      if (url.isEmpty ||
          url.length > 8192 ||
          title.isEmpty ||
          title.length > 2000) {
        throw const FormatException('Invalid manga record');
      }
      sources.add(source);
      final id = identity(source, url), cover = entry.text(9);
      final item = Manga(
        id: id,
        title: title,
        source: 'ext:$source',
        cover: Uri.tryParse(cover)?.scheme == 'https' ? cover : '',
        description: entry.text(6),
        author: {
          entry.text(5),
          entry.text(4),
        }.where((v) => v.isNotEmpty).join(' · '),
        tags: entry.allBytes(7).map(utf8.decode).toList(),
        status: switch (entry.integer(8).toInt()) {
          1 => 'ongoing',
          2 || 4 => 'completed',
          5 => 'cancelled',
          6 => 'hiatus',
          _ => 'unknown',
        },
        metadata: meta(url, entry.bytes(112)),
      );
      manga[id] = item.toJson();
      final memberships = entry
          .integers(17)
          .map((n) => categories[n.toString()])
          .whereType<String>()
          .toSet()
          .toList();
      if (!entry.fields.containsKey(100) || entry.integer(100) != BigInt.zero) {
        library[id] = {
          'category': memberships.firstOrNull ?? 'Reading',
          'collections': memberships,
          'favorite': false,
          'added': date(entry.integer(13)),
          'notes': entry.text(110),
        };
      }
      final list = <Chapter>[];
      final rawChapters = entry.allBytes(16).map(ProtoMessage.read).toList()
        ..sort((a, b) => b.integer(10).compareTo(a.integer(10)));
      for (final c in rawChapters) {
        if (++chapterCount > 150000) {
          throw const FormatException('Backup exceeds 150,000 chapters');
        }
        final chapterUrl = c.text(1), name = c.text(2);
        if (chapterUrl.isEmpty || chapterUrl.length > 8192) {
          throw const FormatException('Invalid chapter URL');
        }
        final chapterId = ExtensionIdentity.chapter(id, chapterUrl),
            number = c.floating(9);
        final chapter = Chapter(
          id: chapterId,
          mangaId: id,
          title: name,
          number: number.isFinite && number >= 0
              ? number.toString().replaceFirst(RegExp(r'\.0$'), '')
              : '',
          language: '',
          metadata: meta(chapterUrl, c.bytes(13)),
        );
        list.add(chapter);
        final page = c.integer(6);
        if (page > BigInt.from(1000000)) {
          throw const FormatException('Invalid reading position');
        }
        final read = c.integer(4) != BigInt.zero;
        if (read || page > BigInt.zero) {
          progress[chapterId] = {
            'page': page.toInt(),
            'total': 0,
            'complete': read,
            'time': date(c.integer(7)),
          };
        }
        if (c.integer(5) != BigInt.zero) {
          bookmarks['$chapterId:${page.toInt()}'] = true;
        }
      }
      chapters[id] = list.map((c) => c.toJson()).toList();
      final events = entry.allBytes(104).map(ProtoMessage.read).toList()
        ..sort((a, b) => b.integer(2).compareTo(a.integer(2)));
      for (final h in events) {
        if (h.integer(2) <= BigInt.zero) continue;
        final chapterId = ExtensionIdentity.chapter(id, h.text(1));
        final chapter = list.where((c) => c.id == chapterId).firstOrNull;
        if (chapter == null) continue;
        final time = date(h.integer(2));
        sessions[time.substring(0, 10)] = true;
        history.putIfAbsent(
          id,
          () => {
            'chapter': chapter.toJson(),
            'page': progress[chapterId]?['page'] ?? 0,
            'total': 0,
            'time': time,
          },
        );
      }
    }
    if (manga.isEmpty) {
      throw const FormatException(
        'This backup contains no supported online titles. Import local CBZ files separately.',
      );
    }
    return MihonImport(
      {
        'manga': manga,
        'library': library,
        'chapters': chapters,
        'progress': progress,
        'history': history,
        'bookmarks': bookmarks,
        'sessions': sessions,
        'categories': {'Reading', ...categories.values}.toList(),
      },
      manga.length,
      chapterCount,
      skipped,
      sources,
    );
  }
}
