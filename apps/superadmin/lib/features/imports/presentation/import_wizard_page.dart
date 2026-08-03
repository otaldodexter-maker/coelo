// ignore_for_file: deprecated_member_use

import 'package:coelo_tokens/coelo_tokens.dart';
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
      Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space3,
        children: ImportEntity.values
            .map(
              (entity) => ChoiceChip(
                label: Text(entity.label),
                selected: controller.entity == entity,
                onSelected: (_) => controller.selectEntity(entity),
              ),
            )
            .toList(),
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
      Text('Use um arquivo demonstrativo conhecido.', style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: CoeloSpacing.space4),
      SegmentedButton<ImportFileFixture>(
        segments: const [
          ButtonSegment(value: ImportFileFixture.csv, label: Text('CSV')),
          ButtonSegment(value: ImportFileFixture.xlsx, label: Text('XLSX')),
        ],
        selected: {controller.file},
        onSelectionChanged: (values) => controller.selectFile(values.first),
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
    children: ImportStrategy.values
        .map(
          (strategy) => RadioListTile(
            value: strategy,
            groupValue: controller.strategy,
            onChanged: (_) => controller.selectStrategy(strategy),
            title: Text(strategy.label),
          ),
        )
        .toList(),
  );
}

final class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.draft});
  final ImportJob draft;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Prévia de 8 linhas', style: Theme.of(context).textTheme.titleMedium),
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
