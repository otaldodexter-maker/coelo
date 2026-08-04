import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/shared/presentation/widgets/cover_crop_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adjusts a cover in a rectangular viewport with equal actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<CoverCropResult>(
                context: context,
                builder: (_) => CoverCropDialog(bytes: _transparentPng),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustar capa'), findsOneWidget);
    expect(find.textContaining('retângulo'), findsOneWidget);
    final viewport = tester.getRect(find.byKey(const Key('coelo-cover-crop-view')));
    expect(viewport.width / viewport.height, closeTo(CoverCropDialog.aspectRatio, 0.02));
    final cancel = tester.getSize(find.widgetWithText(OutlinedButton, 'Cancelar'));
    final apply = tester.getSize(find.widgetWithText(FilledButton, 'Aplicar'));
    expect(cancel.width, closeTo(apply.width, 1));
    expect(find.byTooltip('Redefinir recorte'), findsOneWidget);
  });
}

final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
