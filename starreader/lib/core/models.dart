class Manga {
  final String id, title, cover, description, author, status, source;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  const Manga({
    required this.id,
    required this.title,
    this.cover = '',
    this.description = '',
    this.author = '',
    this.status = '',
    this.source = 'mangadex',
    this.tags = const [],
    this.metadata = const {},
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cover': cover,
    'description': description,
    'author': author,
    'status': status,
    'source': source,
    'tags': tags,
    'metadata': metadata,
  };
  factory Manga.fromJson(Map<String, dynamic> j) => Manga(
    id: j['id'] as String,
    title: j['title'] as String,
    cover: j['cover'] as String? ?? '',
    description: j['description'] as String? ?? '',
    author: j['author'] as String? ?? '',
    status: j['status'] as String? ?? '',
    source: j['source'] as String? ?? 'mangadex',
    tags: List<String>.from(j['tags'] ?? []),
    metadata: Map<String, dynamic>.from(j['metadata'] ?? {}),
  );
}

class Chapter {
  final String id, mangaId, title, number, language;
  final int pages;
  final Map<String, dynamic> metadata;
  const Chapter({
    required this.id,
    required this.mangaId,
    required this.title,
    this.number = '',
    this.language = 'en',
    this.pages = 0,
    this.metadata = const {},
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'mangaId': mangaId,
    'title': title,
    'number': number,
    'language': language,
    'pages': pages,
    'metadata': metadata,
  };
  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
    id: j['id'] as String,
    mangaId: j['mangaId'] as String,
    title: j['title'] as String,
    number: j['number'] as String? ?? '',
    language: j['language'] as String? ?? 'en',
    pages: j['pages'] as int? ?? 0,
    metadata: Map<String, dynamic>.from(j['metadata'] ?? {}),
  );
}

abstract interface class MangaSource {
  String get id;
  String get name;
  Future<List<Manga>> search({
    String query = '',
    int offset = 0,
    String sort = 'followedCount',
    String status = '',
  });
  Future<List<Chapter>> chapters(String mangaId, {String language = 'en'});
  Future<List<String>> pages(String chapterId);
  Future<void> health();
}
