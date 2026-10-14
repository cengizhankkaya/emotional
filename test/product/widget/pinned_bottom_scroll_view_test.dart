import 'package:emotional/product/widget/pinned_bottom_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({required double height, required double contentHeight}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: height,
          child: PinnedBottomScrollView(
            top: SizedBox(key: const Key('top'), height: contentHeight),
            bottom: const SizedBox(key: Key('bottom'), height: 100),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pins the bottom widget to the bottom edge when it fits', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(height: 600, contentHeight: 180));

    final area = tester.getRect(find.byType(PinnedBottomScrollView));
    expect(tester.getRect(find.byKey(const Key('top'))).top, area.top);
    expect(tester.getRect(find.byKey(const Key('bottom'))).bottom, area.bottom);
  });

  testWidgets('scrolls instead of overflowing when it does not fit', (
    tester,
  ) async {
    // The reported case: ~98px more content than space.
    await tester.pumpWidget(_harness(height: 380, contentHeight: 378));

    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(PinnedBottomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    final area = tester.getRect(find.byType(PinnedBottomScrollView));
    expect(tester.getRect(find.byKey(const Key('bottom'))).bottom, area.bottom);
  });
}
