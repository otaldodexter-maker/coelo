// ignore_for_file: deprecated_member_use

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/import_job.dart';
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
        final compact = constraints.maxWidth < CoeloBreakpoints.large.minWidth;
        final steps = [
          'Entidade e contexto',
          'Arquivo',
          'Mapeamento',
          'Estratégia',
          'Prévia e conflitos',
          'Confirmação',
        ];
        final body = _StepBody(controller: widget.controller);
        return Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nova importação', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space2),
              if (compact) _CompactSteps(current: widget.controller.currentStep, steps: steps),
              const SizedBox(height: CoeloSpacing.space4),
              Expanded(
                child: compact
                    ? body
                    : Row(
                        children: [
                          SizedBox(
                            width: 220,
                            child: _SideSteps(current: widget.controller.currentStep, steps: steps),
                          ),
                          const SizedBox(width: CoeloSpacing.space6),
                          Expanded(child: body),
                        ],
                      ),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              _Footer(
                controller: widget.controller,
                onFinished: widget.onFinished,
                compact: compact,
              ),
            ],
          ),
        );
      },
    ),
  );
}

final class _CompactSteps extends StatelessWidget {
  const _CompactSteps({required this.current, required this.steps});
  final int current;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => Text(
    'Etapa ${current + 1} de ${steps.length}: ${steps[current]}',
    style: Theme.of(context).textTheme.titleSmall,
  );
}

final class _SideSteps extends StatelessWidget {
  const _SideSteps({required this.current, required this.steps});
  final int current;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: steps.length,
    itemBuilder: (_, index) => ListTile(
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text(steps[index]),
      selected: index == current,
    ),
  );
}

final class _StepBody extends StatelessWidget {
  const _StepBody({required this.controller});
  final ImportWizardController controller;
  @override
  Widget build(BuildContext context) {
    final draft = controller.draft;
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: switch (controller.currentStep) {
          0 => _EntityStep(controller: controller),
          1 => _FileStep(controller: controller),
          2 => _MappingStep(draft: draft),
          3 => _StrategyStep(controller: controller),
          4 => _PreviewStep(draft: draft),
          _ => _ConfirmationStep(controller: controller, draft: draft),
        },
      ),
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
            children: ImportEntity.values
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
      Text('Selecione o tipo de arquivo.', style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<ImportFileFixture>(
        label: 'Formato',
        value: controller.file,
        options: ImportFileFixture.values,
        optionLabel: (value) => value.name.toUpperCase(),
        onChanged: controller.selectFile,
        searchable: false,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      OutlinedButton.icon(
        onPressed: controller.downloadTemplate,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Baixar modelo'),
      ),
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
        if (job.status == ImportJobStatus.completed) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Text(
            'Resultado: ${job.result.created} criados, ${job.result.updated} atualizados, ${job.result.ignored} ignorados e ${job.result.rejected} rejeitados.',
          ),
        ],
      ],
    );
  }
}

final class _Footer extends StatelessWidget {
  const _Footer({required this.controller, required this.onFinished, required this.compact});
  final ImportWizardController controller;
  final VoidCallback onFinished;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final confirming = controller.currentStep == 5;
    final complete = controller.job?.status == ImportJobStatus.completed;
    final primary = FilledButton(
      key: const Key('import-wizard-primary'),
      onPressed: complete
          ? onFinished
          : confirming
          ? controller.confirm
          : controller.next,
      child: Text(
        complete
            ? 'Voltar às importações'
            : confirming
            ? 'Confirmar importação'
            : 'Continuar',
      ),
    );
    final secondary = OutlinedButton(
      onPressed: controller.currentStep == 0 ? null : controller.previous,
      child: const Text('Voltar'),
    );
    return compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: CoeloSpacing.space2),
              secondary,
            ],
          )
        : Row(children: [secondary, const Spacer(), primary]);
  }
}
