import 'dart:convert';

import 'package:di_dau/api/api_client.dart';
import 'package:di_dau/features/suggestions/suggestions_screen.dart';
import 'package:di_dau/features/tours/tour_form_screen.dart';
import 'package:di_dau/theme/app_theme.dart';
import 'package:di_dau/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient fixtureApi() => ApiClient(
  baseUrl: 'http://fixture/api',
  client: MockClient((req) async {
    final body = req.url.path.endsWith('/cities')
        ? [
            {
              'id': 'hanoi',
              'name': 'Hà Nội',
              'center': {'lat': 21.0, 'lng': 105.8},
            },
          ]
        : <Object>[];
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  }),
);

Widget host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: buildAppTheme(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  for (final (w, h) in [(320.0, 640.0), (375.0, 812.0), (414.0, 896.0)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('UI-01 suggestions grid fits at ${w}x$h, text scale $scale', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(SuggestionsScreen(api: fixtureApi()), textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final tiles = find.byType(ChoiceTile);
        final rows = {for (var i = 0; i < 4; i++) tester.getTopLeft(tiles.at(i)).dy};
        // The grid sits inside 20px page padding on each side.
        expect(rows.length, w - 40 < 340 ? 2 : 1);
      });
    }
  }

  testWidgets('UI-12 multi-select ChoiceTile exposes toggled state and label', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(TourFormScreen(api: fixtureApi())));
    await tester.pumpAndSettle();
    final history = find.byWidgetPredicate((w) => w is ChoiceTile && w.label == 'Lịch sử');
    expect(
      tester.getSemantics(history),
      isSemantics(label: 'Lịch sử, đã chọn', isButton: true, hasToggledState: true, isToggled: true),
    );
    semantics.dispose();
  });
}
