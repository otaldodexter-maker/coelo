import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/shared/presentation/widgets/avatar_crop_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns a valid repositioned 320 square avatar', (tester) async {
    AvatarCropResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<AvatarCropResult>(
                  context: context,
                  builder: (_) => AvatarCropDialog(bytes: _sourcePng, rasterizer: _fakeRasterizer),
                );
              },
              child: const Text('Abrir recorte'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir recorte'));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    expect(find.byKey(const Key('coelo-avatar-crop-view')), findsOneWidget);
    final reset = find.byTooltip('Redefinir recorte');
    expect(reset, findsOneWidget);
    expect(tester.getSize(reset), const Size.square(CoeloSize.touchMin));

    final footer = find.byKey(const Key('coelo-admin-dialog-footer'));
    expect(
      tester.getSize(find.descendant(of: footer, matching: find.byType(OutlinedButton))).width,
      tester.getSize(find.descendant(of: footer, matching: find.byType(FilledButton))).width,
    );

    final slider = find.byType(Slider);
    tester.widget<Slider>(slider).onChanged!(2);
    await tester.pump();
    await tester.drag(find.byKey(const Key('coelo-avatar-crop-view')), const Offset(24, 16));
    await tester.pump();

    await tester.tap(reset);
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, 1);

    tester.widget<Slider>(slider).onChanged!(2);
    await tester.pump();
    await tester.drag(find.byKey(const Key('coelo-avatar-crop-view')), const Offset(24, 16));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    for (var attempt = 0; attempt < 100 && result == null; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(result, isNotNull);
    expect(result!.bytes, isNotEmpty);
    expect(result!.scale, greaterThan(1));
  });
}

final _sourcePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAdSURBVDhPY/i/lOE/JZgBXYBUPGrAqAGjBgwWAwC+5aMf+7YJAgAAAABJRU5ErkJggg==',
);

Future<Uint8List?> _fakeRasterizer({
  required Uint8List bytes,
  required Size viewportSize,
  required Matrix4 transform,
  required int outputWidth,
  required int outputHeight,
}) async => bytes;
