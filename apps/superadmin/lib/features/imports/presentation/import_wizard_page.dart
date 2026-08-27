// ignore_for_file: deprecated_member_use

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/import_job.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'import_wizard_controller.dart';

final class ImportWizardPage extends StatefulWidget {
  const ImportWizardPage({required this.controller, required this.onFinished, super.key});
  final ImportWizardController controller;
  final VoidCallback onFinished;
  @override
  State<ImportWizardPage> createState() => _ImportWizardPageState();
}

final class _ImportWizardPageState extends State<ImportWizardPage> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final steps = const [
          'Entidade e contexto',
          'Arquivo',
          'Mapeamento',
          'Estratégia',
          'Prévia e conflitos',
          'Confirmação',
        ];
        final controller = widget.controller;
        final currentStep = controller.currentStep;
        final isConfirmation = currentStep == steps.length - 1;
        final isComplete = controller.job?.status.isTerminal ?? false;
        final primaryLabel = isComplete
            ? 'Voltar às importações'
            : isConfirmation
            ? 'Confirmar importação'
            : 'Continuar';
        return SuperadminFormFrame(
          viewportWidth: constraints.maxWidth,
          navigation: SuperadminFormStepNavigation(
            currentIndex: currentStep,
            onStepSelected: controller.goToStep,
            steps: [
              for (var index = 0; index < steps.length; index++)
                SuperadminFormStep(
                  label: steps[index],
                  enabled: index <= currentStep,
                  status: index < currentStep
                      ? SuperadminFormStepStatus.complete
                      : index == currentStep
                      ? SuperadminFormStepStatus.current
                      : SuperadminFormStepStatus.incomplete,
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nova importação', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space4),
              _StepBody(controller: controller),
            ],
          ),
          footer: SuperadminFormActionFooter(
            tertiaryAction: TextButton(onPressed: widget.onFinished, child: const Text('Cancelar')),
            continuationActions: [
              OutlinedButton(
                onPressed: currentStep == 0 ? null : controller.previous,
                child: const Text('Anterior'),
              ),
              FilledButton(
                key: const Key('import-wizard-primary'),
                onPressed: isComplete
                    ? widget.onFinished
                    : isConfirmation
                    ? (controller.canConfirm ? controller.confirm : null)
                    : controller.next,
                child: Text(primaryLabel),
              ),
            ],
          ),
        );
      },
    ),
  );
}

final class _StepBody extends StatelessWidget {
  const _StepBody({required this.controller});
  final ImportWizardController controller;
  @override
  Widget build(BuildContext context) {
    Widget withDraft() => FutureBuilder<ImportJob>(
      future: controller.preparedDraft,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.none) {
          return const Center(child: Text('Prepare a importação para continuar.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Não foi possível preparar a prévia. Tente novamente.'));
        }
        final resolvedDraft = snapshot.data!;
        return switch (controller.currentStep) {
          2 => _MappingStep(draft: resolvedDraft),
          4 => _PreviewStep(draft: resolvedDraft),
          _ => _ConfirmationStep(controller: controller, draft: resolvedDraft),
        };
      },
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: switch (controller.currentStep) {
        0 => _EntityStep(controller: controller),
        1 => _FileStep(controller: controller),
        2 => withDraft(),
        3 => _StrategyStep(controller: controller),
        4 => withDraft(),
        _ => withDraft(),
      },
    );
  }
}

final class _EntityStep extends StatelessWidget {
  const _EntityStep({required this.controller});
  final ImportWizardController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Escolha a entidade e o contexto de destino.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > CoeloBreakpoints.medium.minWidth ? 2 : 1;
          final optionWidth = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - CoeloSpacing.space3) / 2;
          return Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space3,
            children: ImportWizardController.supportedEntities
                .map(
                  (entity) => SizedBox(
                    width: optionWidth,
                    child: _ImportWizardOptionTile(
                      label: entity.label,
                      subtitle: entity.matchingKey,
                      selected: controller.entity == entity,
                      onTap: () => controller.selectEntity(entity),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: CoeloSpacing.space4),
      Text('Destino: ${controller.context}'),
    ],
  );
}

