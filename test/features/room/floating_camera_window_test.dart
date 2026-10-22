import 'package:emotional/features/room/presentation/widgets/web/floating_camera_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Axis? axis;

  Future<void> pumpStage(
    WidgetTester tester, {
    Size stage = const Size(700, 500),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: stage,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FloatingCameraWindow(
                    cameraCount: 2,
                    builder: (context, a) {
                      axis = a;
                      return const ColoredBox(color: Colors.red);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Rect window(WidgetTester tester) => tester.getRect(
    find.byWidgetPredicate((w) => w is Positioned && w.width != null),
  );

  testWidgets('starts in the top right corner as a column', (tester) async {
    await pumpStage(tester);
    final rect = window(tester);
    expect(rect.right, 700 - 12);
    expect(rect.width, 200);
    expect(rect.height, greaterThan(rect.width));
    expect(axis, Axis.vertical);
  });

  testWidgets('drags anywhere on the stage, never off it', (tester) async {
    await pumpStage(tester);
    final start = window(tester);

    await tester.drag(
      find.byIcon(Icons.drag_handle_rounded),
      const Offset(-300, 100),
    );
    await tester.pump();
    expect(window(tester).topLeft, start.topLeft + const Offset(-300, 100));

    await tester.drag(
      find.byIcon(Icons.drag_handle_rounded),
      const Offset(-5000, 5000),
    );
    await tester.pump();
    final rect = window(tester);
    expect(rect.left, 0);
    expect(rect.bottom, 500);
  });

  testWidgets('the corner resizes it; a wide window is a row', (tester) async {
    await pumpStage(tester);
    final start = window(tester);
    final corner = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeDownLeft,
    );

    await tester.drag(corner, const Offset(-300, -150));
    await tester.pump();
    final rect = window(tester);
    expect(rect.right, start.right, reason: 'anchored to the right');
    expect(rect.width, start.width + 300);
    expect(rect.height, start.height - 150);
    expect(axis, Axis.horizontal);

    // Not smaller than usable, not bigger than the stage allows.
    await tester.drag(corner, const Offset(5000, -5000));
    await tester.pump();
    expect(window(tester).size, const Size(140, 100));
  });

  testWidgets('stays on a stage that shrinks', (tester) async {
    await pumpStage(tester);
    await pumpStage(tester, stage: const Size(400, 300));
    final rect = window(tester);
    expect(rect.right, lessThanOrEqualTo(400));
    expect(rect.bottom, lessThanOrEqualTo(300));
    expect(rect.left, greaterThanOrEqualTo(0));
  });
}
