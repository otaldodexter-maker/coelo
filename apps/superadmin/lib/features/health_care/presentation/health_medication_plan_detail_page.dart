import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'health_care_responsive_surface.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/health_care.dart';
import 'health_care_controller.dart';

final class HealthMedicationPlanDetailPage extends StatefulWidget {
  const HealthMedicationPlanDetailPage({
    required this.controller,
    required this.medicationId,
    required this.logout,
    this.onEdit,
    super.key,
  });

  final HealthCareController controller;
  final String medicationId;
  final LogoutAction logout;
  final VoidCallback? onEdit;

  @override
  State<HealthMedicationPlanDetailPage> createState() => _HealthMedicationPlanDetailPageState();
}

final class _HealthMedicationPlanDetailPageState extends State<HealthMedicationPlanDetailPage> {
  HealthCareChild? _child;
  HealthMedication? _medication;
  var _loading = true;
  var _currentSection = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final childId in const ['child-demo-a', 'child-demo-b']) {
      final child = await widget.controller.repository.findChild(
        childId,
        actor: widget.controller.actor,
      );
      if (child == null) continue;
      for (final medication in child.medications) {
        if (medication.id == widget.medicationId) {
          if (!mounted) return;
          setState(() {
            _child = child;
            _medication = medication;
            _loading = false;
          });
          return;
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'health-medication-plans',
    title: 'Plano de medicação',
    subtitle: 'Vigência, horários e registros de doses.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        if (_loading) {
          return const CoeloStatePanel(
            title: 'Carregando',
            message: 'Buscando o plano local.',
            loading: true,
          );
        }
        final child = _child;
        final medication = _medication;
        if (child == null || medication == null) {
          return const CoeloStatePanel(
            title: 'Plano não encontrado',
            message: 'O registro solicitado não existe nesta demonstração.',
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: _content(context, child, medication, padding),
          ),
        );
      },
    ),
  ).withHealthCareResponsiveSurface();

  Widget _content(
    BuildContext context,
    HealthCareChild child,
    HealthMedication medication,
    double padding,
  ) {
    final version = medication.currentVersion;
    final doses = child.doses
        .where((dose) => dose.medicationVersionId == version.id)
        .toList(growable: false);
    final steps = <SuperadminFormStep>[
      for (var index = 0; index < _sectionLabels.length; index++)
        SuperadminFormStep(
          label: _sectionLabels[index],
          status: index == _currentSection
              ? SuperadminFormStepStatus.current
              : SuperadminFormStepStatus.incomplete,
        ),
    ];
    return SingleChildScrollView(
      key: const Key('health-medication-detail-scroll'),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlanHeader(
            childName: child.displayName,
            medicationName: version.name,
            onBack: () => Navigator.of(context).maybePop(),
            onEdit: widget.onEdit,
          ),
          const SizedBox(height: CoeloSpacing.space6),
          LayoutBuilder(
            builder: (context, constraints) {
              final navigation = SuperadminFormStepNavigation(
                steps: steps,
                currentIndex: _currentSection,
                onStepSelected: _selectSection,
              );
              final section = _section(context, version, doses);
              if (constraints.maxWidth >= CoeloBreakpoints.medium.minWidth) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    navigation,
                    const SizedBox(width: CoeloSpacing.space6),
                    Expanded(child: section),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  navigation,
                  const SizedBox(height: CoeloSpacing.space4),
                  section,
                  const SizedBox(height: CoeloSpacing.space4),
                  _compactSectionActions(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _selectSection(int index) => setState(() => _currentSection = index);

  Widget _section(
    BuildContext context,
    HealthMedicationVersion version,
    List<HealthMedicationDose> doses,
  ) => switch (_currentSection) {
    0 => _summary(context, version),
    1 => _agenda(context, version),
    _ => _doseRecords(context, doses),
  };

  Widget _compactSectionActions() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('health-medication-detail-previous-section'),
          onPressed: _currentSection == 0 ? null : () => _selectSection(_currentSection - 1),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Anterior'),
        ),
      ),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('health-medication-detail-next-section'),
          onPressed: _currentSection == _sectionLabels.length - 1
              ? null
              : () => _selectSection(_currentSection + 1),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Próxima'),
        ),
      ),
    ],
  );

  Widget _summary(BuildContext context, HealthMedicationVersion version) {
    final status = _statusPresentation(context, version.status);
    return _DetailSection(
      title: 'Resumo',
      subtitle: 'Medicamento, dose e vigência atual do plano.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoeloStatusChip(
            label: status.label,
            icon: status.icon,
            backgroundColor: status.background,
            foregroundColor: status.foreground,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Wrap(
            spacing: CoeloSpacing.space4,
            runSpacing: CoeloSpacing.space3,
            children: [
              Text('Dose: ${version.dose} ${version.doseUnit}'),
              Text('Via: ${version.route}'),
              Text('Vigência: ${_dateLabel(version.startsAt)} — ${_dateLabel(version.endsAt)}'),
            ],
          ),
          if (version.prescriptionReference case final prescription?) ...[
            const SizedBox(height: CoeloSpacing.space4),
            Text('Documento: $prescription'),
          ],
        ],
      ),
    );
  }

  Widget _agenda(BuildContext context, HealthMedicationVersion version) => _DetailSection(
    title: 'Agenda e responsáveis',
    subtitle: 'Horários, contextos e responsáveis pela administração.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final schedule in version.schedules)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule_outlined),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Text(
                    '${_timeLabel(schedule.time)} • '
                    '${schedule.atHome ? 'Em casa' : _institutionLabel(schedule.institutionId)}',
                  ),
                ),
              ],
            ),
          ),
        if (version.policy case final policy?) ...[
          const Divider(height: CoeloSpacing.space6),
          Text('Responsáveis', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space2),
          Text(policy.recipientIds.map(_responsibleLabel).join(', ')),
        ],
      ],
    ),
  );

  Widget _doseRecords(BuildContext context, List<HealthMedicationDose> doses) => _DetailSection(
    title: 'Registros de dose',
    subtitle: 'Histórico periódico deste plano.',
    child: doses.isEmpty
        ? const Text('Nenhuma dose registrada.')
        : Column(
            children: [
              for (var index = 0; index < doses.length; index++) ...[
                if (index > 0) const Divider(height: CoeloSpacing.space6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.medication_outlined),
                    const SizedBox(width: CoeloSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_dateTimeLabel(doses[index].dueAt)),
                          const SizedBox(height: CoeloSpacing.space1),
                          Text(_doseSituationLabel(doses[index].situation)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
  );
}

const _sectionLabels = ['Resumo', 'Agenda e responsáveis', 'Registros de dose'];

final class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.childName,
    required this.medicationName,
    required this.onBack,
    required this.onEdit,
  });

  final String childName;
  final String medicationName;
  final VoidCallback onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(childName, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Text(medicationName),
            ],
          );
          final actions = Wrap(
            alignment: WrapAlignment.end,
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              if (onEdit != null)
                FilledButton.icon(
                  key: const Key('health-medication-detail-edit'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar plano'),
                ),
            ],
          );
          if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: CoeloSpacing.space4),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: CoeloSpacing.space4),
              Flexible(child: actions),
            ],
          );
        },
      ),
    ),
  );
}

