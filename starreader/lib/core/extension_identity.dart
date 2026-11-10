import 'dart:convert';

/// Mihon chapter URLs are unique within a manga, not necessarily within a source.
abstract final class ExtensionIdentity {
  static String encode(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  static String manga(String source, String url) =>
      'ext:$source:${encode(url)}';
  static String chapter(String mangaId, String url) =>
      '$mangaId:${encode(url)}';
}
