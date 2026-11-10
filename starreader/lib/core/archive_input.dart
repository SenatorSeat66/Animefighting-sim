import 'package:archive/archive.dart';

import 'archive_input_stub.dart'
    if (dart.library.io) 'archive_input_io.dart'
    as platform;

class ArchiveInput {
  final Archive archive;
  final Future<void> Function() close;
  ArchiveInput(this.archive, this.close);
}

Future<ArchiveInput> openArchivePath(String path) =>
    platform.openArchivePath(path);
