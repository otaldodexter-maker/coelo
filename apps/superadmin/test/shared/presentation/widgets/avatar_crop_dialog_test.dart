import 'dart:convert';

import 'package:coelo_superadmin/shared/presentation/widgets/avatar_crop_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crops an avatar with equal actions and a circular reset control', (tester) async {
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
                  builder: (_) => AvatarCropDialog(bytes: _transparentPng),
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
    expect(tester.widget<Slider>(slider).value, greaterThan(1));
    await tester.tap(reset);
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.bytes, _transparentPng);
    expect(result!.scale, 1);
    expect(result!.offset, Offset.zero);
  });
}

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL8wQAAAABJRU5ErkJggg==',
);
