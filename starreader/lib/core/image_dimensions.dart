import 'dart:math' as math;
import 'dart:typed_data';

/// Reads dimensions without decoding pixels, including in Flutter web.
/// The codec still validates pixel data when a page is displayed.
class ImageDimensions {
  final int width, height;
  const ImageDimensions(this.width, this.height);
  static ImageDimensions read(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    bool text(int at, String value) =>
        at + value.length <= bytes.length &&
        List.generate(
          value.length,
          (i) => bytes[at + i] == value.codeUnitAt(i),
        ).every((v) => v);
    ImageDimensions? size;
    if (bytes.length >= 24 &&
        bytes[0] == 137 &&
        text(1, 'PNG\r\n\x1a\n') &&
        text(12, 'IHDR')) {
      size = ImageDimensions(data.getUint32(16), data.getUint32(20));
    } else if (bytes.length >= 10 && (text(0, 'GIF87a') || text(0, 'GIF89a'))) {
      size = ImageDimensions(
        data.getUint16(6, Endian.little),
        data.getUint16(8, Endian.little),
      );
    } else if (bytes.length >= 30 && text(0, 'RIFF') && text(8, 'WEBP')) {
      if (text(12, 'VP8X')) {
        int u24(int p) => bytes[p] | (bytes[p + 1] << 8) | (bytes[p + 2] << 16);
        size = ImageDimensions(u24(24) + 1, u24(27) + 1);
      } else if (text(12, 'VP8L') && bytes[20] == 0x2f) {
        final packed = data.getUint32(21, Endian.little);
        size = ImageDimensions(
          (packed & 0x3fff) + 1,
          ((packed >> 14) & 0x3fff) + 1,
        );
      } else if (text(12, 'VP8 ') &&
          bytes[23] == 0x9d &&
          bytes[24] == 1 &&
          bytes[25] == 0x2a) {
        size = ImageDimensions(
          data.getUint16(26, Endian.little) & 0x3fff,
          data.getUint16(28, Endian.little) & 0x3fff,
        );
      }
    } else if (bytes.length >= 4 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      var p = 2;
      while (p + 3 < bytes.length) {
        if (bytes[p++] != 0xff) break;
        while (p < bytes.length && bytes[p] == 0xff) {
          p++;
        }
        if (p >= bytes.length) break;
        final marker = bytes[p++];
        if (marker == 0xda || marker == 0xd9) break;
        if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd8)) continue;
        if (p + 2 > bytes.length) break;
        final length = data.getUint16(p);
        if (length < 2 || p + length > bytes.length) break;
        if ([
              0xc0,
              0xc1,
              0xc2,
              0xc3,
              0xc5,
              0xc6,
              0xc7,
              0xc9,
              0xca,
              0xcb,
              0xcd,
              0xce,
              0xcf,
            ].contains(marker) &&
            length >= 7) {
          size = ImageDimensions(data.getUint16(p + 5), data.getUint16(p + 3));
          break;
        }
        p += length;
      }
    }
    if (size == null ||
        size.width < 1 ||
        size.height < 1 ||
        size.width > 65536 ||
        size.height > 262144 ||
        size.width * size.height > 64000000 ||
        size.height / size.width > 1000 ||
        size.width / size.height > 1000) {
      throw const FormatException(
        'Unsupported, malformed, or excessively large image dimensions',
      );
    }
    return size;
  }

  ImageDimensions decoded({
    int maxWidth = 2048,
    int maxHeight = 8192,
    int maxPixels = 8000000,
  }) {
    final scale = [
      1.0,
      maxWidth / width,
      maxHeight / height,
      math.sqrt(maxPixels / (width * height)),
    ].reduce(math.min);
    return ImageDimensions(
      math.max(1, (width * scale).floor()),
      math.max(1, (height * scale).floor()),
    );
  }
}
