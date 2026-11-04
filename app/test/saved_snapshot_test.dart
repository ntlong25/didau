import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:di_dau/api/api_client.dart';
import 'package:di_dau/features/saved/saved_snapshot.dart';

void main() {
  final snapshot = <String, dynamic>{
    'id': 't',
    'start': 'UserLocation',
    'totalMinutes': 50,
    'userLocation': {'lat': 20, 'lng': 100},
    'stops': [
      for (var i = 1; i <= 2; i++)
        {
          'order': i,
          'stayMinutes': 20,
          'name': 'private provider name',
          'place': {'id': 'osm:node/$i'},
          'narration': [],
        },
    ],
    'legs': [
      {
        'fromOrder': null,
        'toOrder': 1,
        'minutes': 5,
        'directionsUrl': 'private origin',
      },
      {'fromOrder': 1, 'toOrder': 2, 'minutes': 5, 'mode': 'Walk'},
    ],
  };
  test(
    'Saved tours discard personal origin and unrecognized provider fields',
    () {
      final saved = stripPlacesContent('tour', snapshot);
      expect(saved['start'], 'FirstStop');
      expect(saved['totalMinutes'], 45);
      expect((saved['legs'] as List).length, 1);
      expect(jsonEncode(saved), isNot(contains('private')));
      expect(saved.containsKey('userLocation'), false);
    },
  );
  test('Hydration restores directions after coordinates expire', () async {
    final api = ApiClient(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'id': r.url.pathSegments.last,
            'name': 'Stop',
            'location': {'lat': 21.03, 'lng': 105.85},
          }),
          200,
        ),
      ),
    );
    addTearDown(api.dispose);
    final saved = stripPlacesContent('tour', snapshot);
    final hydrated = await hydrate('tour', saved, api);
    expect(
      hydrated['legs'][0]['directionsUrl'],
      contains('travelmode=walking'),
    );
    expect(hydrated['legs'][0]['directionsUrl'], contains('origin=21.03'));
  });
}
