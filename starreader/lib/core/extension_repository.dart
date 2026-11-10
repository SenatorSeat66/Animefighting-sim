import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

/// Mihon ExtensionStore protobuf wire format, including gzip-compressed indexes.
/// Unknown fields are skipped so additions to the upstream schema remain safe.
class ExtensionRepository {
  final String url, name, certificate, website;
  final List<ExtensionPackage> packages;
  const ExtensionRepository({
    required this.url,
    required this.name,
    required this.certificate,
    required this.website,
    required this.packages,
  });
  static const keiyoushi =
      'https://github.com/keiyoushi/extensions/raw/repo/index.pb';
  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'certificate': certificate,
    'website': website,
    'packages': packages.map((p) => p.toJson()).toList(),
  };
  factory ExtensionRepository.fromJson(Map<String, dynamic> j) =>
      ExtensionRepository(
        url: j['url'],
        name: j['name'],
        certificate: j['certificate'],
        website: j['website'],
        packages: (j['packages'] as List)
            .map((p) => ExtensionPackage.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );

  static Uri normalize(String input) {
    var uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException('Use an HTTPS extension repository URL.');
    }
    // Accept the exact link supplied by Keiyoushi as well as its canonical raw URL.
    if (uri.host == 'github.com' &&
        uri.pathSegments.length >= 5 &&
        uri.pathSegments[2] == 'raw') {
      final parts = uri.pathSegments;
      uri = Uri.https(
        'raw.githubusercontent.com',
        '/${parts[0]}/${parts[1]}/${parts.skip(3).join('/')}',
      );
    }
    if (!uri.path.endsWith('.pb')) {
      uri = uri.replace(
        path: '${uri.path.replaceFirst(RegExp(r'/$'), '')}/index.pb',
      );
    }
    return uri;
  }

  static Future<Uint8List> _get(http.Client client, Uri uri) async {
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw Exception(
        'Repository HTTP ${response.statusCode}. Check the URL and try again.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final part in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      bytes.add(part);
      if (bytes.length > 12 * 1024 * 1024) {
        throw const FormatException('Repository exceeds 12 MB');
      }
    }
    return unpack(bytes.takeBytes());
  }

  static Uint8List unpack(Uint8List bytes) {
    if (bytes.length > 12 * 1024 * 1024) {
      throw const FormatException('Repository exceeds 12 MB');
    }
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      return const GZipDecoder().decodeBytes(
        bytes,
        verify: true,
        throwOnError: true,
        maxOutputSize: 16 * 1024 * 1024,
      );
    }
    return bytes;
  }

  static Future<ExtensionRepository> fetch(
    String url, {
    http.Client? client,
  }) async {
    final ownClient = client == null;
    client ??= http.Client();
    try {
      final uri = normalize(url);
      final fields = ProtoMessage.read(await _get(client, uri));
      Uint8List? list = fields.bytes(101);
      final external = fields.text(102);
      if (list == null && external.isNotEmpty) {
        final next = Uri.tryParse(external);
        if (next == null ||
            next.scheme != 'https' ||
            next.userInfo.isNotEmpty) {
          throw const FormatException('Invalid external extension list URL');
        }
        list = await _get(client, next);
      }
      return decode(fields, uri.toString(), list);
    } finally {
      if (ownClient) client.close();
    }
  }

  static ExtensionRepository parse(Uint8List bytes, String url) {
    final fields = ProtoMessage.read(unpack(bytes));
    return decode(fields, normalize(url).toString(), fields.bytes(101));
  }

  static ExtensionRepository decode(
    ProtoMessage fields,
    String url,
    Uint8List? list,
  ) {
    final name = fields.text(1), certificate = fields.text(3).toLowerCase();
    if (name.isEmpty ||
        name.length > 200 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(certificate) ||
        list == null) {
      throw const FormatException('Not a supported Mihon extension repository');
    }
    final entries = ProtoMessage.read(list).allBytes(1);
    if (entries.length > 10000) {
      throw const FormatException('Too many extension packages');
    }
    final packages = entries.map((raw) {
      final e = ProtoMessage.read(raw);
      final resources = ProtoMessage.read(e.bytes(3) ?? Uint8List(0));
      final apk = resources.text(1), pkg = e.text(2);
      if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$').hasMatch(pkg) ||
          Uri.tryParse(apk)?.scheme != 'https') {
        throw const FormatException('Invalid extension package or APK URL');
      }
      return ExtensionPackage(
        name: e.text(1),
        package: pkg,
        apk: apk,
        icon: resources.text(2),
        api: e.text(4),
        code: e.integer(5).toInt(),
        version: e.text(6),
        content: e.integer(7).toInt(),
        repository: url,
        certificate: certificate,
        sources: e.allBytes(8).map((raw) {
          final s = ProtoMessage.read(raw);
          return ExtensionSourceInfo(
            id: s.integer(1).toString(),
            name: s.text(2),
            language: s.text(3),
            url: s.text(4),
          );
        }).toList(),
      );
    }).toList();
    final contact = fields.bytes(4);
    return ExtensionRepository(
      url: url,
      name: name,
      certificate: certificate,
      website: contact == null ? '' : ProtoMessage.read(contact).text(1),
      packages: packages,
    );
  }
}

