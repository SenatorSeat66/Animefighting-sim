import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LibraryUpdates {
  static const channel = MethodChannel('app.starreader/library_updates');
  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> bind(
    Future<Map<String, dynamic>> Function(String) run,
    void Function(String) cancel,
  ) async {
    if (!available) return;
    channel.setMethodCallHandler((call) async {
      final id = (call.arguments as Map?)?['id'] as String? ?? '';
      if (call.method == 'run') return run(id);
      if (call.method == 'cancel') cancel(id);
      return null;
    });
    try {
      await channel.invokeMethod<void>('ready');
    } on MissingPluginException {
      /* Non-Android test host. */
    }
  }

  static Future<void> configure(Map<String, dynamic> settings) async {
    if (!available) return;
    await channel.invokeMethod<void>('configure', {
      'hours': settings['updateHours'] ?? 0,
      'wifi': settings['updateWifi'] != false,
      'notify': settings['updateNotify'] == true,
    });
  }
}
