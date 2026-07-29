import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the neutral bug-popup shell and equal two-action footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => CoeloAdminDialogShell(
                title: 'Editar pessoa',
                closeTooltip: 'Fechar edição',
                body: const Text('Conteúdo'),
                secondaryAction: OutlinedButton(
                  key: const Key('secondary-action'),
                  onPressed: () {},
                  child: const Text('Cancelar'),
                ),
                primaryAction: FilledButton(
                  key: const Key('primary-action'),
                  onPressed: () {},
                  child: const Text('Salvar'),
                ),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    expect(dialog.surfaceTintColor, Colors.transparent);
    expect(find.byType(Divider), findsOneWidget);
    expect(find.byTooltip('Fechar edição'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    final secondary = tester.getRect(find.byKey(const Key('secondary-action')));
    final primary = tester.getRect(find.byKey(const Key('primary-action')));
    expect(secondary.width, primary.width);
    expect(primary.left - secondary.right, CoeloSpacing.space3);
    expect(secondary.height, greaterThanOrEqualTo(CoeloSize.touchMin));
  });

  testWidgets('stretches a single action across the footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => CoeloAdminDialogShell(
                title: 'Bug! O Coelo resolve!',
                body: const Text('Conteúdo'),
                primaryAction: FilledButton(
                  key: const Key('single-action'),
                  onPressed: () {},
                  child: const Text('Enviar'),
                ),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final footer = tester.getRect(find.byKey(const Key('coelo-admin-dialog-footer')));
    final action = tester.getRect(find.byKey(const Key('single-action')));
    expect(action.left, footer.left);
    expect(action.right, footer.right);
  });

  testWidgets('scrolls only the body and Escape restores focus to the opener', (tester) async {
    final openerFocusNode = FocusNode();
    addTearDown(openerFocusNode.dispose);
    await tester.binding.setSurfaceSize(const Size(700, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            focusNode: openerFocusNode,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => CoeloAdminDialogShell(
                title: 'Conteúdo rolável',
                body: Column(children: List.generate(20, (index) => Text('Linha $index'))),
                primaryAction: FilledButton(onPressed: () {}, child: const Text('Salvar')),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    openerFocusNode.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final footerTop = tester.getTopLeft(find.byKey(const Key('coelo-admin-dialog-footer'))).dy;
    final firstLineTop = tester.getTopLeft(find.text('Linha 0')).dy;
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Linha 0')).dy, lessThan(firstLineTop));
    expect(tester.getTopLeft(find.byKey(const Key('coelo-admin-dialog-footer'))).dy, footerTop);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminDialogShell), findsNothing);
    expect(openerFocusNode.hasFocus, isTrue);
  });

  testWidgets('lets footer actions grow with text at 200 percent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => CoeloAdminDialogShell(
                title: 'Confirmar saída',
                body: const Text('Há alterações não salvas.'),
                secondaryAction: OutlinedButton(
                  key: const Key('keep-editing'),
                  onPressed: () {},
                  child: const Text('Continuar editando'),
                ),
                primaryAction: FilledButton(
                  key: const Key('leave-without-saving'),
                  onPressed: () {},
                  child: const Text('Sair sem salvar'),
                ),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('keep-editing'))).height,
      greaterThanOrEqualTo(CoeloSize.touchMin),
    );
    expect(
      tester.getSize(find.byKey(const Key('leave-without-saving'))).height,
      greaterThanOrEqualTo(CoeloSize.touchMin),
    );
  });
}
