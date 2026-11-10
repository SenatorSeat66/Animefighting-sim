import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundDownloads {
  static const channel = MethodChannel('app.starreader/downloads');
  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static void listen(Future<void> Function() pause) {
    if (available) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'pause') await pause();
      });
    }
  }

  static Future<void> start() async {
    if (available) await channel.invokeMethod<void>('start');
  }

  static Future<void> stop() async {
    if (available) await channel.invokeMethod<void>('stop');
  }

  static Future<void> update(
    String title,
    int done,
    int total,
    int remaining,
  ) async {
    if (available) {
      await channel.invokeMethod<void>('update', {
        'title': title,
        'done': done,
        'total': total,
        'remaining': remaining,
      });
    }
  }
}
