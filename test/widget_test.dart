import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readrss/src/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders RSS reader shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ReadRssApp());
    await tester.pump();

    expect(find.text('Recent Feeds'), findsWidgets);
    expect(find.textContaining('Thêm nguồn'), findsWidgets);
    expect(find.byIcon(Icons.dashboard_customize_outlined), findsOneWidget);
  });
}
