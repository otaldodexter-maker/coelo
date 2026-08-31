import 'dart:io';

import 'package:coelo_superadmin/features/principal_shared/presentation/principal_publication_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('frame alterna resumo compacto e navegação ampla sem overflow', (tester) async {
    for (final width in [375.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('principal-publication-step-summary')),
        width == 375 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('principal-publication-step-media')),
        width == 1024 ? findsOneWidget : findsNothing,
      );
    }
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('footer põe primária primeiro no compacto e Cancelar à esquerda no amplo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Publicar')).dy,
      lessThan(tester.getTopLeft(find.text('Salvar rascunho')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Salvar rascunho')).dy,
      lessThan(tester.getTopLeft(find.text('Cancelar')).dy),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cancelar')).dx,
      lessThan(tester.getTopLeft(find.text('Salvar rascunho')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Salvar rascunho')).dx,
      lessThan(tester.getTopLeft(find.text('Publicar')).dx),
    );
  });

  testWidgets('texto a 200% empilha o footer amplo sem overflow', (tester) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Publicar')).dy,
      lessThan(tester.getTopLeft(find.text('Salvar rascunho')).dy),
    );
  });

  testWidgets('linha do toggle alterna por teclado e preserva semântica', (tester) async {
    var value = false;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PrincipalPublicationToggleField(
              label: 'Salvar automaticamente',
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(value, isTrue);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Salvar automaticamente')),
      matchesSemantics(
        label: 'Salvar automaticamente',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  test('features do Principal não importam componentes administrativos', () {
    final directories = Directory('lib/features').listSync().whereType<Directory>().where(
      (directory) => directory.path.split(Platform.pathSeparator).last.startsWith('principal_'),
    );
    final files = directories
        .expand((directory) => directory.listSync(recursive: true))
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('package:coelo_ui_admin')), reason: file.path);
      expect(source, isNot(contains('superadmin_form_')), reason: file.path);
    }
  });
}

Widget _app({TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: PrincipalPublicationFrame(
      navigation: PrincipalPublicationStepNavigation(
        currentIndex: 0,
        onStepSelected: (_) {},
        steps: const [
          PrincipalPublicationStep(
            key: Key('principal-publication-step-media'),
            label: 'Mídia',
            status: PrincipalPublicationStepStatus.current,
          ),
          PrincipalPublicationStep(
            label: 'Conteúdo',
            status: PrincipalPublicationStepStatus.incomplete,
          ),
        ],
      ),
      body: const SizedBox(height: 200, child: Text('Sua publicação')),
      footer: PrincipalPublicationActionFooter(
        tertiaryAction: TextButton(onPressed: () {}, child: const Text('Cancelar')),
        continuationActions: [
          OutlinedButton(onPressed: () {}, child: const Text('Salvar rascunho')),
          FilledButton(onPressed: () {}, child: const Text('Publicar')),
        ],
      ),
    ),
  ),
);
