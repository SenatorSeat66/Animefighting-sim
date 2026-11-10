import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starreader/core/archive_decoder.dart';
import 'package:starreader/core/library.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  final image = File('test/fixtures/long_strip.png').readAsBytesSync();
  Uint8List volume() => Uint8List.fromList(
    ZipEncoder().encodeBytes(
      Archive()..addFile(ArchiveFile.bytes('page.png', image)),
    ),
  );
  int central(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 4; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) return i;
    }
    throw StateError('Fixture directory missing');
  }

  test('CBZ preflight rejects oversized declarations and symlinks before decoding content', () {
    final oversized = volume();
    ByteData.sublistView(oversized)
        .setUint32(central(oversized) + 24, 1024 * 1024 * 1024, Endian.little);
    expect(
      () => decodeCbz(InputMemoryStream(oversized)),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'limit',
          contains('safe image import limits'),
        ),
      ),
    );
    final symlink = volume();
    ByteData.sublistView(symlink)
        .setUint32(central(symlink) + 38, 0xa1ff << 16, Endian.little);
    expect(
      () => decodeCbz(InputMemoryStream(symlink)),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'symlink',
          contains('symbolic links'),
        ),
      ),
    );
  });
  test('CBZ checksum corruption does not leave a partial library or downloaded pages', () async {
    final bytes = volume();
    final data = ByteData.sublistView(bytes);
    final at = central(bytes);
    data.setUint32(
      at + 16,
      data.getUint32(at + 16, Endian.little) ^ 0xffffffff,
      Endian.little,
    );
    final storage = MemoryStorage();
    final library = Library(storage);
    await expectLater(
      library.importCbz('Corrupt.cbz', bytes),
      throwsA(anything),
    );
    expect(storage.images, isEmpty);
    expect(library.saved, isEmpty);
    expect(library.section('downloads'), isEmpty);
  });
}
