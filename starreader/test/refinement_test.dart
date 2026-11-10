import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:starreader/core/file_input.dart';
import 'package:starreader/core/library_updates.dart';

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:starreader/core/extensions.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/library_query.dart';
import 'package:starreader/core/models.dart';
import 'package:starreader/main.dart';

import 'widget_test.dart' show MemoryStorage, EmptySource;

class FailingStorage extends MemoryStorage {
  bool fail = false;
  @override
  Future<void> save(Map<String, dynamic> s) async {
    if (fail) throw StateError('disk full');
    return super.save(s);
  }
}

class UpdateSource extends EmptySource {
  int calls = 0;
  @override
  Future<List<Chapter>> chapters(
    String mangaId, {
    String language = 'en',
  }) async {
    calls++;
    if (mangaId == 'broken') throw StateError('Source unavailable');
    return [
      Chapter(id: '$mangaId-old', mangaId: mangaId, title: 'Old'),
      Chapter(id: '$mangaId-new', mangaId: mangaId, title: 'New'),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LibraryUpdates.channel, (call) async => null);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          ExtensionBridge.channel,
          (call) async => call.method == 'list' ? <dynamic>[] : null,
        ),
  );
  test(
    'streaming CBZ input reads pages and picker bounds are enforced',
    () async {
      final directory = Directory.systemTemp.createTempSync('starreader-cbz-');
      try {
        final bytes = File('test/fixtures/long_strip.png').readAsBytesSync();
        final archive = Archive()
          ..addFile(ArchiveFile.bytes('10.png', bytes))
          ..addFile(ArchiveFile.bytes('2.png', bytes));
        final file = File('${directory.path}/volume.cbz')
          ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
        final storage = MemoryStorage();
        final l = Library(storage);
        await l.init();
        await l.importCbzPath('Volume.cbz', file.path);
        expect(l.saved.single.title, 'Volume');
        expect(storage.images.length, 2);
        await expectLater(
          readPickedBytes(
            PlatformFile(
              name: 'too-big',
              size: 100,
              readStream: Stream.value([1, 2]),
            ),
            maxBytes: 10,
          ),
          throwsFormatException,
        );
        await expectLater(
          readPickedBytes(
            PlatformFile(
              name: 'lying-size',
              size: 2,
              readStream: Stream.value(List.filled(20, 1)),
            ),
            maxBytes: 10,
          ),
          throwsFormatException,
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
  test('library update continues after a source failure and only reports genuinely new chapters', () async {
    final source = UpdateSource();
    final l = Library(MemoryStorage(), source: source);
    await l.init();
    for (final id in ['good', 'broken', 'fresh']) {
      await l.toggle(Manga(id: id, title: id));
      if (id != 'fresh') {
        l.section('chapters')[id] = [
          Chapter(id: '$id-old', mangaId: id, title: 'Old').toJson(),
        ];
      }
    }
    final report = await l.updateLibrary();
    expect(report['newChapters'], 1);
    expect(report['failed'], 1);
    expect(report['checked'], 3);
    expect(source.calls, 3);
    expect(l.updatingLibrary, false);
    expect(l.section('updates').keys, ['good-new']);
    expect(l.chapters('broken').single.id, 'broken-old');
    expect(l.section('updateState')['failures'], contains('broken'));
    expect((await l.updateLibrary())['newChapters'], 0);
  });
  test(
    'continuous reader can save the last strip without marking it complete',
    () async {
      final l = Library(MemoryStorage());
      await l.init();
      const m = Manga(id: 'a', title: 'A');
      const c = Chapter(id: 'c', mangaId: 'a', title: 'One strip', pages: 1);
      await l.position(m, c, 0, 1, offset: -2, completed: false);
      expect(l.progress('c')['complete'], false);
      expect(l.progress('c')['offset'], -2);
      await l.position(m, c, 0, 1, offset: -8, completed: true);
      expect(l.progress('c')['complete'], true);
    },
  );
  test('library filters combine tags, secondary collections, progress and duplicate titles', () async {
    final l = Library(MemoryStorage(), source: EmptySource());
    await l.init();
    const a = Manga(
      id: 'a',
      title: 'Blue Moon',
      author: 'Aki',
      source: 'local',
    );
    const b = Manga(id: 'b', title: 'Blue-Moon', source: 'mangadex');
    const c = Chapter(id: 'c', mangaId: 'a', title: 'One', pages: 3);
    await l.toggle(a);
    await l.toggle(b);
    l.section('library')['a']['collections'] = ['Reading', 'Weekend'];
    l.section('library')['a']['tags'] = ['comfort'];
    l.section('chapters')['a'] = [c.toJson()];
    await l.position(a, c, 0, 3);
    expect(
      const LibraryQuery(
        query: 'aki comfort',
        collection: 'Weekend',
        state: 'In progress',
      ).apply(l).map((m) => m.id),
      ['a'],
    );
    expect(const LibraryQuery(state: 'Duplicates').apply(l), hasLength(2));
    expect(const LibraryQuery(state: 'Finished').apply(l), isEmpty);
    await l.position(a, c, 2, 3);
    expect(const LibraryQuery(state: 'Finished').apply(l).map((m) => m.id), [
      'a',
    ]);
    expect(
      const LibraryQuery(source: 'mangadex', collection: 'Weekend').apply(l),
      isEmpty,
    );
    final restored = Library(MemoryStorage());
    await restored.init();
    await restored.restore(l.backup());
    expect(
      const LibraryQuery(
        query: 'comfort',
        collection: 'Weekend',
      ).apply(restored).single.id,
      'a',
    );
  });
  test(
    'CBZ import removes pages and metadata when saving the library fails',
    () async {
      final storage = FailingStorage();
      final l = Library(storage);
      await l.init();
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      final archive = Archive()..addFile(ArchiveFile.bytes('1.png', png));
      storage.fail = true;
      await expectLater(
        l.importCbz('Book.cbz', ZipEncoder().encodeBytes(archive)),
        throwsStateError,
      );
      expect(storage.images, isEmpty);
      expect(l.saved, isEmpty);
      expect(l.section('chapters'), isEmpty);
      expect(l.section('downloads'), isEmpty);
    },
  );
  test(
    'queue storage failure is visible and releases the running flag',
    () async {
      final storage = FailingStorage();
      final l = Library(storage, source: EmptySource());
      await l.init();
      l.section('downloads')['c'] = {
        'chapter': const Chapter(id: 'c', mangaId: 'a', title: 'One').toJson(),
        'status': 'queued',
        'done': 0,
        'total': 0,
      };
      storage.fail = true;
      await l.runQueue();
      expect(l.running, false);
      expect(l.active, isNull);
      expect(l.downloadError, contains('disk full'));
      expect(l.section('downloads')['c']['status'], 'failed');
    },
  );
  testWidgets(
    'four-column covers fit large text without overflow on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l = Library(MemoryStorage(), source: EmptySource());
      await l.init();
      await l.setting('columns', 4);
      await l.setting('textScale', 1.3);
      final items = List.generate(
        2000,
        (i) => Manga(
          id: '$i',
          title: 'A rather long title with many words',
          source: 'local',
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: l,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.7),
              ),
              child: Scaffold(
                body: CustomScrollView(slivers: [MangaSliverGrid(items)]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MangaTile).evaluate().length, lessThan(60));
    },
  );
  testWidgets(
    'main routes remain usable at narrow width and enlarged system text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final l = Library(MemoryStorage(), source: EmptySource());
      await l.init();
      await l.setting('onboarded', true);
      await l.setting('textScale', 1.15);
      await l.toggle(
        const Manga(
          id: 'local-a',
          title: 'A title for the accessibility check',
          source: 'local',
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: l, child: const StarReader()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final tab in ['Library', 'Discover', 'Activity', 'Settings']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$tab must fit enlarged text',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
