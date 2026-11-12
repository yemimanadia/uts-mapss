import 'package:flutter_test/flutter_test.dart';

import 'package:uts_maps_23053009_yemima_nadia_paparang/main.dart';

void main() {
  testWidgets('Smart logistics app shows routing dashboard', (tester) async {
    await tester.pumpWidget(const SmartLogisticsApp());

    expect(find.text('Express Route Logistics'), findsOneWidget);
    expect(find.text('Panel Analisis Rute & Efisiensi'), findsOneWidget);
    expect(find.text('Rute Aktif:'), findsOneWidget);
  });
}
