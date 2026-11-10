import 'dart:typed_data';

/// Compressed page bytes only. Flutter separately bounds its decoded image cache.
class PageCache {
  final int maximumBytes;
  PageCache({this.maximumBytes = 24 * 1024 * 1024});
  final _entries = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  int bytes = 0;
  int _generation = 0;
  Future<Uint8List> get(String key, Future<Uint8List> Function() load) {
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return Future.value(cached);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    final generation = _generation;
    late Future<Uint8List> future;
    future = load()
        .then((data) {
          if (generation == _generation && data.length <= maximumBytes) {
            while (bytes + data.length > maximumBytes && _entries.isNotEmpty) {
              bytes -= _entries.remove(_entries.keys.first)!.length;
            }
            _entries[key] = data;
            bytes += data.length;
          }
          return data;
        })
        .whenComplete(() {
          if (identical(_pending[key], future)) _pending.remove(key);
        });
    _pending[key] = future;
    return future;
  }

  void clear() {
    _generation++;
    _entries.clear();
    _pending.clear();
    bytes = 0;
  }
}
