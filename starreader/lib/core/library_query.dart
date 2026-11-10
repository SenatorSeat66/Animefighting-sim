import 'library.dart';
import 'models.dart';

/// Filters use persisted chapter state and preserve titles with unknown chapters.
class LibraryQuery {
  final String query, collection, state, source, sort;
  const LibraryQuery({
    this.query = '',
    this.collection = 'All',
    this.state = 'All',
    this.source = 'All',
    this.sort = 'Title',
  });
  static String normalizedTitle(String title) => title.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  List<Manga> apply(Library library) {
    final titles = library.saved;
    final duplicateCounts = <String, int>{};
    for (final m in titles) {
      duplicateCounts.update(
        normalizedTitle(m.title),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
    final unreadCounts = <String, int>{};
    int unread(Manga m) => unreadCounts.putIfAbsent(
      m.id,
      () => library
          .chapters(m.id)
          .where((c) => library.progress(c.id)['complete'] != true)
          .length,
    );
    String time(Manga m) => library.section('history')[m.id]?['time'] ?? '';
    final result = titles.where((m) {
      final entry = library.section('library')[m.id];
      final text =
          '${m.title} ${m.author} ${m.tags.join(' ')} ${(entry['tags'] as List? ?? []).join(' ')}'
              .toLowerCase();
      if (!terms.every(text.contains) ||
          (source != 'All' && source != m.source)) {
        return false;
      }
      if (collection != 'All' &&
          !(collection == 'Favorites'
              ? entry['favorite'] == true
              : entry['category'] == collection ||
                    (entry['collections'] as List? ?? []).contains(
                      collection,
                    ))) {
        return false;
      }
      final chapters = library.chapters(m.id);
      return switch (state) {
        'Unread' => chapters.any(
          (c) => library.progress(c.id)['complete'] != true,
        ),
        'In progress' =>
          library.section('history').containsKey(m.id) && unread(m) > 0,
        'Finished' => chapters.isNotEmpty && unread(m) == 0,
        'Downloaded' => chapters.any(
          (c) => library.section('downloads')[c.id]?['status'] == 'complete',
        ),
        'Duplicates' => (duplicateCounts[normalizedTitle(m.title)] ?? 0) > 1,
        _ => true,
      };
    }).toList();
    result.sort((a, b) {
      final order = switch (sort) {
        'Recently added' =>
          (library.section('library')[b.id]['added'] as String).compareTo(
            library.section('library')[a.id]['added'] as String,
          ),
        'Last read' => time(b).compareTo(time(a)),
        'Most unread' => unread(b).compareTo(unread(a)),
        _ => 0,
      };
      return order == 0
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : order;
    });
    return result;
  }
}
