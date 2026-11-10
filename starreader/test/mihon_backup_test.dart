import 'package:starreader/core/library_updates.dart';

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starreader/core/library.dart';
import 'package:starreader/core/mihon_backup.dart';
import 'package:starreader/core/extension_identity.dart';

import 'extension_test.dart' show blob, number, text, varint;
import 'widget_test.dart' show MemoryStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LibraryUpdates.channel, (call) async => null);
  test('imports standard Mihon gzip protobuf without trusting repositories or credentials', () async {
    final source = BigInt.parse('2499283573021220255');
    final float = ByteData(4)..setFloat32(0, 12.5, Endian.little);
    final chapter = [
      ...text(1, '/chapter'),
      ...text(2, 'Twelve and a half'),
      ...number(4, BigInt.one),
      ...number(5, BigInt.one),
      ...number(6, BigInt.from(8)),
      ...varint(BigInt.from((9 << 3) | 5)),
      ...float.buffer.asUint8List(),
      ...blob(13, '{}'.codeUnits),
    ];
    final manga = [
      ...number(1, source),
      ...text(2, '/manga'),
      ...text(3, 'Imported title'),
      ...text(5, 'Author'),
      ...blob(16, chapter),
      ...blob(17, varint(BigInt.from(7))),
      ...blob(104, [
        ...text(1, '/chapter'),
        ...number(2, BigInt.from(1794355200000)),
      ]),
    ];
    final root = [
      ...blob(1, manga),
      ...blob(2, [...text(1, 'My collection'), ...number(3, BigInt.from(7))]),
      ...blob(105, text(1, 'private credential fixture')),
      ...blob(106, text(1, 'untrusted repository fixture')),
    ];
    final imported = MihonImport.parse(
      Uint8List.fromList(GZipEncoder().encodeBytes(root)),
    );
    expect(imported.titles, 1);
    expect(imported.chapters, 1);
    expect(imported.data.containsKey('repositories'), isFalse);
    expect(imported.starReaderBackup, isNot(contains('private credential')));
    final library = Library(MemoryStorage());
    await library.init();
    await library.restore(imported.starReaderBackup);
    final title = library.saved.single;
    expect(title.source, 'ext:2499283573021220255');
    final c = library.chapters(title.id).single;
    expect(c.number, '12.5');
    expect(library.progress(c.id)['page'], 8);
    expect(library.progress(c.id)['complete'], true);
    expect(library.section('library')[title.id]['category'], 'My collection');
    expect(library.section('bookmarks')['${c.id}:8'], true);
    expect(library.section('history')[title.id]['chapter']['id'], c.id);
  });
  test(
    'malformed and local-only imports never produce a replacement library',
    () {
      expect(
        () => MihonImport.parse(Uint8List.fromList([10, 99])),
        throwsFormatException,
      );
      final local = [
        ...blob(1, [
          ...number(1, BigInt.zero),
          ...text(2, '/local'),
          ...text(3, 'Local'),
        ]),
      ];
      expect(
        () => MihonImport.parse(Uint8List.fromList(local)),
        throwsFormatException,
      );
    },
  );
  test('two titles sharing a chapter URL retain separate progress and native-compatible identities', () {
    final root = <int>[];
    for (var i = 1; i <= 2; i++) {
      root.addAll(
        blob(1, [
          ...number(1, BigInt.from(42)),
          ...text(2, '/manga-$i'),
          ...text(3, 'Title $i'),
          ...blob(16, [
            ...text(1, '/chapter'),
            ...text(2, 'One'),
            ...number(6, BigInt.from(i)),
          ]),
        ]),
      );
    }
    final imported = MihonImport.parse(Uint8List.fromList(root));
    final chapters = (imported.data['chapters'] as Map).values
        .expand((v) => v as List)
        .toList();
    expect(chapters.map((c) => c['id']).toSet().length, 2);
    expect(chapters.first['id'], 'ext:42:L21hbmdhLTE:L2NoYXB0ZXI');
    expect(
      chapters.first['id'],
      ExtensionIdentity.chapter(
        ExtensionIdentity.manga('42', '/manga-1'),
        '/chapter',
      ),
    );
    expect((imported.data['progress'] as Map).length, 2);
    expect(imported.data['progress'][chapters[0]['id']]['page'], 1);
    expect(imported.data['progress'][chapters[1]['id']]['page'], 2);
  });
}
