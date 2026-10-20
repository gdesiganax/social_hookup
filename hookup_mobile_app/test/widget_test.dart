import 'package:flutter_test/flutter_test.dart';
import 'package:testing/main.dart';

void main() {
  testWidgets('shows guest discovery home', (WidgetTester tester) async {
    await tester.pumpWidget(const HookupApp());

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Who would you like to meet?'), findsOneWidget);
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);
  });
}
