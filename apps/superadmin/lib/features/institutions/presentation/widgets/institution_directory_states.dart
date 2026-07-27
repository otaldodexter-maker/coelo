import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../view_models/institution_directory_view_model.dart';

final class InstitutionDirectoryStates extends StatelessWidget {
  const InstitutionDirectoryStates({
    required this.viewModel,
    required this.successContent,
    super.key,
  });

  final InstitutionDirectoryViewModel viewModel;
  final Widget successContent;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.state) {
      case InstitutionDirectoryLoadState.initial:
      case InstitutionDirectoryLoadState.loading:
        return const Padding(
          padding: EdgeInsets.all(CoeloSpacing.space8),
          child: Center(child: CircularProgressIndicator()),
        );
      case InstitutionDirectoryLoadState.failure:
        return _MessageCard(
          icon: Icons.error_outline,
          message: viewModel.errorMessage ?? InstitutionDirectoryViewModel.genericErrorMessage,
          actionLabel: 'Tentar novamente',
          onAction: viewModel.retry,
        );
      case InstitutionDirectoryLoadState.unauthorized:
        return _MessageCard(
          icon: Icons.lock_outline,
          message: viewModel.errorMessage ?? InstitutionDirectoryViewModel.unauthorizedMessage,
        );
      case InstitutionDirectoryLoadState.empty:
        return const _MessageCard(
          icon: Icons.apartment_outlined,
          message: 'Ainda não há instituições cadastradas.',
        );
      case InstitutionDirectoryLoadState.noResults:
        return const _MessageCard(
          icon: Icons.search_off_outlined,
          message: 'Nenhuma instituição encontrada com estes filtros.',
        );
      case InstitutionDirectoryLoadState.success:
        return successContent;
    }
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: CoeloSize.iconLg),
              const SizedBox(height: CoeloSpacing.space3),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: CoeloSpacing.space3),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
