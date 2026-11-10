import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_dimensions.dart';
import 'page_cache.dart';

/// At most two full cover inputs are in memory; widgets retain small thumbnails.
class ThumbnailCache {
  final _cache = PageCache(maximumBytes: 8 * 1024 * 1024);
  final _queue = Queue<Future<void> Function()>();
  int _active = 0;
  void clear() => _cache.clear();
  Future<Uint8List> get(String key, Future<Uint8List> Function() read) =>
      _cache.get(key, () {
        final complete = Completer<Uint8List>();
        _queue.add(() async {
          try {
            complete.complete(await _thumbnail(await read()));
          } catch (e, s) {
            complete.completeError(e, s);
          } finally {
            _active--;
            _drain();
          }
        });
        _drain();
        return complete.future;
      });
  void _drain() {
    while (_active < 2 && _queue.isNotEmpty) {
      _active++;
      unawaited(_queue.removeFirst()());
    }
  }

  Future<Uint8List> _thumbnail(Uint8List bytes) async {
    final size = ImageDimensions.read(bytes)
        .decoded(maxWidth: 600, maxHeight: 2048, maxPixels: 1200000);
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: size.width,
      targetHeight: size.height,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final cropHeight = math.min(
          frame.image.height.toDouble(),
          frame.image.width * 1.5,
        );
        final outputHeight = (300 * cropHeight / frame.image.width)
            .round()
            .clamp(1, 450);
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          frame.image,
          ui.Rect.fromLTWH(0, 0, frame.image.width.toDouble(), cropHeight),
          ui.Rect.fromLTWH(0, 0, 300, outputHeight.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(300, outputHeight);
          try {
            return (await image.toByteData(format: ui.ImageByteFormat.png))!
                .buffer
                .asUint8List();
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
