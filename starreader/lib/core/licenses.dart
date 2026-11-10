import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerStarReaderLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in {
      'Manrope': 'assets/fonts/OFL.txt',
      'Newsreader': 'assets/fonts/Newsreader-OFL.txt',
      'Mihon / Tachiyomi': 'assets/licenses/Mihon-NOTICE.txt',
      'Mihon, AndroidX, Kotlin, OkHttp, Okio, RxJava, Zstd KMP':
          'assets/licenses/Apache-2.0.txt',
      'Injekt': 'assets/licenses/Injekt-MIT.txt',
      'Jsoup': 'assets/licenses/Jsoup-MIT.txt',
      'Brotli decoder': 'assets/licenses/Brotli-MIT.txt',
      'QuickJS runtime': 'assets/licenses/QuickJS-MIT.txt',
      'QuickJS Java binding / Square': 'assets/licenses/Apache-2.0.txt',
      'Zstandard': 'assets/licenses/Zstd-BSD.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString(entry.value));
    }
  });
}
