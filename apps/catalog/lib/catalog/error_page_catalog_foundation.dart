import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';

Map<String, CatalogFoundation> buildErrorPageFoundationRegistry() {
  return {
    'pattern.error-pages': CatalogFoundation(
      id: 'pattern.error-pages',
      builder: (_) => const _ErrorPageFoundation(),
    ),
  };
}

final class _ErrorPageFoundation extends StatefulWidget {
  const _ErrorPageFoundation();

  @override
  State<_ErrorPageFoundation> createState() => _ErrorPageFoundationState();
}

final class _ErrorPageFoundationState extends State<_ErrorPageFoundation> {
  _ErrorPageReference _selected = _references.first;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Use página fullscreen somente quando a falha interromper toda a janela. '
          'Erros locais continuam em CoeloStatePanel ou feedback contextual.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            for (final reference in _references)
              ChoiceChip(
                key: Key('foundation-error-page-option-${reference.code}'),
                label: Text(reference.code),
                selected: _selected == reference,
                onSelected: (_) => setState(() => _selected = reference),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        SizedBox(
          key: const Key('foundation-error-page-preview'),
          height: 360,
          child: _ErrorPagePreview(reference: _selected),
        ),
      ],
    );
  }
}

final class _ErrorPagePreview extends StatelessWidget {
  const _ErrorPagePreview({required this.reference});

  final _ErrorPageReference reference;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: colors.primaryContainer,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final horizontal =
                constraints.maxWidth > CoeloBreakpoints.compact.maxWidth && textScale <= 1.5;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal ? CoeloSpacing.space10 : CoeloSpacing.space4,
                  vertical: CoeloSpacing.space8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        container: true,
                        label: 'Erro ${reference.code}. ${reference.message}',
                        child: ExcludeSemantics(
                          child: horizontal
                              ? IntrinsicHeight(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        reference.code,
                                        style: textTheme.titleMedium?.copyWith(
                                          color: colors.onPrimaryContainer,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: CoeloSpacing.space4,
                                        ),
                                        child: VerticalDivider(color: colors.onPrimaryContainer),
                                      ),
                                      Flexible(
                                        child: Text(
                                          reference.message,
                                          style: textTheme.bodyLarge?.copyWith(
                                            color: colors.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      reference.code,
                                      style: textTheme.titleMedium?.copyWith(
                                        color: colors.onPrimaryContainer,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: CoeloSpacing.space3,
                                      ),
                                      child: Divider(color: colors.onPrimaryContainer),
                                    ),
                                    Text(
                                      reference.message,
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: colors.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: CoeloSpacing.space6),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(foregroundColor: colors.onPrimaryContainer),
                        child: Text(reference.actionLabel),
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

final class _ErrorPageReference {
  const _ErrorPageReference({required this.code, required this.message, required this.actionLabel});

  final String code;
  final String message;
  final String actionLabel;
}

const _references = [
  _ErrorPageReference(
    code: '403',
    message: 'Você não tem permissão para acessar esta área.',
    actionLabel: 'Voltar ao início',
  ),
  _ErrorPageReference(
    code: '404',
    message: 'Não encontramos a página que você procura.',
    actionLabel: 'Voltar ao início',
  ),
  _ErrorPageReference(
    code: '500',
    message: 'Não foi possível concluir esta ação.',
    actionLabel: 'Tentar novamente',
  ),
  _ErrorPageReference(
    code: '503',
    message: 'O Coelo está temporariamente indisponível.',
    actionLabel: 'Tentar novamente',
  ),
];
