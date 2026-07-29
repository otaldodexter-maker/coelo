import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows initials with an image semantic label', (tester) async {
    await _pumpAvatar(
      tester,
      const CoeloAvatar(initials: 'AM', semanticLabel: 'Foto de Ana Martins'),
    );

    expect(find.text('AM'), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(CoeloAvatar));
    expect(semantics.label, 'Foto de Ana Martins');
    expect(semantics.getSemanticsData().flagsCollection.isImage, isTrue);
  });

  testWidgets('uses the neutral person fallback without initials or image', (tester) async {
    await _pumpAvatar(tester, const CoeloAvatar(semanticLabel: 'Pessoa sem foto'));

    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  testWidgets('falls back to initials when the image cannot load', (tester) async {
    await _pumpAvatar(
      tester,
      CoeloAvatar(
        initials: 'AM',
        semanticLabel: 'Foto de Ana Martins',
        image: MemoryImage(Uint8List.fromList(const [0])),
      ),
    );
    await tester.pump();

    expect(find.text('AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maps public sizes to avatar tokens', (tester) async {
    for (final (size, expected) in [
      (CoeloAvatarSize.small, CoeloSize.avatarSm),
      (CoeloAvatarSize.medium, CoeloSize.avatarMd),
      (CoeloAvatarSize.large, CoeloSize.avatarLg),
    ]) {
      await _pumpAvatar(tester, CoeloAvatar(semanticLabel: 'Avatar', size: size));

      expect(tester.getSize(find.byType(CoeloAvatar)), Size.square(expected));
    }
  });

  testWidgets('preserves semantics without overflow in light and dark at 200%', (tester) async {
    for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
      await _pumpAvatar(
        tester,
        const CoeloAvatar(
          initials: 'AM',
          semanticLabel: 'Foto de Ana Martins',
          size: CoeloAvatarSize.large,
        ),
        theme: theme,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSemantics(find.byType(CoeloAvatar)).label, 'Foto de Ana Martins');
    }
  });
}

Future<void> _pumpAvatar(
  WidgetTester tester,
  CoeloAvatar avatar, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(body: Center(child: avatar)),
    ),
  );
}
