import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:construction_estimation/screens/home_screen.dart';
import 'package:construction_estimation/theme/app_theme.dart';

void main() {
  Widget app() => MaterialApp(
        theme: AppTheme.light(),
        home: const HomeScreen(),
      );

  testWidgets('HomeScreen renders all 5 nav destinations', (tester) async {
    await tester.pumpWidget(app());

    // NavigationBar labels — appear in destinations
    expect(find.widgetWithText(NavigationDestination, 'Materials'),
        findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Labour'),
        findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'AC'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Estimates'),
        findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Settings'),
        findsOneWidget);
  });

  testWidgets('Default tab is Estimates (index 3)', (tester) async {
    await tester.pumpWidget(app());

    // AppBar shows the current tab title
    expect(find.widgetWithText(AppBar, 'Project Estimates'), findsOneWidget);
  });

  testWidgets('Tapping each tab updates AppBar title', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.widgetWithText(NavigationDestination, 'Materials'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Materials'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Labour'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Labour'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'AC'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Abstract of Cost'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    // Settings sections render
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
