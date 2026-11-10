import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class Storage {
  Database? db;
  SharedPreferences? prefs;
  final Map<String, Uint8List> browserPages = {};
  Future<void> open() async {
    if (kIsWeb) {
      prefs = await SharedPreferences.getInstance();
      return;
    }
    db = await openDatabase(
      p.join(await getDatabasesPath(), 'starreader.db'),
      version: 2,
      onUpgrade: (d, old, next) async {
        if (old < 2) {
          await d.execute(
            'CREATE TABLE cache (key TEXT PRIMARY KEY, json TEXT NOT NULL)',
          );
        }
      },
      onCreate: (d, v) async {
        await d.execute(
          'CREATE TABLE cache (key TEXT PRIMARY KEY, json TEXT NOT NULL)',
        );
        await d.execute(
          'CREATE TABLE state (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
        );
        await d.execute(
          'CREATE TABLE pages (chapter TEXT NOT NULL, page INTEGER NOT NULL, bytes BLOB NOT NULL, PRIMARY KEY(chapter,page))',
        );
      },
    );
  }

  final Map<String, String> _memoryCache = {};
  Future<String?> readCache(String key) async {
    if (kIsWeb) return prefs?.getString('cache.$key');
    if (db == null) return _memoryCache[key];
    return (await db!.query(
          'cache',
          where: 'key = ?',
          whereArgs: [key],
        )).firstOrNull?['json']
        as String?;
  }

  Future<void> writeCache(String key, String value) async {
    if (kIsWeb) {
      await prefs!.setString('cache.$key', value);
    } else if (db == null) {
      _memoryCache[key] = value;
    } else {
      await db!.insert('cache', {
        'key': key,
        'json': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<String, dynamic>> load() async {
    final rows = await db?.query('state', where: 'id = 1');
    final raw = kIsWeb
        ? prefs?.getString('state')
        : rows?.firstOrNull?['json'] as String?;
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> save(Map<String, dynamic> state) async {
    final raw = jsonEncode(state);
    if (kIsWeb) {
      await prefs!.setString('state', raw);
    } else {
      await db!.insert('state', {
        'id': 1,
        'json': raw,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> putPage(String chapter, int page, Uint8List bytes) async {
    if (kIsWeb) {
      browserPages['$chapter/$page'] = bytes;
    } else {
      await db!.insert('pages', {
        'chapter': chapter,
        'page': page,
        'bytes': bytes,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Uint8List?> page(String chapter, int page) async {
    if (kIsWeb) {
      return browserPages['$chapter/$page'];
    }
    final row = await db!.query(
      'pages',
      columns: ['bytes'],
      where: 'chapter = ? AND page = ?',
      whereArgs: [chapter, page],
    );
    return row.firstOrNull?['bytes'] as Uint8List?;
  }

  Future<void> deletePages(String chapter) async {
    if (kIsWeb) {
      browserPages.removeWhere((k, v) => k.startsWith('$chapter/'));
    } else {
      await db!.delete('pages', where: 'chapter = ?', whereArgs: [chapter]);
    }
  }

  Future<int> bytesUsed() async => kIsWeb
      ? browserPages.values.fold<int>(0, (n, b) => n + b.length)
      : (Sqflite.firstIntValue(
              await db!.rawQuery(
                'SELECT COALESCE(SUM(length(bytes)),0) FROM pages',
              ),
            ) ??
            0);
}
