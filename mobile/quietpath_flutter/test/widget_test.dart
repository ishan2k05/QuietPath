import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quietpath_flutter/main.dart';

void main() {
  testWidgets('QuietPath app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: QuietPathApp()));
    await tester.pumpAndSettle();

    // Verify that Welcome to QuietPath is rendered on initial onboarding screen
    expect(find.text('Welcome to QuietPath'), findsOneWidget);
    expect(find.text('Noise Sensitivity'), findsOneWidget);
    expect(find.text('Save & Start Exploring →'), findsOneWidget);
  });
}
