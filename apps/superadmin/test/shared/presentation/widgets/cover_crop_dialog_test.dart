import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/shared/presentation/widgets/cover_crop_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns a valid repositioned 851 by 315 cover', (tester) async {
    CoverCropResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<CoverCropResult>(
                  context: context,
                  builder: (_) => CoverCropDialog(bytes: _sourcePng, rasterizer: _fakeRasterizer),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustar capa'), findsOneWidget);
    expect(find.textContaining('ret'), findsWidgets);
    final viewport = tester.getRect(find.byKey(const Key('coelo-cover-crop-view')));
    expect(viewport.width / viewport.height, closeTo(851 / 315, 0.02));
    final cancel = tester.getSize(find.widgetWithText(OutlinedButton, 'Cancelar'));
    final apply = tester.getSize(find.widgetWithText(FilledButton, 'Aplicar'));
    expect(cancel.width, closeTo(apply.width, 1));
    expect(find.byTooltip('Redefinir recorte'), findsOneWidget);

    final slider = find.byType(Slider);
    tester.widget<Slider>(slider).onChanged!(2);
    await tester.pump();
    await tester.drag(find.byKey(const Key('coelo-cover-crop-view')), const Offset(24, 12));
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

final Uint8List _sourcePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABsAAAAKCAYAAABFXiVrAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAfSURBVDhPY/i/lOE/vTADugAt8ahlVMGjllEFD1/LAE1DyAkvbpZRAAAAAElFTkSuQmCC',
);

Future<Uint8List?> _fakeRasterizer({
  required Uint8List bytes,
  required Size viewportSize,
  required Matrix4 transform,
  required int outputWidth,
  required int outputHeight,
}) async => bytes;
