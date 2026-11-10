import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/reader.dart';
import 'package:starreader/core/models.dart';
import 'package:provider/provider.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  for (final fit in ['width', 'height']) {
    testWidgets('fit $fit keeps an oversized page reachable through panning', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final name = fit == 'width' ? 'long_strip.png' : 'wide_page.png';
      final bytes = File('test/fixtures/$name').readAsBytesSync();
      final library = Library(
        MemoryStorage(),
        imageFetcher: (_) async => bytes,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderImage(
              chapter: 'fit-$fit',
              index: 0,
              url: 'https://example.invalid/page.png',
              library: library,
              continuous: false,
              fit: fit,
              margin: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final imageSize = tester.getSize(find.byType(Image));
      if (fit == 'width') {
        expect(imageSize.width, 360);
        expect(imageSize.height, 7200);
      } else {
        expect(imageSize.height, 640);
        expect(imageSize.width, 12800);
      }
      await tester.drag(
        find.byType(InteractiveViewer),
        fit == 'width' ? const Offset(0, -300) : const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final position = viewer.transformationController!.value.getTranslation();
      expect(fit == 'width' ? position.y : position.x, lessThan(-200));
      expect(tester.takeException(), isNull);
    });
  }
  for (final fitted in [false, true]) {
    testWidgets(
      fitted
          ? 'a fitted wide page pans without accidentally turning the chapter page'
          : 'double-tap zoom reserves drag gestures for the image until zoom is reset',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = MemoryStorage();
        final library = Library(storage);
        const manga = Manga(
          id: 'local-volume',
          title: 'Pan fixture',
          source: 'local',
        );
        const chapter = Chapter(
          id: 'local-wide',
          mangaId: 'local-volume',
          title: 'Wide pages',
          pages: 2,
        );
        final bytes = File('test/fixtures/wide_page.png').readAsBytesSync();
        await storage.putPage(chapter.id, 0, bytes);
        await storage.putPage(chapter.id, 1, bytes);
        library.section('chapters')[manga.id] = [chapter.toJson()];
        library.section('readerProfiles')[manga.id] = {
          'fit': fitted ? 'height' : 'contain',
          'autoHide': false,
        };
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: library,
            child: const MaterialApp(
              home: Reader(manga: manga, chapter: chapter),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final viewer = find.byType(InteractiveViewer).first;
        if (!fitted) {
          await tester.tap(viewer);
          await tester.pump(const Duration(milliseconds: 80));
          await tester.tap(viewer);
          await tester.pumpAndSettle();
        }
        expect(
          tester.widget<PageView>(find.byType(PageView)).physics,
          isA<NeverScrollableScrollPhysics>(),
        );
        final before = tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!
            .value
            .getTranslation()
            .x;
        await tester.drag(viewer, const Offset(-220, 0));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          0,
        );
        final after = tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!
            .value
            .getTranslation()
            .x;
        expect(after, lessThan(before - 100));
        if (!fitted) {
          await tester.tap(viewer);
          await tester.pump(const Duration(milliseconds: 80));
          await tester.tap(viewer);
          await tester.pumpAndSettle();
          expect(
            tester.widget<PageView>(find.byType(PageView)).physics,
            isNot(isA<NeverScrollableScrollPhysics>()),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
