import 'dart:io';

import 'package:starreader/core/source.dart';

Future<void> main() async {
  final source = MangaDexSource();
  try {
    final titles = await source.search();
    stdout.writeln('Catalogue: ${titles.length} real titles');
    for (final title in titles.take(5)) {
      final chapters = await source.chapters(title.id);
      stdout.writeln(
        'Title checked: ${chapters.length} English readable chapters',
      );
      if (chapters.isNotEmpty) {
        final pages = await source.pages(chapters.first.id);
        stdout.writeln('Chapter: ${pages.length} HTTPS page URLs');
        break;
      }
    }
  } finally {
    source.client.close();
  }
}
