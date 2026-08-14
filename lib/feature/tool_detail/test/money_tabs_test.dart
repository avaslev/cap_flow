import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/feature/tool_detail/presentation/components/money_overview_tab.dart';
import 'package:investflow/feature/tool_detail/presentation/components/money_performance_tab.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

void main() {
  group('Money Asset Tabs', () {
    final testTool = ToolDetailDisplay(
      id: 'test-money',
      name: 'Test Money Account',
      quantity: 1000.0,
      percentageChange: 0.0,
      accountId: 'test-account',
      type: 'MONEY',
      currentValue: 10000.0,
      ticker: null,
      startDate: null,
      endDate: null,
      interestRate: null,
      faceValue: null,
      paymentDayOfMonth: null,
    );

    testWidgets('MoneyOverviewTab displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyOverviewTab(tool: testTool),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if the account name is displayed
      expect(find.text('Cash Account'), findsOneWidget);

      // Check if the balance is displayed
      expect(find.text('\$10,000.00'), findsOneWidget);

      // Check if balance label is displayed
      expect(find.text('Current Balance'), findsOneWidget);

      // Quick actions should NOT be present in overview tab
      expect(find.text('Quick Actions'), findsNothing);
      expect(find.text('Send'), findsNothing);
      expect(find.text('Withdraw'), findsNothing);
      expect(find.text('Pay Bills'), findsNothing);
    });

    testWidgets('MoneyPerformanceTab displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyPerformanceTab(tool: testTool),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if performance title is displayed
      expect(find.text('Performance'), findsOneWidget);

      // Check if performance metrics are present
      expect(find.text('Performance Metrics'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('This Year'), findsOneWidget);
    });

    testWidgets('MoneyOverviewTab shows transfer dialog on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyOverviewTab(tool: testTool),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the Send action card
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Check if the transfer dialog appears
      expect(find.text('Send Money'), findsOneWidget);
      expect(find.text('Recipient'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('MoneyOverviewTab shows withdraw dialog on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyOverviewTab(tool: testTool),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the Withdraw action card
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      // Check if the withdraw dialog appears
      expect(find.text('Withdraw Money'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('MoneyOverviewTab shows bills dialog on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyOverviewTab(tool: testTool),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the Pay Bills action card
      await tester.tap(find.text('Pay Bills'));
      await tester.pumpAndSettle();

      // Check if the bills dialog appears
      expect(find.text('Pay Bills'), findsOneWidget);
      expect(find.text('Electric Bill'), findsOneWidget);
      expect(find.text('Water Bill'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
    });
  });
}