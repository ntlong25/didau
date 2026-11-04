import '../../api/api_client.dart';
import '../../api/models.dart';

/// App retention policy: keep IDs and tour narration; refresh provider details
/// on opening. Coordinates expire after 30 days, including legacy snapshots.
const coordinateRetention = Duration(days: 30);

Json _stripPlace(Json place) => {
  'id': place['id'],
  if (place['location'] != null) 'location': place['location'],
};

/// Keeps only data the device may store: place IDs, coordinates, and our own
/// tour data (order, stay time, legs, Wikipedia-sourced narration).
Json stripPlacesContent(String kind, Json snapshot) {
  if (kind == 'place') return _stripPlace(snapshot);
  final legs = (snapshot['legs'] as List? ?? const []).cast<Json>();
  final originMinutes = legs
      .where((l) => l['fromOrder'] == null)
      .fold<int>(0, (sum, l) => sum + (l['minutes'] as int? ?? 0));
  return {
    for (final key in [
      'id',
      'cityId',
      'areaPlaceId',
      'duration',
      'interests',
      'variant',
      'generatedAt',
    ])
      if (snapshot.containsKey(key)) key: snapshot[key],
    'start': 'FirstStop',
    if (snapshot['totalMinutes'] is int)
      'totalMinutes': (snapshot['totalMinutes'] as int) - originMinutes,
    'stops': [
      for (final stop in (snapshot['stops'] as List).cast<Json>())
        {
          for (final key in ['order', 'stayMinutes', 'narration'])
            if (stop.containsKey(key)) key: stop[key],
          'place': _stripPlace(Map<String, dynamic>.from(stop['place'])),
        },
    ],
    'legs': [
      for (final leg in legs.where((l) => l['fromOrder'] != null))
        {
          for (final key in [
            'fromOrder',
            'toOrder',
            'mode',
            'minutes',
            'distanceMeters',
            'directionsUrl',
          ])
            if (leg.containsKey(key)) key: leg[key],
        },
    ],
  };
}

/// Removes coordinates (and URLs embedding them) once they pass the 30-day limit.
Json purgeExpiredCoordinates(
  String kind,
  Json snapshot,
  DateTime savedAt,
  DateTime now,
) {
  if (now.difference(savedAt) < coordinateRetention) return snapshot;
  Json purge(Json place) => {...place}..remove('location');
  if (kind == 'place') return purge(snapshot);
  return {
    ...snapshot,
    'stops': [
      for (final stop in (snapshot['stops'] as List).cast<Json>())
        {...stop, 'place': purge(Map<String, dynamic>.from(stop['place']))},
    ],
    'legs': [
      for (final leg in (snapshot['legs'] as List? ?? const []).cast<Json>())
        {...leg}..remove('directionsUrl'),
    ],
  };
}

/// Re-fetches live place details for a saved item. Throws [ApiException] when offline.
Future<Json> hydrate(String kind, Json snapshot, ApiClient api) async {
  if (kind == 'place') return (await api.place(snapshot['id'])).json;
  final stops = (snapshot['stops'] as List).cast<Json>();
  final places = await Future.wait(
    stops.map((s) => api.place(s['place']['id'] as String)),
  );
  final locations = {
    for (var i = 0; i < stops.length; i++)
      stops[i]['order']: places[i].json['location'],
  };
  Json refreshLeg(Json leg) {
    final result = {...leg}..remove('directionsUrl');
    final from = locations[leg['fromOrder']];
    final to = locations[leg['toOrder']];
    if (from != null && to != null) {
      result['directionsUrl'] = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': '${from['lat']},${from['lng']}',
        'destination': '${to['lat']},${to['lng']}',
        'travelmode': leg['mode'] == 'Walk' ? 'walking' : 'driving',
      }).toString();
    }
    return result;
  }

  return {
    ...snapshot,
    'legs': (snapshot['legs'] as List? ?? const [])
        .cast<Json>()
        .map(refreshLeg)
        .toList(),
    'stops': [
      for (var i = 0; i < stops.length; i++)
        {...stops[i], 'place': places[i].json},
    ],
  };
}
