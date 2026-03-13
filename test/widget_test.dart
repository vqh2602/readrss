import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readrss/src/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders RSS reader shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ReadRssApp());
    await tester.pump();

    expect(find.text('ReadRSS'), findsOneWidget);
    expect(find.text('Chua co nguon RSS nao'), findsOneWidget);
    expect(find.textContaining('Them nguon'), findsWidgets);
  });
}
