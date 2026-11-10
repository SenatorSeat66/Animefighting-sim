import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class MangaDexSource implements MangaSource {
  final http.Client client;
  MangaDexSource({http.Client? client}) : client = client ?? http.Client();
  @override
  String get id => 'mangadex';
  @override
  String get name => 'MangaDex';
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, dynamic> query = const {},
  ]) async {
    final response = await client
        .get(
          Uri.https('api.mangadex.org', path, query),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception(
        response.statusCode == 429
            ? 'Source rate limit reached. Please wait and retry.'
            : 'Source returned HTTP ${response.statusCode}',
      );
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic> || value['result'] != 'ok') {
      throw const FormatException('Invalid source response');
    }
    return value;
  }

  @override
  Future<List<Manga>> search({
    String query = '',
    int offset = 0,
    String sort = 'followedCount',
    String status = '',
  }) async {
    final j = await get('/manga', {
      'limit': '30',
      'offset': '$offset',
      'includes[]': ['cover_art', 'author'],
      'contentRating[]': ['safe', 'suggestive'],
      'order[$sort]': 'desc',
      if (query.isNotEmpty) 'title': query,
      if (status.isNotEmpty) 'status[]': [status],
    });
    return (j['data'] as List).map((raw) {
      final m = raw as Map<String, dynamic>;
      final a = m['attributes'] as Map<String, dynamic>;
      final relations = m['relationships'] as List;
      final cover = relations
          .where((r) => r['type'] == 'cover_art')
          .firstOrNull;
      final title = Map<String, dynamic>.from(a['title']);
      final desc = Map<String, dynamic>.from(a['description'] ?? {});
      return Manga(
        id: m['id'],
        title: (title['en'] ?? title.values.firstOrNull ?? 'Untitled')
            .toString(),
        cover: cover?['attributes']?['fileName'] == null
            ? ''
            : 'https://uploads.mangadex.org/covers/${m['id']}/${cover['attributes']['fileName']}.256.jpg',
        description: (desc['en'] ?? desc.values.firstOrNull ?? '').toString(),
        author: relations
            .where((r) => r['type'] == 'author')
            .map((r) => r['attributes']?['name'] ?? '')
            .join(', '),
        status: a['status'] ?? '',
        tags: (a['tags'] as List)
            .map((t) => (t['attributes']['name']['en'] ?? '').toString())
            .toList(),
      );
    }).toList();
  }

  @override
  Future<List<Chapter>> chapters(
    String mangaId, {
    String language = 'en',
  }) async {
    final result = <Chapter>[];
    int offset = 0;
    while (true) {
      final j = await get('/manga/$mangaId/feed', {
        'limit': '500',
        'offset': '$offset',
        'translatedLanguage[]': [language],
        'order[chapter]': 'asc',
        'includeExternalUrl': '0',
      });
      final data = j['data'] as List;
      result.addAll(
        data.where((m) => (m['attributes']['pages'] as int? ?? 0) > 0).map((m) {
          final a = m['attributes'];
          return Chapter(
            id: m['id'],
            mangaId: mangaId,
            title: a['title'] ?? '',
            number: a['chapter'] ?? '',
            language: a['translatedLanguage'] ?? language,
            pages: a['pages'] ?? 0,
          );
        }),
      );
      offset += data.length;
      if (data.isEmpty || offset >= (j['total'] as int) || offset >= 10000) {
        break;
      }
    }
    return result;
  }

  @override
  Future<List<String>> pages(String chapterId) async {
    final j = await get('/at-home/server/$chapterId');
    final c = j['chapter'];
    final base = Uri.parse(j['baseUrl']);
    if (base.scheme != 'https') {
      throw const FormatException('Insecure image server rejected');
    }
    return (c['data'] as List)
        .map((p) => '$base/data/${c['hash']}/$p')
        .toList();
  }

  @override
  Future<void> health() async {
    await get('/manga', {'limit': '1'});
  }
}
