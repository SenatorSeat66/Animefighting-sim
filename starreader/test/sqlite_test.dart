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
    expect(await first.db!.getVersion(), 2);
    await first.save({
      'settings': {'theme': 'amoled'},
    });
    await first.writeCache('repository', '{"name":"fixture"}');
    await first.putPage('chapter', 0, Uint8List.fromList([1, 2, 3, 4]));
    await first.db!.close();
    final second = Storage();
    await second.open();
    expect((await second.load())['settings']['theme'], 'amoled');
    expect(await second.page('chapter', 0), [1, 2, 3, 4]);
    expect(await second.bytesUsed(), 4);
    expect(await second.readCache('repository'), '{"name":"fixture"}');
    await second.deletePages('chapter');
    expect(await second.page('chapter', 0), isNull);
    expect(await second.bytesUsed(), 0);
    await second.db!.close();
    await dir.delete(recursive: true);
  });
  test(
    'upgrades a real v1 database without losing offline pages or settings',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp(
        'starreader-migration-',
      );
      await databaseFactory.setDatabasesPath(dir.path);
      final old = await openDatabase(
        '${dir.path}/starreader.db',
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE state (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE pages (chapter TEXT NOT NULL, page INTEGER NOT NULL, bytes BLOB NOT NULL, PRIMARY KEY(chapter,page))',
          );
        },
      );
      await old.insert('state', {
        'id': 1,
        'json': '{"settings":{"theme":"light"}}',
      });
      await old.insert('pages', {
        'chapter': 'old',
        'page': 2,
        'bytes': Uint8List.fromList([1, 2, 3]),
      });
      await old.close();
      final next = Storage();
      await next.open();
      expect(await next.db!.getVersion(), 2);
      expect((await next.load())['settings']['theme'], 'light');
      expect(await next.page('old', 2), [1, 2, 3]);
      await next.writeCache('new', 'kept');
      expect(await next.readCache('new'), 'kept');
      await next.db!.close();
      await dir.delete(recursive: true);
    },
  );
}
