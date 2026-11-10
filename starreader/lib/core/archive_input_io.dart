import 'dart:io';

import 'package:archive/archive_io.dart';

import 'archive_input.dart';
import 'archive_decoder.dart';

Future<ArchiveInput> openArchivePath(String path) async {
  if (await File(path).length() > 250 * 1024 * 1024) {
    throw const FormatException('Archive exceeds 250 MB');
  }
  final input = InputFileStream(path);
  try {
    final archive = decodeCbz(input);
    return ArchiveInput(archive, () async {
      await input.close();
    });
  } catch (_) {
    await input.close();
    rethrow;
  }
}