final class _FileStep extends StatelessWidget {
  const _FileStep({required this.controller});
  final ImportWizardController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Selecione o arquivo real para processamento.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      OutlinedButton.icon(
        key: const Key('import-source-file-picker'),
        onPressed: controller.selectingFile ? null : controller.pickSourceFile,
        icon: controller.selectingFile
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file_rounded),
        label: Text(controller.selectingFile ? 'Abrindo...' : 'Selecionar CSV ou XLSX'),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      if (controller.sourceFile case final source?)
        Semantics(
          label: 'Arquivo selecionado: ${source.name}. Formato: ${source.mimeType}.',
          child: DecoratedBox(
            key: const Key('import-selected-file'),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(source.mimeType, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        const Text('Nenhum arquivo selecionado. Limite: 5 MB e 5.000 linhas.'),
      if (controller.sourceFileError case final error?) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ],
  );
}

final class _MappingStep extends StatelessWidget {
  const _MappingStep({required this.draft});
  final ImportJob draft;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Chave de correspondência: ${draft.entity.matchingKey}'),
      const SizedBox(height: CoeloSpacing.space4),
      ...draft.mapping.entries.map(
        (entry) => ListTile(
          leading: const Icon(Icons.arrow_forward_rounded),
          title: Text(entry.key),
          trailing: Text(entry.value),
        ),
      ),
    ],
  );
}

final class _StrategyStep extends StatelessWidget {
  const _StrategyStep({required this.controller});
  final ImportWizardController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Escolha como tratar registros existentes.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      ...ImportStrategy.values.map(
        (strategy) => Padding(
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
          child: _ImportWizardOptionTile(
            label: strategy.label,
            subtitle: strategy == ImportStrategy.createOnly
                ? 'Mantém novos registros e ignora possíveis duplicidades.'
                : 'Atualiza registros existentes e mantém histórico.',
            selected: controller.strategy == strategy,
            onTap: () => controller.selectStrategy(strategy),
          ),
        ),
      ),
    ],
  );
}

final class _ImportWizardOptionTile extends StatelessWidget {
  const _ImportWizardOptionTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedColor = selected ? colors.primary : colors.outline;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${selected ? 'selecionado' : 'não selecionado'}',
      child: CoeloAdminInteractiveCard(
        onPressed: onTap,
        minHeight: 84,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selectedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.draft});
  final ImportJob draft;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Prévia de 8 linhas', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space2),
      ...draft.previewRows.map(
        (row) => ListTile(
          title: Text('Linha ${row.row} · ${row.values['nome']}'),
          subtitle: Text(row.values['codigo']!),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      Text('Conflitos', style: Theme.of(context).textTheme.titleMedium),
      ...draft.conflicts.map(
        (conflict) => ListTile(
          leading: const Icon(Icons.warning_amber_rounded),
          title: Text('Linha ${conflict.row}: ${conflict.field}'),
          subtitle: Text(conflict.reason),
        ),
      ),
    ],
  );
}

final class _ConfirmationStep extends StatelessWidget {
  const _ConfirmationStep({required this.controller, required this.draft});
  final ImportWizardController controller;
  final ImportJob draft;
  @override
  Widget build(BuildContext context) {
    final job = controller.job;
    if (job == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revise e confirme a importação.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: CoeloSpacing.space3),
          Text('${draft.entity.label} · ${draft.file.fileName} · ${draft.strategy.label}'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acompanhamento: ${job.progress}%', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
        LinearProgressIndicator(value: job.progress / 100),
        if (job.status.isTerminal) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Text(
            'Resultado: ${job.result.created} criados, ${job.result.updated} atualizados, ${job.result.ignored} ignorados e ${job.result.rejected} rejeitados.',
          ),
        ],
      ],
    );
  }
}
