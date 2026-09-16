import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quietpath_flutter/main.dart';

void main() {
  testWidgets('QuietPath app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: QuietPathApp()));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify QuietPath brand name renders on initial splash
    expect(find.text('QuietPath'), findsOneWidget);
    expect(find.text('Navigate at your own pace'), findsOneWidget);

    // Advance time past splash animation and navigation
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
