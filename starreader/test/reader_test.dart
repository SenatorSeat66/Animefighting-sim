import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/models.dart';
import 'package:starreader/reader.dart';

import 'widget_test.dart' show MemoryStorage, EmptySource;

void main() {
  testWidgets(
    'offline reader restores position, turns pages, saves bookmark and changes mode',
    (tester) async {
      final storage = MemoryStorage();
      final l = Library(storage, source: EmptySource());
      await l.init();
      const m = Manga(id: 'local-book', title: 'Offline test', source: 'local');
      const c = Chapter(
        id: 'local-chapter',
        mangaId: 'local-book',
        title: 'Volume',
        pages: 3,
      );
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      for (int i = 0; i < 3; i++) {
        await storage.putPage(c.id, i, png);
      }
      l.section('chapters')[m.id] = [c.toJson()];
      await l.position(m, c, 1, 3);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: l,
          child: MaterialApp(
            home: Reader(manga: m, chapter: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byTooltip('Bookmark page'));
      await tester.pump();
      expect(l.section('bookmarks').containsKey('${c.id}:1'), true);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(l.progress(c.id)['page'], 2);
      await tester.tap(find.byTooltip('Reader settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuous'));
      await tester.pumpAndSettle();
      expect(l.settings['readerMode'], 'webtoon');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
