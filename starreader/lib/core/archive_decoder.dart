import 'package:archive/archive.dart';

/// Check the central directory before ZipDecoder can materialize any content,
/// including symbolic-link payloads which the decoder otherwise reads eagerly.
Archive decodeCbz(InputStream input) {
  final start = input.position;
  var entries = 0, images = 0, expanded = 0;
  try {
    for (final header in ZipDirectory().headers(
      input,
      verify: true,
      files: false,
    )) {
      if (++entries > 10000) {
        throw const FormatException('Archive contains too many entries');
      }
      final mode = header.externalFileAttributes >> 16;
      if ((mode & 0xf000) == 0xa000) {
        throw const FormatException('CBZ symbolic links are not supported');
      }
      if ((header.generalPurposeBitFlag & 1) != 0) {
        throw const FormatException('Encrypted CBZ archives are not supported');
      }
      if (RegExp(
        r'\.(png|jpe?g|webp|gif)$',
        caseSensitive: false,
      ).hasMatch(header.filename)) {
        images++;
        expanded += header.uncompressedSize;
        if (images > 1500 ||
            header.uncompressedSize > 40 * 1024 * 1024 ||
            expanded > 750 * 1024 * 1024) {
          throw const FormatException(
            'Archive exceeds safe image import limits',
          );
        }
      }
    }
    if (images == 0) {
      throw const FormatException('Archive contains no supported images');
    }
  } finally {
    input.setPosition(start);
  }
  return ZipDecoder().decodeStream(input, verify: true);
}
