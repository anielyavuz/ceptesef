import 'package:flutter_test/flutter_test.dart';

import 'package:ceptesef/app.dart';

void main() {
  testWidgets('Uygulama başarıyla yüklenir', (WidgetTester tester) async {
    await tester.pumpWidget(const CepteSefApp());
    await tester.pumpAndSettle();
  });
}
