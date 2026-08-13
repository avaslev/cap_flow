import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/feature/tool_detail/presentation/tool_detail_screen.dart';

void main() {
  group('ToolDetailScreen', () {
    testWidgets('displays loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolDetailScreen(
            accountId: 'test-account',
            toolId: 'money-test',
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays asset details when loaded', (WidgetTester tester) async {
      // Mock the repository response
      await tester.pumpWidget(
        MaterialApp(
          home: ToolDetailScreen(
            accountId: 'test-account',
            toolId: 'money-test',
          ),
        ),
      );

      // Wait for the widget to rebuild after loading
      await tester.pumpAndSettle();

      // Check if the asset name is displayed
      expect(find.text('Main Checking Account'), findsOneWidget);

      // Check if the asset type is displayed
      expect(find.text('Cash'), findsOneWidget);

      // Check if the value is displayed in the MoneyAssetTab
      expect(find.text('Main Checking Account'), findsOneWidget);

      // Check for money balance in MoneyAssetTab
      expect(find.text('\$10000.00'), findsAtLeastNWidgets(1));
    });
  });
}