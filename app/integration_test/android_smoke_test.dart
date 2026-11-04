import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:di_dau/main.dart' as app;
import 'package:di_dau/features/saved/saved_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android HTTP, suggestions, tour, native storage and offline', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SavedStore.key);
    final place = <String, dynamic>{
      'id': 'osm:node/42',
      'name': 'Điểm kiểm thử Android',
      'address': 'Địa chỉ fixture',
      'location': {'lat': 21.0288, 'lng': 105.852},
      'mapsUri': 'https://www.openstreetmap.org/node/42',
    };
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 5000);
    server.listen((request) async {
      await request.drain<void>();
      final path = request.uri.path;
      final Object body;
      if (path.endsWith('/cities')) {
        body = [
          {'id': 'hanoi', 'name': 'Hà Nội', 'center': place['location']},
        ];
      } else if (path.endsWith('/geocode')) {
        body = [
          {'label': place['name'], 'location': place['location']},
        ];
      } else if (path.endsWith('/areas')) {
        body = [place];
      } else if (path.contains('/places/')) {
        body = place;
      } else if (path.endsWith('/suggestions')) {
        body = {
          'cityId': 'hanoi',
          'canExpandRadius': true,
          'items': [
            {
              'place': place,
              'reason': 'Dữ liệu fixture',
              'distanceMeters': 100,
            },
          ],
        };
      } else {
        body = {
          'id': 'android-tour',
          'cityId': 'hanoi',
          'variant': 0,
          'start': 'FirstStop',
          'totalMinutes': 20,
          'legs': [],
          'stops': [
            {
              'order': 1,
              'place': place,
              'stayMinutes': 20,
              'narration': [
                {
                  'kind': 'History',
                  'text': 'Lời dẫn offline Android.',
                  'sources': [],
                },
              ],
            },
          ],
        };
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    Future<void> tap(String text) async {
      final target = find.text(text).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    app.main();
    await tester.pumpAndSettle();
    // Runner grants foreground permission and injects a Hanoi GPS fix via adb.
    await tap('Dùng vị trí hiện tại');
    expect(
      find.text('Đã chọn: Vị trí hiện tại'),
      findsOneWidget,
      reason:
          'Permission: ${await Geolocator.checkPermission()}, service: ${await Geolocator.isLocationServiceEnabled()}, UI: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ')}',
    );
    await tester.enterText(find.byType(TextField).first, 'Hồ Hoàn Kiếm');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tap('Tìm khu vực');
    await tap('Điểm kiểm thử Android');
    await tap('Gợi ý cho tôi');
    expect(find.text('Đã chọn: Điểm kiểm thử Android'), findsOneWidget);
    await tap('Điểm kiểm thử Android');
    await tap('Lưu');
    expect(find.text('Đã lưu'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tap('Tour');
    await tap('Tạo tour');
    await tap('Lưu');
    expect((await SavedStore().list()).length, 2);
    expect(prefs.getString(SavedStore.key), isNot(contains('Địa chỉ fixture')));
    await server.close(force: true);
    // Recreate app widgets while retaining Android SharedPreferences.
    await tester.pumpWidget(const SizedBox.shrink());
    app.main();
    await tester.pumpAndSettle();
    await tap('Đã lưu');
    await tap('Tour Hà Nội');
    expect(find.text('1 điểm dừng • 20 phút'), findsOneWidget);
    await tap('Cần kết nối mạng để xem tên');
    expect(find.text('Lời dẫn offline Android.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tap('Địa điểm đã lưu');
    await tap('Đã lưu');
    expect(find.text('Lưu'), findsOneWidget);
    expect((await SavedStore().list()).length, 1);
    expect(tester.takeException(), isNull);
  });
}
