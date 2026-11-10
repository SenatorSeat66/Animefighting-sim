import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starreader/core/image_dimensions.dart';
import 'package:starreader/core/thumbnail_cache.dart';

void main() {
  test(
    'dimension parsing supports actual PNG JPEG GIF and both WebP encodings',
    () {
      for (final name in [
        'long_strip.png',
        'long_strip.jpg',
        'long_strip.webp',
        'long_strip_lossless.webp',
        'long_strip.gif',
      ]) {
        final size = ImageDimensions.read(
          File('test/fixtures/$name').readAsBytesSync(),
        );
        expect(size.width, 120, reason: name);
        expect(size.height, 2400, reason: name);
      }
      final long = const ImageDimensions(900, 150000).decoded();
      expect(long.height, lessThanOrEqualTo(8192));
      expect(long.width * long.height, lessThanOrEqualTo(8000000));
      final small = const ImageDimensions(120, 2400).decoded();
      expect(small.width, 120);
    },
  );
  test(
    'truncated headers and hostile image dimensions fail before pixel decoding',
    () {
      final bytes = File('test/fixtures/long_strip.png').readAsBytesSync();
      for (var length = 0; length < 24; length++) {
        expect(
          () => ImageDimensions.read(Uint8List.sublistView(bytes, 0, length)),
          throwsFormatException,
        );
      }
      final hostile = Uint8List.fromList(bytes);
      ByteData.sublistView(hostile).setUint32(16, 0xffffffff);
      expect(() => ImageDimensions.read(hostile), throwsFormatException);
      ByteData.sublistView(hostile).setUint32(16, 900);
      ByteData.sublistView(hostile).setUint32(20, 150000);
      expect(() => ImageDimensions.read(hostile), throwsFormatException);
    },
  );
  testWidgets(
    'cover cache returns bounded thumbnails and reuses the compressed result',
    (tester) async {
      await tester.runAsync(() async {
        final cache = ThumbnailCache();
        int reads = 0;
        Future<Uint8List> load() async {
          reads++;
          return File('test/fixtures/long_strip.png').readAsBytes();
        }

        final result = await cache.get('fixture', load);
        final size = ImageDimensions.read(result);
        expect(size.width, 300);
        expect(size.height, 450);
        expect(await cache.get('fixture', load), same(result));
        expect(reads, 1);
      });
    },
  );
}
