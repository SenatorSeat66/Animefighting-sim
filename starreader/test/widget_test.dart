import 'package:starreader/core/library_updates.dart';
import 'package:starreader/core/extensions.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/models.dart';
import 'package:starreader/core/source.dart';
import 'package:starreader/core/storage.dart';
import 'package:starreader/main.dart';

class MemoryStorage extends Storage {
  Map<String, dynamic> state = {};
  final Map<String, Uint8List> images = {};
  @override
  Future<void> open() async {}
  @override
  Future<Map<String, dynamic>> load() async => state;
  @override
  Future<void> save(Map<String, dynamic> s) async {
    state = jsonDecode(jsonEncode(s));
  }

  @override
  Future<void> putPage(String chapter, int page, Uint8List bytes) async {
    images['$chapter:$page'] = bytes;
  }

  @override
  Future<Uint8List?> page(String chapter, int page) async =>
      images['$chapter:$page'];
  @override
  Future<void> deletePages(String chapter) async {
    images.removeWhere((k, v) => k.startsWith('$chapter:'));
  }
}

class EmptySource implements MangaSource {
  @override
  String get id => 'test';
  @override
  String get name => 'Test';
  @override
  Future<List<Manga>> search({
    String query = '',
    int offset = 0,
    String sort = 'followedCount',
    String status = '',
  }) async => [];
  @override
  Future<List<Chapter>> chapters(
    String mangaId, {
    String language = 'en',
  }) async => [];
  @override
  Future<List<String>> pages(String chapterId) async => [];
  @override
  Future<void> health() async {}
}

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

  const m = Manga(id: 'a', title: 'A title');
  const c = Chapter(id: 'c', mangaId: 'a', title: 'One', pages: 3);
  test('library, category and progress survive a restart', () async {
    final storage = MemoryStorage();
    final l = Library(storage);
    await l.init();
    await l.toggle(m);
    await l.position(m, c, 2, 3);
    final restarted = Library(storage);
    await restarted.init();
    expect(restarted.saved.single.title, m.title);
    expect(restarted.progress(c.id)['complete'], true);
    expect(restarted.section('history')['a']['page'], 2);
  });
  test('backup merges metadata and keeps local download records', () async {
    final l = Library(MemoryStorage());
    await l.init();
    await l.toggle(m);
    final backup = l.backup();
    l.section('downloads')['local'] = {'status': 'complete'};
    await l.restore(backup);
    expect(l.saved.length, 1);
    expect(l.section('downloads').containsKey('local'), true);
    await expectLater(l.restore('{"format":"mihon"}'), throwsFormatException);
    expect(l.saved.length, 1);
  });
  test('natural archive order and image validation', () {
    final pages = ['10.png', '2.png', '1.png']..sort(Library.naturalCompare);
    expect(pages, ['1.png', '2.png', '10.png']);
    expect(
      Library.isImage(
        Uint8List.fromList(utf8.encode('<html>not an image</html>')),
      ),
      false,
    );
  });
  test('source reports HTTP errors instead of inventing content', () async {
    final source = MangaDexSource(
      client: MockClient((_) async => http.Response('rate limit', 429)),
    );
    await expectLater(source.search(), throwsA(isA<Exception>()));
  });
  test('source keeps metadata and cover relationship', () async {
    final source = MangaDexSource(
      client: MockClient((request) async {
        expect(request.url.queryParameters['title'], 'story');
        return http.Response(
          jsonEncode({
            'result': 'ok',
            'data': [
              {
                'id': 'id',
                'attributes': {
                  'title': {'en': 'Story'},
                  'description': {'en': 'Synopsis'},
                  'status': 'ongoing',
                  'tags': [],
                },
                'relationships': [
                  {
                    'type': 'cover_art',
                    'attributes': {'fileName': 'cover.jpg'},
                  },
                  {
                    'type': 'author',
                    'attributes': {'name': 'Author'},
                  },
                ],
              },
            ],
          }),
          200,
        );
      }),
    );
    final result = await source.search(query: 'story');
    expect(result.single.author, 'Author');
    expect(result.single.cover, contains('cover.jpg.256.jpg'));
  });
  testWidgets('onboarding and each main navigation route renders', (
    tester,
  ) async {
    final l = Library(MemoryStorage(), source: EmptySource());
    await l.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: l, child: const StarReader()),
    );
    expect(find.text('Enter StarReader'), findsOneWidget);
    await tester.ensureVisible(find.text('Enter StarReader'));
    await tester.tap(find.text('Enter StarReader'));
    await tester.pumpAndSettle();
    expect(find.text('The reading room'), findsOneWidget);
    for (final name in ['Library', 'Discover', 'Activity', 'Settings']) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(l.settings['theme'], 'light');
  });
  testWidgets('narrow screen onboarding has no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l = Library(MemoryStorage(), source: EmptySource());
    await l.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: l, child: const StarReader()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
