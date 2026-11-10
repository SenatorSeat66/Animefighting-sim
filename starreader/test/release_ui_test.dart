import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/models.dart';
import 'package:starreader/core/reader_preferences.dart';
import 'package:starreader/main.dart';
import 'package:starreader/enhancements.dart';
import 'package:starreader/reader.dart';
import 'package:starreader/ui/reader_settings.dart';
import 'package:starreader/ui/startup.dart';

import 'widget_test.dart' show MemoryStorage, EmptySource;

class RetrySource extends EmptySource {
  int attempts = 0;
  @override
  Future<List<Manga>> search({
    String query = '',
    int offset = 0,
    String sort = '',
    String status = '',
  }) async {
    if (++attempts == 1) throw StateError('Temporary catalogue failure');
    return [
      const Manga(id: 'fixture', title: 'Recovered catalogue', source: 'local'),
    ];
  }
}

void main() {
  testWidgets(
    'startup displays loading, preserves failure and retries before opening the app',
    (tester) async {
      var pending = Completer<void>();
      var attempts = 0;
      await tester.pumpWidget(
        StarReaderStartup(
          initialize: () {
            attempts++;
            return pending.future;
          },
          child: const MaterialApp(home: Scaffold(body: Text('Library ready'))),
        ),
      );
      expect(
        find.text('Getting your library and sources ready…'),
        findsOneWidget,
      );
      expect(find.text('Library ready'), findsNothing);
      pending.completeError(StateError('Cannot open database'));
      await tester.pumpAndSettle();
      expect(find.text('Your reading room couldn’t open.'), findsOneWidget);
      expect(attempts, 1);
      pending = Completer<void>();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('Library ready'), findsNothing);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Library ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large download queue is lazy and queued action pauses the selected chapter',
    (tester) async {
      final l = Library(MemoryStorage());
      for (var i = 0; i < 1000; i++) {
        final c = Chapter(id: 'c$i', mangaId: 'm', title: 'Part $i');
        l.section('downloads')[c.id] = {
          'chapter': c.toJson(),
          'status': 'queued',
          'done': 0,
          'total': 10,
          'queuedAt': i,
        };
      }
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: l,
          child: const MaterialApp(home: Downloads()),
        ),
      );
      await tester.pump();
      expect(find.byType(Card).evaluate().length, lessThan(12));
      expect(find.byTooltip('Pause'), findsWidgets);
      expect(find.byTooltip('Resume'), findsNothing);
      await tester.tap(find.byTooltip('Pause').first);
      await tester.pump();
      expect(l.section('downloads')['c0']['status'], 'paused');
      expect(l.section('downloads')['c1']['status'], 'queued');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reader defaults show a disk error without falsely reporting a successful save',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderSettingsPanel(
              preferences: const ReaderPreferences(),
              onChanged: (_) {},
              onDefault: (_) async => throw StateError('disk full'),
              onReset: () async => const ReaderPreferences(),
              onBrightness: (_) {},
              brightness: -1,
            ),
          ),
        ),
      );
      await tester.dragUntilVisible(
        find.text('Use for new stories'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.tap(find.text('Use for new stories'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not save reader defaults'),
        findsOneWidget,
      );
      expect(find.text('Saved as your default'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reader retries a transient page failure without losing its position',
    (tester) async {
      final bytes = File('test/fixtures/long_strip.png').readAsBytesSync();
      var attempts = 0;
      final library = Library(
        MemoryStorage(),
        imageFetcher: (_) async {
          if (++attempts == 1) throw StateError('temporary network failure');
          return bytes;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderImage(
              chapter: 'network',
              index: 3,
              url: 'https://example.invalid/page.png',
              library: library,
              continuous: false,
              fit: 'contain',
              margin: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page 4 could not load'), findsOneWidget);
      await tester.tap(find.text('Retry page'));
      // The page's double-tap recognizer yields after its gesture timeout.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Page 4 could not load'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('catalogue retry fetches again after a source failure', (
    tester,
  ) async {
    final source = RetrySource();
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
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(source.attempts, 2);
    expect(find.text('Recovered catalogue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history accepts a valid compact imported date and builds large lists lazily',
    (tester) async {
      final library = Library(MemoryStorage());
      for (var i = 0; i < 1000; i++) {
        final m = Manga(id: 'm$i', title: 'Story $i', source: 'local');
        final c = Chapter(
          id: 'local-$i',
          mangaId: m.id,
          title: 'Volume',
          pages: 1,
        );
        library.section('manga')[m.id] = m.toJson();
        library.section('history')[m.id] = {
          'chapter': c.toJson(),
          'page': 0,
          'total': 1,
          'time': '20261110',
        };
      }
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: library,
          child: const MaterialApp(home: Scaffold(body: Activity())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, lessThan(15));
      expect(tester.takeException(), isNull);
    },
  );
}