final class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(subtitle),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      ),
    ),
  );
}

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _dateTimeLabel(DateTime value) =>
    '${_dateLabel(value)} • ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _timeLabel(HealthCareTimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _institutionLabel(String? id) => switch (id) {
  'institution-demo-a' => 'Instituição Demo A',
  'institution-demo-b' => 'Instituição Demo B',
  _ => 'Instituição demonstrativa',
};

String _responsibleLabel(String id) => switch (id) {
  'professional-demo-professor' => 'Professor Demo',
  'professional-demo-nurse' => 'Enfermagem Demo',
  _ => 'Profissional demonstrativo',
};

({String label, IconData icon, Color background, Color foreground}) _statusPresentation(
  BuildContext context,
  HealthMedicationReviewStatus status,
) {
  final theme = Theme.of(context);
  final colors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  final semantic = switch (status) {
    HealthMedicationReviewStatus.requested || HealthMedicationReviewStatus.underReview => (
      Icons.info_outline_rounded,
      colors.infoContainer,
      colors.onInfoContainer,
    ),
    HealthMedicationReviewStatus.approved || HealthMedicationReviewStatus.active => (
      Icons.check_circle_outline_rounded,
      colors.successContainer,
      colors.onSuccessContainer,
    ),
    HealthMedicationReviewStatus.refused || HealthMedicationReviewStatus.rejected => (
      Icons.block_rounded,
      colors.errorContainer,
      colors.onErrorContainer,
    ),
    HealthMedicationReviewStatus.ended || HealthMedicationReviewStatus.invalidated => (
      Icons.history_rounded,
      colors.historyContainer,
      colors.onHistoryContainer,
    ),
  };
  return (
    label: _statusLabel(status),
    icon: semantic.$1,
    background: semantic.$2,
    foreground: semantic.$3,
  );
}

String _statusLabel(HealthMedicationReviewStatus value) => switch (value) {
  HealthMedicationReviewStatus.requested => 'Solicitado',
  HealthMedicationReviewStatus.underReview => 'Em revisão',
  HealthMedicationReviewStatus.approved => 'Aprovado',
  HealthMedicationReviewStatus.refused => 'Recusado',
  HealthMedicationReviewStatus.active => 'Ativo',
  HealthMedicationReviewStatus.ended => 'Encerrado',
  HealthMedicationReviewStatus.rejected => 'Rejeitado',
  HealthMedicationReviewStatus.invalidated => 'Invalidado',
};

String _doseSituationLabel(HealthMedicationDoseSituation value) => switch (value) {
  HealthMedicationDoseSituation.scheduled => 'Agendada',
  HealthMedicationDoseSituation.claimed => 'Assumida',
  HealthMedicationDoseSituation.administered => 'Administrada',
  HealthMedicationDoseSituation.notAdministered => 'Não administrada',
  HealthMedicationDoseSituation.refused => 'Recusada',
  HealthMedicationDoseSituation.paused => 'Pausada',
  HealthMedicationDoseSituation.late => 'Atrasada',
};
