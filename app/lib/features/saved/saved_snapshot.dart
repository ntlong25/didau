import '../../api/api_client.dart';
import '../../api/models.dart';

/// Google Maps Platform Service Specific Terms 5.4: only place IDs may be stored
/// indefinitely and lat/lng for at most 30 days. Everything else from Places is
/// dropped before saving and re-fetched from the API when the item is opened.
const coordinateRetention = Duration(days: 30);

Json _stripPlace(Json place) => {
  'id': place['id'],
  if (place['location'] != null) 'location': place['location'],
};

/// Keeps only data the device may store: place IDs, coordinates, and our own
/// tour data (order, stay time, legs, Wikipedia-sourced narration).
Json stripPlacesContent(String kind, Json snapshot) {
  if (kind == 'place') return _stripPlace(snapshot);
  return {
    ...snapshot,
    'stops': [
      for (final stop in (snapshot['stops'] as List).cast<Json>())
        {...stop, 'place': _stripPlace(Map<String, dynamic>.from(stop['place']))},
    ],
  };
}

/// Removes coordinates (and URLs embedding them) once they pass the 30-day limit.
Json purgeExpiredCoordinates(String kind, Json snapshot, DateTime savedAt, DateTime now) {
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
  return {
    ...snapshot,
    'stops': [
      for (var i = 0; i < stops.length; i++) {...stops[i], 'place': places[i].json},
    ],
  };
}
