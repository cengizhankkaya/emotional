import 'package:emotional/features/home/presentation/widgets/web_home_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Small laptop up to a 1440p monitor, plus a short window.
  const sizes = [
    Size(900, 700),
    Size(1024, 600),
    Size(1366, 768),
    Size(1920, 1080),
    Size(2560, 1440),
  ];

  for (final size in sizes) {
    testWidgets('lays out without overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebHomeBody(
              userName: 'Cengizhan Kaya',
              roomIdController: controller,
              onCreateRoom: () {},
              onJoinRoom: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Content stays in a centred band instead of spreading edge to edge.
      final body = tester.getRect(find.byType(Row).first);
      expect(body.width, lessThanOrEqualTo(1120));
    });
  }
}
