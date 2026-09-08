// Reproducao C07: em larguras compactas (< 840), o `_PageHeader` do
// `SuperadminShell` com `compactActions` nao vazias usa um ramo
// `Stack(alignment: topEnd)` que encolhe ao conteudo; como o `Column` pai nao
// usa `CrossAxisAlignment.stretch`, o cabecalho fica centralizado e o titulo
// perde o inset esquerdo de `CoeloSpacing.space5` que as paginas sem acoes
// compactas mantem. Este teste mede o `dx` do titulo com e sem acoes e exige
// que sejam iguais.
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Mesmo titulo e legenda de `SuperadminChatPage` (superadmin_chat_page.dart).
const _title = 'Conversas';
const _subtitle = 'Comunicacao institucional privada e contextual.';

void main() {
  // A fonte real e necessaria: com a fonte de teste padrao (glifos de ~1em) a
  // legenda quebra linha em 375 px, o Stack preenche a largura toda e o
  // defeito deixa de ser observavel nessa largura.
  setUpAll(_loadNunitoSans);

  for (final width in [375.0, 768.0]) {
    testWidgets(
      'page header keeps the same left inset with and without compact actions '
      'at ${width.toInt()}x900',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(Size(width, 900));

        // Baseline: pagina sem acao alguma (ex.: Instituicoes), que hoje fica
        // em dx = CoeloSpacing.space5.
        await tester.pumpWidget(_shellApp(withActions: false));
        await tester.pumpAndSettle();
        final titleWithoutActions = tester.getTopLeft(find.text(_title));
        final subtitleWithoutActions = tester.getTopLeft(find.text(_subtitle));

        // Chat: `actions` + `compactActions` exatamente como SuperadminChatPage.
        await tester.pumpWidget(_shellApp(withActions: true));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('coelo-admin-files-action')),
          findsOneWidget,
          reason: 'o ramo compacto com acoes precisa estar ativo em $width px',
        );
        final titleWithActions = tester.getTopLeft(find.text(_title));
        final subtitleWithActions = tester.getTopLeft(find.text(_subtitle));

        expect(
          titleWithActions.dx,
          moreOrLessEquals(titleWithoutActions.dx, epsilon: 0.5),
          reason:
              'titulo em $width px: sem acoes dx=${titleWithoutActions.dx}, '
              'com acoes dx=${titleWithActions.dx}',
        );
        expect(
          subtitleWithActions.dx,
          moreOrLessEquals(subtitleWithoutActions.dx, epsilon: 0.5),
          reason:
              'legenda em $width px: sem acoes dx=${subtitleWithoutActions.dx}, '
              'com acoes dx=${subtitleWithActions.dx}',
        );

        // O bloco titulo+legenda deve ficar encostado no inset esquerdo, nunca
        // centralizado na largura da tela.
        final titleRect = tester.getRect(find.text(_title));
        final subtitleRect = tester.getRect(find.text(_subtitle));
        final blockLeft = titleRect.left < subtitleRect.left ? titleRect.left : subtitleRect.left;
        final blockRight = titleRect.right > subtitleRect.right
            ? titleRect.right
            : subtitleRect.right;
        final blockCenter = (blockLeft + blockRight) / 2;
        expect(
          blockLeft,
          moreOrLessEquals(CoeloSpacing.space5, epsilon: 0.5),
          reason:
              'bloco titulo+legenda em $width px deveria comecar em '
              '${CoeloSpacing.space5}, comecou em $blockLeft '
              '(centro do bloco=$blockCenter, centro da tela=${width / 2})',
        );
      },
    );
  }
}

Widget _shellApp({required bool withActions}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: ThemeMode.light,
    home: SuperadminShell(
      logout: () async => const LogoutResult.success(),
      title: _title,
      subtitle: _subtitle,
      actions: withActions ? [_chatFileActions(compact: false)] : const [],
      compactActions: withActions ? [_chatFileActions(compact: true)] : const [],
      currentDestination: 'conversations',
      onDestinationSelected: (_) {},
      child: const SizedBox.expand(),
    ),
  );
}

// Replica `_fileActions` de `SuperadminChatPage`, que e o que o chat passa ao
// shell em `compactActions: [_fileActions(compact: true)]`.
Widget _chatFileActions({bool compact = true}) => CoeloAdminFileActions(
  compact: compact,
  actions: [
    CoeloAdminFileAction(label: 'Importar', icon: Icons.upload_file_outlined, onPressed: () {}),
    CoeloAdminFileAction(label: 'Exportar CSV', icon: Icons.table_rows_outlined, onPressed: () {}),
    CoeloAdminFileAction(label: 'Exportar XLSX', icon: Icons.grid_on_outlined, onPressed: () {}),
  ],
);

Future<void> _loadNunitoSans() async {
  final fontLoader = FontLoader(CoeloTypography.fontFamily)
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await fontLoader.load();
}
