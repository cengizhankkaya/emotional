import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/presentation/widgets/web/web_drive_picker_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class _FakeDriveService extends DriveService {
  final searches = <String?>[];
  bool fail = false;

  @override
  Future<drive.FileList?> listVideoFiles({
    String? pageToken,
    int pageSize = 10,
    bool silentOnly = false,
    String? search,
  }) async {
    searches.add(search);
    if (fail) return null;
    final all = [
      for (var i = 0; i < 5; i++)
        drive.File()
          ..id = 'f$i'
          ..name = i == 0 ? 'Holiday.mp4' : 'Clip $i.mp4'
          ..mimeType = i == 2 ? 'video/x-no-browser-plays-this' : 'video/mp4'
          ..size = '${(i + 1) * 1024 * 1024}',
    ];
    final query = search ?? '';
    return drive.FileList()
      ..files = all.where((f) => f.name!.contains(query)).toList();
  }
}

void main() {
  late _FakeDriveService service;
  var popupRequests = 0;
  String? token;
  drive.File? picked;

  setUp(() {
    service = _FakeDriveService();
    popupRequests = 0;
    token = 'token';
    picked = null;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepositoryProvider<DriveService>.value(
        value: service,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  picked = await showDialog<drive.File>(
                    context: context,
                    builder: (_) => WebDrivePickerDialog(
                      currentFileId: 'f1',
                      tokenLookup: ({bool silentOnly = false}) async {
                        if (!silentOnly) {
                          popupRequests++;
                          token = 'token';
                        }
                        return token;
                      },
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists Drive videos and returns the tapped one', (tester) async {
    await pump(tester);
    expect(find.text('Holiday.mp4'), findsOneWidget);
    expect(find.text('Clip 4.mp4'), findsOneWidget);
    expect(popupRequests, 0);

    await tester.tap(find.text('Holiday.mp4'));
    await tester.pumpAndSettle();
    expect(find.byType(WebDrivePickerDialog), findsNothing);
    expect(picked?.id, 'f0');
  });

  testWidgets(
    'flags videos the browser may not play',
    (tester) async {
      await pump(tester);
      // Only Clip 2 has a format no browser knows; MP4 plays everywhere.
      expect(find.text('drive.mayNotPlay'), findsOneWidget);
    },
    // Asks the browser's <video> element.
    skip: !kIsWeb,
  );

  testWidgets('searches after typing stops', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Holiday');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(service.searches.last, 'Holiday');
    expect(find.text('Holiday.mp4'), findsOneWidget);
    expect(find.text('Clip 1.mp4'), findsNothing);
  });

  testWidgets('asks to connect without opening a popup by itself', (
    tester,
  ) async {
    token = null;
    await pump(tester);
    expect(popupRequests, 0);
    expect(service.searches, isEmpty);

    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();
    expect(popupRequests, 1);
    expect(find.text('Holiday.mp4'), findsOneWidget);
  });

  testWidgets('offers a retry when Drive fails', (tester) async {
    service.fail = true;
    await pump(tester);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    service.fail = false;
    await tester.tap(find.byIcon(Icons.refresh).last);
    await tester.pumpAndSettle();
    expect(find.text('Holiday.mp4'), findsOneWidget);
  });
}
