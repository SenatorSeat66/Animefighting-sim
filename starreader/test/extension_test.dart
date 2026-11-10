import 'package:starreader/core/library_updates.dart';

import 'dart:convert';
import 'dart:async';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starreader/enhancements.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:starreader/core/extension_repository.dart';
import 'package:starreader/core/extensions.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/models.dart';
import 'package:starreader/core/reader_preferences.dart';

import 'widget_test.dart' show MemoryStorage;

List<int> varint(BigInt n) {
  final bytes = <int>[];
  do {
    final b = (n & BigInt.from(127)).toInt();
    n >>= 7;
    bytes.add(b | (n > BigInt.zero ? 128 : 0));
  } while (n > BigInt.zero);
  return bytes;
}

List<int> number(int field, BigInt value) => [
  ...varint(BigInt.from(field << 3)),
  ...varint(value),
];
List<int> blob(int field, List<int> data) => [
  ...varint(BigInt.from((field << 3) | 2)),
  ...varint(BigInt.from(data.length)),
  ...data,
];
List<int> text(int field, String value) => blob(field, utf8.encode(value));
const certificate =
    '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2';
Uint8List index({
  String cert = certificate,
  String apk = 'https://example.org/source.apk',
}) {
  final source = [
    ...number(1, BigInt.parse('9223372036854775000')),
    ...text(2, 'Example source'),
    ...text(3, 'en'),
    ...text(4, 'https://example.org'),
  ];
  final extension = [
    ...text(1, 'Example'),
    ...text(2, 'org.example.extension'),
    ...blob(3, text(1, apk)),
    ...text(4, '1.6'),
    ...number(5, BigInt.from(106001)),
    ...text(6, '1.6.1'),
    ...number(7, BigInt.one),
    ...blob(8, source),
  ];
  return Uint8List.fromList([
    ...text(1, 'Example repository'),
    ...text(3, cert),
    ...blob(101, blob(1, extension)),
    ...text(999, 'future field'),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LibraryUpdates.channel, (call) async => null);
  test('gzip protobuf preserves source IDs and ignores future fields', () {
    final raw = GZipEncoder().encodeBytes(index());
    final repository = ExtensionRepository.parse(
      Uint8List.fromList(raw),
      ExtensionRepository.keiyoushi,
    );
    expect(repository.packages.single.sources.single.id, '9223372036854775000');
    expect(repository.packages.single.api, '1.6');
    expect(repository.certificate, certificate);
    expect(
      repository.url,
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb',
    );
  });
  test('rejects truncated, overflowing and untrusted index fields', () {
    expect(
      () => ProtoMessage.read(Uint8List.fromList([10, 99, 1])),
      throwsFormatException,
    );
    expect(
      () => ProtoMessage.read(Uint8List.fromList([8, ...List.filled(10, 255)])),
      throwsFormatException,
    );
    expect(
      () => ExtensionRepository.parse(
        index(cert: 'bad'),
        'https://example.org/index.pb',
      ),
      throwsFormatException,
    );
    expect(
      () => ExtensionRepository.parse(
        index(apk: 'file:///tmp/source.apk'),
        'https://example.org/index.pb',
      ),
      throwsFormatException,
    );
    expect(
      () => ExtensionRepository.normalize('http://example.org/index.pb'),
      throwsFormatException,
    );
    expect(
      () => ExtensionRepository.normalize(
        'https://password@example.org/index.pb',
      ),
      throwsFormatException,
    );
  });
  test(
    'repository fetch accepts the supplied GitHub URL and fails on HTTP errors',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'raw.githubusercontent.com');
        return http.Response.bytes(index(), 200);
      });
      expect(
        (await ExtensionRepository.fetch(
          ExtensionRepository.keiyoushi,
          client: client,
        )).packages.length,
        1,
      );
      await expectLater(
        ExtensionRepository.fetch(
          'https://example.org/index.pb',
          client: MockClient((_) async => http.Response('unavailable', 503)),
        ),
        throwsException,
      );
    },
  );
  test(
    'repository refresh cannot silently rotate a trusted certificate',
    () async {
      final manager = ExtensionManager(MemoryStorage());
      final original = ExtensionRepository.parse(
        index(),
        'https://example.org/index.pb',
      );
      await manager.add(original);
      final changed = ExtensionRepository.parse(
        index(cert: 'a' * 64),
        original.url,
      );
      await expectLater(manager.add(changed), throwsFormatException);
      expect(manager.repositories.single.certificate, certificate);
      final restored = ExtensionManager(manager.storage);
      await restored.init();
      expect(restored.packages.single.package, 'org.example.extension');
    },
  );
  test(
    'extension routing preserves manga/chapter memo through library and backup',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      const sourceId = 'ext:123';
      const manga = Manga(
        id: 'ext:123:L2Jvb2s',
        title: 'Story',
        source: sourceId,
        metadata: {'url': '/book', 'memo': '{"token":"synthetic"}'},
      );
      const chapter = Chapter(
        id: 'ext:123:L2NoYXB0ZXI',
        mangaId: 'ext:123:L2Jvb2s',
        title: 'Chapter',
        metadata: {'url': '/chapter', 'memo': '{"chapter":7}'},
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(ExtensionBridge.channel, (call) async {
        calls.add(call.method);
        if (call.method == 'list') return <dynamic>[];
        if (call.method == 'update') {
          expect(
            call.arguments['manga']['metadata']['memo'],
            '{"token":"synthetic"}',
          );
          return {
            'manga': manga.toJson(),
            'chapters': [chapter.toJson()],
          };
        }
        if (call.method == 'pages') {
          expect(
            call.arguments['chapter']['metadata']['memo'],
            '{"chapter":7}',
          );
          return [
            {
              'source': '123',
              'index': 0,
              'url': '/page',
              'imageUrl': 'https://example.org/image.png',
            },
          ];
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(ExtensionBridge.channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      final library = Library(MemoryStorage());
      await library.init();
      await library.toggle(manga);
      await library.refresh(manga);
      final pages = await library.pages(library.chapters(manga.id).single);
      expect(pages.single, startsWith('extimg:'));
      final restored = Library(MemoryStorage());
      await restored.init();
      await restored.restore(library.backup());
      expect(restored.saved.single.source, sourceId);
      expect(
        restored.chapters(manga.id).single.metadata['memo'],
        '{"chapter":7}',
      );
      expect(calls, containsAll(['update', 'pages']));
    },
  );
  test(
    'reader defaults, per-title overrides and sessions survive backup',
    () async {
      final library = Library(MemoryStorage());
      await library.init();
      await library.saveReaderPreferences(
        'one',
        const ReaderPreferences(mode: 'webtoon', background: 'paper'),
        global: true,
      );
      await library.saveReaderPreferences(
        'one',
        const ReaderPreferences(rtl: true, doubleTapScale: 3),
      );
      expect(library.readerPreferences('one').rtl, isTrue);
      expect(library.readerPreferences('two').mode, 'webtoon');
      library.section('sessions')['2026-11-10'] = true;
      final restored = Library(MemoryStorage());
      await restored.init();
      await restored.restore(library.backup());
      expect(restored.readerPreferences('one').doubleTapScale, 3);
      expect(restored.section('sessions')['2026-11-10'], true);
      await restored.resetReaderPreferences('one');
      expect(restored.readerPreferences('one').background, 'paper');
    },
  );
  test('a slow extension host cannot block the persisted offline library at startup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final response = Completer<List<dynamic>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          ExtensionBridge.channel,
          (call) => response.future,
        );
    try {
      final storage = MemoryStorage()
        ..state = {
          'manga': {
            'local-volume': const Manga(
              id: 'local-volume',
              title: 'Offline volume',
              source: 'local',
            ).toJson(),
          },
          'library': {
            'local-volume': {
              'category': 'Reading',
              'favorite': false,
              'added': '2026-11-10',
            },
          },
        };
      final library = Library(storage);
      await library.init().timeout(const Duration(seconds: 1));
      expect(library.saved.single.title, 'Offline volume');
      expect(library.extensions.loadingInstalled, true);
      response.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(library.extensions.loadingInstalled, false);
    } finally {
      if (!response.isCompleted) response.complete([]);
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ExtensionBridge.channel, null);
    }
  });
  testWidgets(
    'home catalogue loading preserves Discover extension pagination and end state',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final pages = <int>[];
      var firstPages = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ExtensionBridge.channel, (call) async {
            final page = call.arguments['page'] as int;
            pages.add(page);
            final count = page == 1 ? (++firstPages == 1 ? 2 : 3) : 1;
            return {
              'more': firstPages == 1,
              'items': List.generate(
                count,
                (i) => Manga(
                  id: 'item-$i',
                  title: 'Catalogue $i',
                  source: 'local',
                ).toJson(),
              ),
            };
          });
      try {
        final source = ExtensionMangaSource(
          const ExtensionSourceInfo(
            id: '42',
            name: 'Extension fixture',
            language: 'en',
            url: 'https://example.invalid',
          ),
        );
        await source.search();
        expect(source.hasMore, true);
        final library = Library(MemoryStorage(), source: source);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: library,
            child: const MaterialApp(
              home: Scaffold(
                body: CatalogueRail(title: 'Popular', sort: 'followedCount'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(source.hasMore, true);
        await source.search(offset: 2);
        expect(pages, [1, 1, 2]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ExtensionBridge.channel, null);
      }
    },
  );
}
