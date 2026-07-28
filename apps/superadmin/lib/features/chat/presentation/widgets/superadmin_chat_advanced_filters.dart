import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_controller.dart';

final class SuperadminChatAdvancedFilters extends StatelessWidget {
  const SuperadminChatAdvancedFilters({required this.controller, super.key});

  final SuperadminChatController controller;

  @override
  Widget build(BuildContext context) {
    const groups = {
      'UF': ['CE', 'SP'],
      'Instituição': ['Centro Horizonte', 'Instituto Aurora'],
      'Unidade': ['Unidade Cambuí', 'Unidade Jardins'],
      'Grupo/Turma': ['Turma Girassol'],
      'Papel': ['Professores', 'Responsáveis'],
    };
    final selected = controller.activeFilters;
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CoeloSize.touchMin * 9),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          children: [
            Row(
              children: [
                Expanded(child: Text('Filtros', style: Theme.of(context).textTheme.titleLarge)),
                TextButton(onPressed: controller.clearFilters, child: const Text('Limpar')),
                IconButton(
                  tooltip: 'Fechar filtros',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            for (final entry in groups.entries) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Text(entry.key, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Wrap(
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space1,
                children: [
                  for (final value in entry.value)
                    FilterChip(
                      label: Text(value),
                      selected: selected.contains(value),
                      onSelected: (_) => controller.toggleFilter(value),
                    ),
                ],
              ),
            ],
            const SizedBox(height: CoeloSpacing.space4),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(CoeloSize.touchMin)),
              child: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}
