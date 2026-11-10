import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Check picker metadata before reading and enforce the bound again per chunk.
Future<Uint8List> readPickedBytes(
  PlatformFile file, {
  required int maxBytes,
}) async {
  if (file.size > maxBytes) {
    throw FormatException('File exceeds ${maxBytes ~/ 1048576} MB');
  }
  if (file.readStream != null) {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.readStream!) {
      if (builder.length + chunk.length > maxBytes) {
        throw const FormatException('File exceeds the import limit');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
  final bytes = file.bytes;
  if (bytes == null) {
    throw const FormatException('File could not be read. Select it again.');
  }
  if (bytes.length > maxBytes) {
    throw const FormatException('File exceeds the import limit');
  }
  return bytes;
}
