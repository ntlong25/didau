import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:di_dau/features/saved/saved_store.dart';

const _loc = {'lat': 21.0288, 'lng': 105.8525};
final _fullPlace = {
  'id': 'p1',
  'name': 'Quán',
  'address': '1 Hàng Bạc',
  'location': _loc,
  'priceLevel': 'Moderate',
  'rating': 4.5,
  'mapsUri': 'https://maps.google.com/?cid=1',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Stores items, overwrites duplicate ids, sorts newest first and removes',
    () async {
      final store = SavedStore();
      final now = DateTime.utc(2026, 11, 4);
      await store.save('place', 'p1', 'A', {
        'id': 'p1',
      }, at: DateTime.utc(2026, 11, 1));
      await store.save('tour', 't1', 'Tour', {
        'id': 't1',
        'stops': [],
      }, at: DateTime.utc(2026, 11, 2));
      await store.save('place', 'p1', 'B', {
        'id': 'p1',
      }, at: DateTime.utc(2026, 11, 3));
      final items = await SavedStore().list(now: now);
      expect(items.length, 2);
      expect(items.first.id, 'place:p1');
      expect(items.first.title, 'Địa điểm đã lưu');
      await store.remove('place:p1');
      expect((await store.list(now: now)).single.id, 'tour:t1');
    },
  );
  test('Only place id and coordinates are persisted for places', () async {
    await SavedStore().save('place', 'p1', 'Địa điểm đã lưu', _fullPlace);
    final raw = (await SharedPreferences.getInstance()).getString(
      SavedStore.key,
    )!;
    final snapshot = (jsonDecode(raw) as List).single['snapshot'] as Map;
    expect(snapshot.keys.toSet(), {'id', 'location'});
  });
  test('Tour stops keep narration but drop Places content', () async {
    await SavedStore().save('tour', 't1', 'Tour Hà Nội', {
      'id': 't1',
      'cityId': 'hanoi',
      'stops': [
        {
          'order': 1,
          'stayMinutes': 30,
          'place': _fullPlace,
          'narration': [
            {'kind': 'History', 'text': 'x', 'sources': []},
          ],
        },
      ],
      'legs': [],
    });
    final raw = (await SharedPreferences.getInstance()).getString(
      SavedStore.key,
    )!;
    final stop =
        ((jsonDecode(raw) as List).single['snapshot']['stops'] as List).single;
    expect((stop['place'] as Map).keys.toSet(), {'id', 'location'});
    expect(stop['narration'], isNotEmpty);
    expect(raw.contains('Hàng Bạc'), isFalse);
  });
  test('Coordinates are purged after 30 days and old snapshots compacted', () async {
    SharedPreferences.setMockInitialValues({
      SavedStore.key: jsonEncode([
        {
          'id': 'place:p1',
          'kind': 'place',
          'title': 'Quán',
          'savedAt': '2026-09-01T00:00:00.000Z',
          'snapshot': _fullPlace,
        },
      ]),
    });
    final store = SavedStore();
    final item = (await store.list(now: DateTime.utc(2026, 11, 4))).single;
    expect(item.snapshot.keys.toSet(), {'id'});
    await store.compact();
    final raw = (await SharedPreferences.getInstance()).getString(
      SavedStore.key,
    )!;
    expect(raw.contains('Hàng Bạc'), isFalse);
  });
  test('Corrupt persisted value does not crash', () async {
    SharedPreferences.setMockInitialValues({
      'saved_items_v1': '[{"broken":true}]',
    });
    expect(await SavedStore().list(), isEmpty);
  });
  test('Concurrent saves do not lose an item', () async {
    final store = SavedStore();
    await Future.wait([
      store.save('place', 'a', 'A', {'id': 'a'}),
      store.save('place', 'b', 'B', {'id': 'b'}),
    ]);
    expect((await store.list()).length, 2);
  });
}
