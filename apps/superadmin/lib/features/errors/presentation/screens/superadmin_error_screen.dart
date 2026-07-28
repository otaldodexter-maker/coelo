import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum SuperadminErrorKind {
  forbidden(
    code: '403',
    message: 'Você não tem permissão para acessar esta área.',
    actionLabel: 'Voltar ao início',
  ),
  notFound(
    code: '404',
    message: 'Não encontramos a página que você procura.',
    actionLabel: 'Voltar ao início',
  ),
  internal(
    code: '500',
    message: 'Não foi possível concluir esta ação.',
    actionLabel: 'Tentar novamente',
  ),
  unavailable(
    code: '503',
    message: 'O Coelo está temporariamente indisponível.',
    actionLabel: 'Tentar novamente',
  );

  const SuperadminErrorKind({required this.code, required this.message, required this.actionLabel});

  final String code;
  final String message;
  final String actionLabel;

  static SuperadminErrorKind fromCode(String? code) {
    return SuperadminErrorKind.values.firstWhere(
      (kind) => kind.code == code,
      orElse: () => SuperadminErrorKind.notFound,
    );
  }
}

final class SuperadminErrorScreen extends StatelessWidget {
  const SuperadminErrorScreen({required this.kind, required this.onAction, super.key});

  final SuperadminErrorKind kind;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primaryContainer,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final useHorizontalLayout =
                constraints.maxWidth > CoeloBreakpoints.compact.maxWidth && textScale <= 1.5;
            final horizontalPadding = useHorizontalLayout
                ? CoeloSpacing.space10
                : CoeloSpacing.space4;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: CoeloSpacing.space8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        container: true,
                        label: 'Erro ${kind.code}. ${kind.message}',
                        child: ExcludeSemantics(
                          child: useHorizontalLayout
                              ? _HorizontalErrorContent(
                                  kind: kind,
                                  color: colorScheme.onPrimaryContainer,
                                  textTheme: textTheme,
                                )
                              : _VerticalErrorContent(
                                  kind: kind,
                                  color: colorScheme.onPrimaryContainer,
                                  textTheme: textTheme,
                                ),
                        ),
                      ),
                      const SizedBox(height: CoeloSpacing.space6),
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onPrimaryContainer,
                        ),
                        child: Text(kind.actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _HorizontalErrorContent extends StatelessWidget {
  const _HorizontalErrorContent({required this.kind, required this.color, required this.textTheme});

  final SuperadminErrorKind kind;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kind.code, style: textTheme.titleMedium?.copyWith(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            child: VerticalDivider(color: color),
          ),
          Flexible(
            child: Text(kind.message, style: textTheme.bodyLarge?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

final class _VerticalErrorContent extends StatelessWidget {
  const _VerticalErrorContent({required this.kind, required this.color, required this.textTheme});

  final SuperadminErrorKind kind;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(kind.code, style: textTheme.titleMedium?.copyWith(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
          child: Divider(color: color),
        ),
        Text(
          kind.message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}