class ExtensionPackage {
  final String name, package, apk, icon, api, version, repository, certificate;
  final int code, content;
  final List<ExtensionSourceInfo> sources;
  const ExtensionPackage({
    required this.name,
    required this.package,
    required this.apk,
    required this.icon,
    required this.api,
    required this.version,
    required this.code,
    required this.content,
    required this.repository,
    required this.certificate,
    required this.sources,
  });
  bool get supported => ['1.4', '1.6'].contains(api);
  String get languages {
    final values = sources.map((s) => s.language.toUpperCase()).toSet();
    return values.length > 4
        ? '${values.length} languages'
        : values.join(' · ');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'package': package,
    'apk': apk,
    'icon': icon,
    'api': api,
    'version': version,
    'code': code,
    'content': content,
    'repository': repository,
    'certificate': certificate,
    'sources': sources.map((s) => s.toJson()).toList(),
  };
  factory ExtensionPackage.fromJson(Map<String, dynamic> j) => ExtensionPackage(
    name: j['name'],
    package: j['package'],
    apk: j['apk'],
    icon: j['icon'],
    api: j['api'],
    version: j['version'],
    code: j['code'],
    content: j['content'],
    repository: j['repository'],
    certificate: j['certificate'],
    sources: (j['sources'] as List)
        .map((s) => ExtensionSourceInfo.fromJson(Map<String, dynamic>.from(s)))
        .toList(),
  );
}

class ExtensionSourceInfo {
  final String id, name, language, url;
  final bool latest, settings;
  const ExtensionSourceInfo({
    required this.id,
    required this.name,
    required this.language,
    required this.url,
    this.latest = false,
    this.settings = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'language': language,
    'url': url,
    'latest': latest,
    'settings': settings,
  };
  factory ExtensionSourceInfo.fromJson(Map<String, dynamic> j) =>
      ExtensionSourceInfo(
        id: j['id'].toString(),
        name: j['name'],
        language: j['language'] ?? '',
        url: j['url'] ?? '',
        latest: j['latest'] == true,
        settings: j['settings'] == true,
      );
}

/// Bounded protobuf reader. BigInt preserves 64-bit source IDs on Flutter web.
class ProtoMessage {
  final Map<int, List<Object>> fields;
  ProtoMessage(this.fields);
  String text(int field) {
    final value = bytes(field);
    return value == null ? '' : utf8.decode(value);
  }

  Uint8List? bytes(int field) =>
      fields[field]?.whereType<Uint8List>().firstOrNull;
  List<Uint8List> allBytes(int field) =>
      fields[field]?.whereType<Uint8List>().toList() ?? [];
  BigInt integer(int field) =>
      fields[field]?.whereType<BigInt>().firstOrNull ?? BigInt.zero;
  double floating(int field) =>
      fields[field]?.whereType<double>().firstOrNull ?? 0;
  List<BigInt> integers(int field) {
    final result = fields[field]?.whereType<BigInt>().toList() ?? <BigInt>[];
    for (final packed in allBytes(field)) {
      var value = BigInt.zero, shift = 0;
      for (final byte in packed) {
        if (shift >= 70 || (shift == 63 && byte > 1)) {
          throw const FormatException('Invalid packed protobuf integer');
        }
        value |= BigInt.from(byte & 127) << shift;
        if (byte < 128) {
          result.add(value);
          value = BigInt.zero;
          shift = 0;
        } else {
          shift += 7;
        }
      }
      if (shift != 0) {
        throw const FormatException('Truncated packed protobuf integer');
      }
    }
    return result;
  }

  static ProtoMessage read(Uint8List input, {int maxBytes = 16 * 1024 * 1024}) {
    if (input.length > maxBytes) {
      throw const FormatException('Protobuf exceeds limit');
    }
    var offset = 0, count = 0;
    final fields = <int, List<Object>>{};
    BigInt varint() {
      var value = BigInt.zero;
      for (var shift = 0; shift < 70; shift += 7) {
        if (offset >= input.length) {
          throw const FormatException('Truncated protobuf');
        }
        final byte = input[offset++];
        if (shift == 63 && byte > 1) {
          throw const FormatException('Protobuf integer overflow');
        }
        value |= BigInt.from(byte & 127) << shift;
        if (byte < 128) return value;
      }
      throw const FormatException('Invalid protobuf integer');
    }

    while (offset < input.length) {
      if (++count > 100000) {
        throw const FormatException('Too many protobuf fields');
      }
      final tag = varint().toInt(), field = tag >> 3, wire = tag & 7;
      if (field <= 0 || field > 0x1fffffff) {
        throw const FormatException('Invalid protobuf tag');
      }
      Object? value;
      if (wire == 0) {
        value = varint();
      } else if (wire == 2 || wire == 1 || wire == 5) {
        final length = wire == 2
            ? varint().toInt()
            : wire == 1
            ? 8
            : 4;
        if (length < 0 || length > input.length - offset) {
          throw const FormatException('Truncated protobuf field');
        }
        if (wire == 2) {
          value = Uint8List.sublistView(input, offset, offset + length);
        } else if (wire == 5) {
          value = ByteData.sublistView(
            input,
            offset,
            offset + 4,
          ).getFloat32(0, Endian.little);
        }
        offset += length;
      } else {
        throw const FormatException('Unsupported protobuf wire type');
      }
      if (value != null) fields.putIfAbsent(field, () => []).add(value);
    }
    return ProtoMessage(fields);
  }
}
