import 'package:flutter_test/flutter_test.dart';
import 'package:di_dau/main.dart';

void main() {
  testWidgets('Three Vietnamese navigation destinations', (tester) async {
    await tester.pumpWidget(const DiDauApp());
    expect(find.text('Đi Đâu'), findsOneWidget);
    expect(find.text('Tour'), findsOneWidget);
    expect(find.text('Đã lưu'), findsOneWidget);
  });
}
