import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/models.dart';
import 'saved_snapshot.dart';

class SavedItem {
  final String id, kind, title;
  final DateTime savedAt;
  final Json snapshot;
  SavedItem(this.id, this.kind, this.title, this.savedAt, this.snapshot);
  factory SavedItem.fromJson(Json j) {
    final item = SavedItem(
      j['id'] as String,
      j['kind'] as String,
      j['title'] as String,
      DateTime.parse(j['savedAt']),
      Map<String, dynamic>.from(j['snapshot']),
    );
    if (!['tour', 'place'].contains(item.kind) ||
        !item.id.startsWith('${item.kind}:') ||
        item.snapshot['id'] is! String) {
      throw const FormatException('Invalid saved item');
    }
    return item;
  }
  Json toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'savedAt': savedAt.toIso8601String(),
    'snapshot': snapshot,
  };
}

class SavedStore {
  static const key = 'saved_items_v1';
  // Serialize mutations across screen instances so simultaneous saves do not overwrite each other.
  static Future<void> _pending = Future.value();
  Future<List<SavedItem>> list({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      final at = now ?? DateTime.now().toUtc();
      final items = (jsonDecode(raw) as List)
          .map((j) => SavedItem.fromJson(Map<String, dynamic>.from(j)))
          .map(
            (i) => SavedItem(
              i.id,
              i.kind,
              // Titles are rebuilt so no Places name stays on the device.
              i.kind == 'place'
                  ? 'Địa điểm đã lưu'
                  : 'Tour ${cityNames[i.snapshot['cityId']] ?? ''}'.trim(),
              i.savedAt,
              // Older data (incl. v1 full snapshots) is re-stripped on read.
              purgeExpiredCoordinates(
                i.kind,
                stripPlacesContent(i.kind, i.snapshot),
                i.savedAt,
                at,
              ),
            ),
          )
          .toList();
      items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _mutate(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> _write(List<SavedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      key,
      jsonEncode(items.map((i) => i.toJson()).toList()),
    )) {
      throw Exception('Không lưu được dữ liệu trên thiết bị.');
    }
  }

  Future<void> save(
    String kind,
    String id,
    String title,
    Json snapshot, {
    DateTime? at,
  }) => _mutate(() async {
    final fullId = '$kind:$id';
    final items = await list();
    items.removeWhere((i) => i.id == fullId);
    items.add(
      SavedItem(
        fullId,
        kind,
        title,
        at ?? DateTime.now().toUtc(),
        stripPlacesContent(kind, jsonDecode(jsonEncode(snapshot))),
      ),
    );
    await _write(items);
  });
  /// Rewrites storage so previously saved full snapshots and expired coordinates are removed.
  Future<void> compact() => _mutate(() async => _write(await list()));
  Future<void> remove(String id) => _mutate(() async {
    final items = await list();
    items.removeWhere((i) => i.id == id);
    await _write(items);
  });
}
