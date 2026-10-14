import 'dart:async';

import 'package:emotional/product/init/version_check_wrapper.dart';
import 'package:emotional/product/utility/validator/app_build.dart';
import 'package:emotional/product/widget/dialog/force_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ({UpdateDecision decision, AppBuild? deployed}) next;
  late StreamController<void> recheck;
  late int checks;

  final build23 = AppBuild.tryParse('1.1.0', '23')!;
  final build24 = AppBuild.tryParse('1.1.0', '24')!;

  setUp(() {
    next = (decision: UpdateDecision.none, deployed: null);
    recheck = StreamController<void>.broadcast();
    checks = 0;
  });

  tearDown(() => recheck.close());

  Future<void> pumpApp(WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        // Same spot as in the app: above the Navigator.
        builder: (context, child) => VersionCheckWrapper(
          navigatorKey: navigatorKey,
          check: ({bool refreshConfig = false}) async {
            checks++;
            return next;
          },
          recheck: recheck.stream,
          child: child!,
        ),
        home: const Scaffold(body: Text('home')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> checkAgain(WidgetTester tester) async {
    recheck.add(null);
    await tester.pumpAndSettle();
  }

  // Keys stand in for text: no translations are loaded in tests.
  final banner = find.text('update.available');

  testWidgets('nothing shows while up to date', (tester) async {
    await pumpApp(tester);
    expect(checks, 1, reason: 'checks once at start');
    expect(banner, findsNothing);
    expect(find.byType(ForceUpdateDialog), findsNothing);
  });

  testWidgets('a new deploy shows a banner that can be dismissed', (
    tester,
  ) async {
    next = (decision: UpdateDecision.available, deployed: build23);
    await pumpApp(tester);
    expect(banner, findsOneWidget);
    expect(find.text('update.reload'), findsOneWidget);
    expect(find.text('home'), findsOneWidget, reason: 'does not block');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(banner, findsNothing);

    // The same deploy stays dismissed...
    await checkAgain(tester);
    expect(banner, findsNothing);

    // ...a newer one shows again.
    next = (decision: UpdateDecision.available, deployed: build24);
    await checkAgain(tester);
    expect(banner, findsOneWidget);
  });

  testWidgets('the banner goes away when the deploy is rolled back', (
    tester,
  ) async {
    next = (decision: UpdateDecision.available, deployed: build23);
    await pumpApp(tester);
    expect(banner, findsOneWidget);

    next = (decision: UpdateDecision.none, deployed: null);
    await checkAgain(tester);
    expect(banner, findsNothing);
  });

  testWidgets('a required update blocks the app, once', (tester) async {
    next = (decision: UpdateDecision.required, deployed: null);
    // Used to throw: the wrapper's own context has no Navigator.
    await pumpApp(tester);
    expect(find.byType(ForceUpdateDialog), findsOneWidget);
    expect(find.text('update.title'), findsOneWidget);

    // Neither the back button nor the barrier closes it.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(ForceUpdateDialog), findsOneWidget);

    await checkAgain(tester);
    expect(find.byType(ForceUpdateDialog), findsOneWidget);
    expect(checks, 1, reason: 'stops checking once blocked');
  });

  testWidgets('a required update replaces the banner', (tester) async {
    next = (decision: UpdateDecision.available, deployed: build23);
    await pumpApp(tester);
    expect(banner, findsOneWidget);

    next = (decision: UpdateDecision.required, deployed: build24);
    await checkAgain(tester);
    expect(banner, findsNothing);
    expect(find.byType(ForceUpdateDialog), findsOneWidget);
  });
}
