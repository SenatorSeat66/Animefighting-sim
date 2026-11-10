import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/models.dart';

import 'widget_test.dart' show MemoryStorage, EmptySource;

class PagesSource extends EmptySource {
  @override
  Future<List<String>> pages(String chapterId) async => [
    'https://example.invalid/1',
    'https://example.invalid/2',
  ];
}

Future<void> idle(Library l) async {
  for (int i = 0; i < 100 && l.running; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(l.running, false);
}

void main() {
  const manga = Manga(id: 'm', title: 'Title');
  const chapter = Chapter(id: 'c', mangaId: 'm', title: 'Chapter', pages: 2);
  test(
    'failed download retains completed pages and retries only missing pages',
    () async {
      final store = MemoryStorage();
      int calls = 0;
      bool fail = true;
      final l = Library(
        store,
        source: PagesSource(),
        imageFetcher: (url) async {
          calls++;
          if (url.endsWith('2') && fail) {
            throw Exception('connection lost');
          }
          return Uint8List.fromList([1, 2, 3]);
        },
      );
      await l.init();
      await l.enqueue(manga, chapter);
      await idle(l);
      expect(l.section('downloads')['c']['status'], 'failed');
      expect(l.section('downloads')['c']['done'], 1);
      fail = false;
      await l.enqueue(manga, chapter);
      await idle(l);
      expect(l.section('downloads')['c']['status'], 'complete');
      expect(calls, 3);
      await l.removeDownload('c');
      expect(await store.page('c', 0), isNull);
    },
  );
  test('pause during transfer does not mark chapter complete or persist late bytes', () async {
    final pending = Completer<Uint8List>();
    final store = MemoryStorage();
    final l = Library(
      store,
      source: PagesSource(),
      imageFetcher: (_) => pending.future,
    );
    await l.init();
    await l.enqueue(manga, chapter);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await l.pause('c');
    pending.complete(Uint8List.fromList([1, 2, 3]));
    await idle(l);
    expect(l.section('downloads')['c']['status'], 'paused');
    expect(await store.page('c', 0), isNull);
  });
  test(
    'malformed backup is rejected before changing any library data',
    () async {
      final l = Library(MemoryStorage());
      await l.init();
      await l.toggle(manga);
      final previous = l.backup();
      await expectLater(
        l.restore(
          '{"format":"starreader","version":1,"data":{"library":{"m":{"category":42}}}}',
        ),
        throwsFormatException,
      );
      expect(l.backup(), previous);
    },
  );
}
