import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';

Map<String, CatalogFoundation> buildRejectedVisualPatternsFoundationRegistry() {
  return {
    'pattern.rejected-visual-patterns': CatalogFoundation(
      id: 'pattern.rejected-visual-patterns',
      referencedComponentIds: const [
        'core.form-text-field',
        'admin.single-select-field',
        'admin.flyout',
        'admin.interactive-card',
        'admin.dialog-shell',
      ],
      builder: (_) => const _RejectedVisualPatternsFoundation(),
    ),
  };
}

final class _RejectedVisualPatternsFoundation extends StatelessWidget {
  const _RejectedVisualPatternsFoundation();

  @override
  Widget build(BuildContext context) {
    const groups = <({String rejected, String replacement})>[
      (
        rejected: 'Faixa inteira em cinza para hover ou seleção cinza',
        replacement: 'Classifique a superfície e aplique o estado semântico da família aprovada.',
      ),
      (
        rejected: 'DropdownButton, DropdownButtonFormField, RadioListTile ou CheckboxListTile cru',
        replacement: 'Use os controles Coelo indexados ou registre uma proposta especializada.',
      ),
      (
        rejected: 'showDateRangePicker direto, fullscreen vazio ou dialog truncado',
        replacement:
            'Proponha um seletor responsivo baseado em Popup de Bug, formulários e ações Coelo.',
      ),
      (
        rejected: 'Rodapé inventado, agrupado ou desalinhado',
        replacement: 'Use Criar/Editar instituição: saída à esquerda e continuidade à direita.',
      ),
      (
        rejected: 'Cards encostados, zero gap e seções sem respiro',
        replacement: 'Separe superfícies e seções com gaps tokenizados de CoeloSpacing.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nunca usar como padrão Coelo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space2),
        const Text(
          'Os exemplos rejeitados são diagnóstico de regressão. Não os renderize '
          'como demonstração e não use defaults Material para preencher lacunas.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        for (final group in groups) ...[
          _RejectedPatternRow(rejected: group.rejected, replacement: group.replacement),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        const Text(
          'Antes de criar, refazer, refatorar ou corrigir: declare uma baseline entre '
          'Login, Instituições, Home, Menu/Flyouts, Perfil/Configurações, Popup de Bug '
          'e Criar/Editar instituição. Compare estado, widget, seção e página inteira.',
        ),
      ],
    );
  }
}

final class _RejectedPatternRow extends StatelessWidget {
  const _RejectedPatternRow({required this.rejected, required this.replacement});

  final String rejected;
  final String replacement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rejected, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CoeloSpacing.space2),
            Text(replacement),
          ],
        ),
      ),
    );
  }
}
