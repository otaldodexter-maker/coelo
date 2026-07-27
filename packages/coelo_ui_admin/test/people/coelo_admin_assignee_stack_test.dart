import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves order, caps avatars at three and announces all assignees', (tester) async {
    final image = MemoryImage(Uint8List.fromList(_onePixelPng));
    final items = [
      CoeloAdminAssigneeItem(label: 'Ana', initials: 'AN', roleLabel: 'Principal', image: image),
      const CoeloAdminAssigneeItem(label: 'Bia', initials: 'BI', roleLabel: 'Colaboradora'),
      const CoeloAdminAssigneeItem(label: 'Caio', initials: 'CA', roleLabel: 'Colaborador'),
      const CoeloAdminAssigneeItem(label: 'Dani', initials: 'DA', roleLabel: 'Colaboradora'),
      const CoeloAdminAssigneeItem(label: 'Eli', initials: 'EL', roleLabel: 'Colaborador'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: CoeloAdminAssigneeStack(items: items)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('BI'), findsOneWidget);
    expect(find.text('CA'), findsOneWidget);
    expect(find.text('DA'), findsNothing);

    final avatars = tester.widgetList<CircleAvatar>(find.byType(CircleAvatar)).toList();
    expect(avatars.first.backgroundImage, same(image));
    expect(avatars[1].backgroundImage, isNull);
    expect(avatars.every((avatar) => avatar.radius == CoeloSize.avatarSm / 2), isTrue);

    final firstX = tester.getTopLeft(find.byType(CircleAvatar).at(0)).dx;
    final secondX = tester.getTopLeft(find.byType(CircleAvatar).at(1)).dx;
    expect(secondX - firstX, CoeloSize.avatarSm - CoeloSpacing.space2);
    expect(
      find.bySemanticsLabel(
        'Ana, Principal; Bia, Colaboradora; Caio, Colaborador; '
        'Dani, Colaboradora; Eli, Colaborador',
      ),
      findsOneWidget,
    );
  });
}

const _onePixelPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
