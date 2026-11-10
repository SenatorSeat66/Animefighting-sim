import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starreader/core/page_cache.dart';

void main() {
  test(
    'deduplicates in-flight pages and evicts least recently read bytes',
    () async {
      final cache = PageCache(maximumBytes: 6);
      var fetches = 0;
      final pending = Completer<Uint8List>();
      Future<Uint8List> load() {
        fetches++;
        return pending.future;
      }

      final a = cache.get('a', load), b = cache.get('a', load);
      pending.complete(Uint8List(3));
      await a;
      await b;
      expect(fetches, 1);
      await cache.get('b', () async => Uint8List(3));
      await cache.get('a', () async => throw StateError('cached'));
      await cache.get('c', () async => Uint8List(3));
      expect(cache.bytes, 6);
      await cache.get('b', () async {
        fetches++;
        return Uint8List(3);
      });
      expect(fetches, 2);
    },
  );
  test('clear prevents a late request from repopulating cache', () async {
    final cache = PageCache(maximumBytes: 6);
    final pending = Completer<Uint8List>();
    final request = cache.get('a', () => pending.future);
    cache.clear();
    pending.complete(Uint8List(3));
    await request;
    expect(cache.bytes, 0);
  });
}
