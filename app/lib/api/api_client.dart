import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _http;
  final String baseUrl;
  ApiClient({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:5000/api',
    ),
  }) : _http = client ?? http.Client();
  Future<dynamic> _send(String path, [Json? body]) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response =
          await (body == null
                  ? _http.get(uri)
                  : _http.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 22));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 400) {
        throw ApiException(
          decoded is Map
              ? decoded['message'] ?? 'Không thể lấy dữ liệu.'
              : 'Không thể lấy dữ liệu.',
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Yêu cầu mất quá nhiều thời gian. Vui lòng thử lại.',
      );
    } catch (_) {
      throw const ApiException(
        'Không thể kết nối. Kiểm tra mạng rồi thử lại; bạn vẫn có thể xem mục Đã lưu.',
      );
    }
  }

  Future<List<City>> cities() async =>
      (await _send('/cities') as List).map((e) => City.fromJson(e)).toList();
  Future<List<Json>> geocode(String city, String query) async =>
      (await _send(
                '/geocode?cityId=${Uri.encodeQueryComponent(city)}&q=${Uri.encodeQueryComponent(query)}',
              )
              as List)
          .cast<Json>();
  Future<List<Json>> areas(String city, [String query = '']) async =>
      (await _send(
                '/cities/${Uri.encodeComponent(city)}/areas?q=${Uri.encodeQueryComponent(query)}',
              )
              as List)
          .cast<Json>();
  Future<SuggestionResult> suggestions(
    GeoPoint point,
    String need,
    int radius,
  ) async => SuggestionResult.fromJson(
    await _send('/suggestions', {
      'location': point.toJson(),
      'need': need,
      'radiusMeters': radius,
    }),
  );
  Future<Place> place(String id) async =>
      Place.fromJson(await _send('/places/${Uri.encodeComponent(id)}'));
  Future<Tour> tour(Json request) async =>
      Tour.fromJson(await _send('/tours', request));
  void dispose() => _http.close();
}
