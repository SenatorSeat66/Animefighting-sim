import 'dart:io';

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:starreader/core/library_updates.dart';
import 'package:starreader/core/extensions.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/models.dart';
import 'package:starreader/reader.dart';

import 'widget_test.dart' show MemoryStorage, EmptySource;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LibraryUpdates.channel, (call) async => null);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          ExtensionBridge.channel,
          (call) async => call.method == 'list' ? <dynamic>[] : null,
        );
  });

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
      expect(l.readerPreferences(m.id).mode, 'webtoon');
      expect(l.readerPreferences('another-story').mode, 'paged');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'long strip restores its intra-page offset and completes only at the bottom',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage();
      final l = Library(storage, source: EmptySource());
      await l.init();
      const m = Manga(id: 'local-long', title: 'Long strip', source: 'local');
      const c = Chapter(
        id: 'local-strip',
        mangaId: 'local-long',
        title: 'One long image',
        pages: 1,
      );
      await storage.putPage(
        c.id,
        0,
        File('test/fixtures/long_strip.png').readAsBytesSync(),
      );
      l.section('chapters')[m.id] = [c.toJson()];
      await l.setting('readerMode', 'webtoon');
      Widget reader() => ChangeNotifierProvider.value(
        value: l,
        child: const MaterialApp(
          home: Reader(manga: m, chapter: c),
        ),
      );
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(l.progress(c.id)['complete'], false);
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      final offset = (l.progress(c.id)['offset'] as num).toDouble();
      expect(offset, lessThan(-1));
      expect(l.progress(c.id)['complete'], false);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(
        (l.progress(c.id)['offset'] as num).toDouble(),
        closeTo(offset, .2),
      );
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -16000),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(l.progress(c.id)['complete'], true);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
