import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starreader/core/storage.dart';

void main() {
  test('SQLite schema, metadata and page blobs survive close/reopen', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('starreader-db-');
    await databaseFactory.setDatabasesPath(dir.path);
    final first = Storage();
    await first.open();
    expect(await first.db!.getVersion(), 1);
    await first.save({
      'settings': {'theme': 'amoled'},
    });
    await first.putPage('chapter', 0, Uint8List.fromList([1, 2, 3, 4]));
    await first.db!.close();
    final second = Storage();
    await second.open();
    expect((await second.load())['settings']['theme'], 'amoled');
    expect(await second.page('chapter', 0), [1, 2, 3, 4]);
    expect(await second.bytesUsed(), 4);
    await second.deletePages('chapter');
    expect(await second.page('chapter', 0), isNull);
    expect(await second.bytesUsed(), 0);
    await second.db!.close();
    await dir.delete(recursive: true);
  });
}
