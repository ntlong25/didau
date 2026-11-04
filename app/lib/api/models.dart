typedef Json = Map<String, dynamic>;

class GeoPoint {
  final double lat, lng;
  const GeoPoint(this.lat, this.lng);
  factory GeoPoint.fromJson(Json j) =>
      GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
  Json toJson() => {'lat': lat, 'lng': lng};
}

class City {
  final String id, name;
  final GeoPoint center;
  City.fromJson(Json j)
    : id = j['id'],
      name = j['name'],
      center = GeoPoint.fromJson(j['center']);
}

const cityNames = {
  'hanoi': 'Hà Nội',
  'hcmc': 'TP. Hồ Chí Minh',
  'dalat': 'Đà Lạt',
  'nhatrang': 'Nha Trang',
  'danang': 'Đà Nẵng',
};

class Place {
  final Json json;
  Place.fromJson(this.json);
  String get id => json['id'];
  // Saved items keep only id/location (Places terms), so details may be missing until re-fetched.
  bool get hasDetails => json['name'] is String;
  String get name => json['name'] ?? 'Cần kết nối mạng để xem tên';
  String? get address => json['address'];
  GeoPoint? get location =>
      json['location'] == null ? null : GeoPoint.fromJson(json['location']);
  String get mapsUri =>
      json['mapsUri'] ??
      (id.startsWith('osm:')
          ? 'https://www.openstreetmap.org/${id.substring(4)}'
          : location == null
          ? 'https://www.google.com/maps'
          : 'https://www.google.com/maps/search/?api=1&query=${location!.lat},${location!.lng}');
  String? get price => const {
    'Inexpensive': 'Rẻ',
    'Moderate': 'Vừa',
    'Expensive': 'Cao',
    'VeryExpensive': 'Rất cao',
  }[json['priceLevel']];
  bool? get openNow => json['openNow'];
  String? get nextOpenAt => json['nextOpenAt'];
  List<String>? get openingHours =>
      (json['openingHoursText'] as List?)?.cast<String>();
}

class Suggestion {
  final Place place;
  final String reason;
  final int distanceMeters;
  Suggestion.fromJson(Json j)
    : place = Place.fromJson(j['place']),
      reason = j['reason'],
      distanceMeters = j['distanceMeters'];
}

class SuggestionResult {
  final String cityId;
  final List<Suggestion> items;
  final bool canExpandRadius;
  SuggestionResult.fromJson(Json j)
    : cityId = j['cityId'],
      items = (j['items'] as List).map((e) => Suggestion.fromJson(e)).toList(),
      canExpandRadius = j['canExpandRadius'];
}

class Tour {
  final Json json;
  Tour.fromJson(this.json);
  String get id => json['id'];
  String get cityId => json['cityId'];
  int get totalMinutes => json['totalMinutes'];
  int get variant => json['variant'];
  List<Json> get stops => (json['stops'] as List).cast<Json>();
  List<Json> get legs => (json['legs'] as List).cast<Json>();
}
