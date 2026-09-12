import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';

/// Canonical private frame for Superadmin entity forms.
final class SuperadminFormFrame extends StatelessWidget {
  const SuperadminFormFrame({
    required this.navigation,
    required this.body,
    required this.footer,
    required this.viewportWidth,
    this.bodyMaxWidth = 880,
    this.scrollKey,
    super.key,
  });

  final Widget navigation;
  final Widget body;
  final Widget footer;
  final double viewportWidth;
  final double bodyMaxWidth;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final localWidth = constraints.maxWidth;
        final showRail = localWidth >= CoeloBreakpoints.medium.minWidth;
        final inset = showRail && localWidth >= CoeloBreakpoints.expanded.minWidth
            ? CoeloSpacing.space10
            : showRail
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        final mainRegion = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: scrollKey,
                  // Respiro no fim do conteudo (P15, decisao do Owner de 10/09/2026):
                  // com o rodape ancorado, a ultima linha do formulario precisa de
                  // espaco para nunca terminar colada ou escondida sob o rodape.
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!showRail) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: bodyMaxWidth),
                          child: body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // O rodape fica ancorado no fim da viewport em todas as larguras.
              // Antes ele ia para dentro do scroll em mobile, entao subia junto
              // com conteudo curto e ficava fora da primeira tela em formulario
              // longo. Decisao do Owner de 10/09/2026 sobre a observacao RODAPE.
              // Texto ampliado ou teclado podem deixar menos altura que o
              // rodape. Preservar espaco para o formulario e tornar todas as
              // acoes alcancaveis, sem reduzir texto nem sobrepor o conteudo.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: ((constraints.maxHeight - inset - CoeloSpacing.space4) / 2).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: SingleChildScrollView(child: footer),
              ),
            ],
          ),
        );
        return _ChatLauncherSuppressor(
          child: Padding(
            padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showRail) ...[navigation, const SizedBox(width: CoeloSpacing.space6)],
                mainRegion,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Decisao 7 do Owner (10/09/2026): sem balao de chat em criar, editar e
/// publicar. Todo formulario passa por este frame, entao e aqui, no
/// componente compartilhado, que o shell hospedeiro fica sabendo; assim o
/// balao nunca cobre o rodape ancorado, em largura nenhuma, sem cada tela
/// precisar lembrar da flag.
final class _ChatLauncherSuppressor extends StatefulWidget {
  const _ChatLauncherSuppressor({required this.child});

  final Widget child;

  @override
  State<_ChatLauncherSuppressor> createState() => _ChatLauncherSuppressorState();
}

final class _ChatLauncherSuppressorState extends State<_ChatLauncherSuppressor> {
  VoidCallback? _release;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _release ??= SuperadminShell.suppressChatLauncher(context);
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
