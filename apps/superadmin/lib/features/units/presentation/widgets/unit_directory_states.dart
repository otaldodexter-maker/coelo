import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../unit_directory_view_model.dart';

final class UnitDirectoryStates extends StatelessWidget {
  const UnitDirectoryStates({
    required this.viewModel,
    required this.createAction,
    required this.successContent,
    super.key,
  });

  final UnitDirectoryViewModel viewModel;
  final Widget createAction;
  final Widget successContent;

  @override
  Widget build(BuildContext context) {
    return switch (viewModel.state) {
      UnitDirectoryLoadState.initial || UnitDirectoryLoadState.loading => const Padding(
        padding: EdgeInsets.all(CoeloSpacing.space8),
        child: Center(child: CircularProgressIndicator()),
      ),
      UnitDirectoryLoadState.failure => _withCreateAction(
        _MessageCard(
          icon: Icons.error_outline,
          message: 'Não foi possível carregar as unidades. Tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: viewModel.retry,
        ),
      ),
      UnitDirectoryLoadState.unauthorized => const _MessageCard(
        icon: Icons.lock_outline,
        message: 'Você não tem permissão para ver as unidades.',
      ),
      UnitDirectoryLoadState.empty => _withCreateAction(
        const _MessageCard(
          icon: Icons.apartment_outlined,
          message: 'Ainda não há unidades cadastradas.',
        ),
      ),
      UnitDirectoryLoadState.noResults => _withCreateAction(
        const _MessageCard(
          icon: Icons.search_off_outlined,
          message: 'Nenhuma unidade encontrada com estes filtros.',
        ),
      ),
      UnitDirectoryLoadState.success => successContent,
    };
  }

  Widget _withCreateAction(Widget stateContent) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      createAction,
      const SizedBox(height: CoeloSpacing.space4),
      stateContent,
    ],
  );
}

final class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: CoeloSize.iconLg),
            const SizedBox(height: CoeloSpacing.space3),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel case final label?) ...[
              const SizedBox(height: CoeloSpacing.space3),
              OutlinedButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    ),
  );
}
