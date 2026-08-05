import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
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
    title: 'Plano de medica\u00e7\u00e3o',
    subtitle: 'Vig\u00eancia, hor\u00e1rios e registros de doses.',
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
            title: 'Plano n\u00e3o encontrado',
            message: 'O registro solicitado n\u00e3o existe nesta demonstra\u00e7\u00e3o.',
          );
        }
        final version = medication.currentVersion;
        final doses = child.doses
            .where((dose) => dose.medicationVersionId == version.id)
            .toList(growable: false);
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailSection(
                    title: child.displayName,
                    subtitle: version.name,
                    action: widget.onEdit == null
                        ? null
                        : OutlinedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar plano'),
                          ),
                    child: Wrap(
                      spacing: CoeloSpacing.space2,
                      runSpacing: CoeloSpacing.space2,
                      children: [
                        Chip(label: Text(_statusLabel(version.status))),
                        Chip(label: Text('Dose: ${version.dose} ${version.doseUnit}')),
                        Chip(label: Text('Via: ${version.route}')),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _DetailSection(
                    title: 'Vig\u00eancia',
                    subtitle: 'Per\u00edodo autorizado para este plano.',
                    child: Text(
                      '${_dateLabel(version.startsAt)} \u2014 ${_dateLabel(version.endsAt)}',
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _DetailSection(
                    title: 'Hor\u00e1rios e respons\u00e1veis',
                    subtitle: 'Agenda e contexto de administra\u00e7\u00e3o.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final schedule in version.schedules)
                          Padding(
                            padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_outlined),
                                const SizedBox(width: CoeloSpacing.space2),
                                Expanded(
                                  child: Text(
                                    '${_timeLabel(schedule.time)} \u2022 '
                                    '${schedule.atHome ? 'Em casa' : 'Na institui\u00e7\u00e3o'}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _DetailSection(
                    title: 'Registros de doses',
                    subtitle: 'Hist\u00f3rico peri\u00f3dico deste plano.',
                    child: doses.isEmpty
                        ? const Text('Nenhuma dose registrada.')
                        : Column(
                            children: [
                              for (final dose in doses)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.medication_outlined),
                                  title: Text(_dateTimeLabel(dose.dueAt)),
                                  subtitle: Text(_doseSituationLabel(dose.situation)),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

final class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(subtitle),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _dateTimeLabel(DateTime value) =>
    '${_dateLabel(value)} \u2022 ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _timeLabel(HealthCareTimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _statusLabel(HealthMedicationReviewStatus value) => switch (value) {
  HealthMedicationReviewStatus.requested => 'Solicitado',
  HealthMedicationReviewStatus.underReview => 'Em revis\u00e3o',
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
  HealthMedicationDoseSituation.notAdministered => 'N\u00e3o administrada',
  HealthMedicationDoseSituation.refused => 'Recusada',
  HealthMedicationDoseSituation.paused => 'Pausada',
  HealthMedicationDoseSituation.late => 'Atrasada',
};
