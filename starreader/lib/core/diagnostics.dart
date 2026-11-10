import 'package:flutter/foundation.dart';

import 'extensions.dart';
import 'library.dart';

Future<Map<String, dynamic>> diagnostics(Library library) async {
  Map<String, dynamic> android = {};
  if (ExtensionBridge.available) {
    try {
      android = Map<String, dynamic>.from(
        await ExtensionBridge.call<Map>('diagnostics') ?? {},
      );
    } catch (_) {
      android = {'host': 'unavailable'};
    }
  }
  final statuses = <String, int>{};
  for (final job in library.section('downloads').values) {
    final status = job['status'] as String? ?? 'unknown';
    statuses.update(status, (n) => n + 1, ifAbsent: () => 1);
  }
  return {
    'format': 'starreader-diagnostics',
    'version': '0.2.0+2',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'android': android,
    'databaseSchema': 2,
    'libraryTitleCount': library.saved.length,
    'downloadStates': statuses,
    'repositoryCount': library.extensions.repositories.length,
    'extensions': [
      for (final e in library.extensions.installed)
        {
          'package': e.package,
          'version': e.version,
          'loadedSources': e.sources.length,
          'loadFailed': e.error.isNotEmpty,
        },
    ],
    'privacy': 'No titles, reading history, cookies, source preferences, credentials, or page images are included.',
  };
}
