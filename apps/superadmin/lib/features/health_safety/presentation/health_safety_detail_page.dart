import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/health_safety.dart';
import 'health_safety_controller.dart';
import 'health_safety_forms.dart';

final class HealthSafetyDetailPage extends StatefulWidget {
  const HealthSafetyDetailPage({
    required this.controller,
    required this.childId,
    required this.logout,
    this.onEditMedication,
    this.onEditAllergy,
    this.onEditCareProfile,
    super.key,
  });

  final HealthSafetyController controller;
  final String childId;
  final LogoutAction logout;
  final ValueChanged<String>? onEditMedication;
  final ValueChanged<String>? onEditAllergy;
  final VoidCallback? onEditCareProfile;

  @override
  State<HealthSafetyDetailPage> createState() => _HealthSafetyDetailPageState();
}

final class _HealthSafetyDetailPageState extends State<HealthSafetyDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.loadDetail(widget.childId);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HealthSafetyDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final childChanged = oldWidget.childId != widget.childId;
    if (controllerChanged) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (controllerChanged || childChanged) {
      Future.microtask(() => widget.controller.loadDetail(widget.childId));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'health-safety',
    title: 'Saúde e Segurança',
    subtitle: 'Detalhe sensível centrado na criança.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: _body(context, padding),
          ),
        );
      },
    ),
  );

  Widget _body(BuildContext context, double padding) {
    if (widget.controller.state == HealthSafetyLoadState.loading) {
      return const CoeloStatePanel(
        title: 'Carregando',
        message: 'Buscando detalhe sensível.',
        loading: true,
      );
    }
    if (widget.controller.state == HealthSafetyLoadState.minimized) {
      return const Padding(
        padding: EdgeInsets.all(CoeloSpacing.space6),
        child: CoeloStatePanel(
          title: 'Resumo minimizado',
          message:
              'Este perfil recebe apenas contagens, pendências e status; detalhes sensíveis foram omitidos.',
        ),
      );
    }
    if (widget.controller.state == HealthSafetyLoadState.unauthorized) {
      return const CoeloStatePanel(
        title: 'Sem permissão',
        message: 'O contexto ativo não autoriza dados sensíveis desta criança.',
      );
    }
    if (widget.controller.state == HealthSafetyLoadState.error) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Tente novamente.',
        actionLabel: 'Tentar novamente',
        onAction: () => widget.controller.loadDetail(widget.childId),
      );
    }
    final child = widget.controller.detail;
    if (child == null) {
      return const CoeloStatePanel(
        title: 'Registro não encontrado',
        message: 'Não há detalhe disponível.',
      );
    }
    final sections = <Widget>[
      _header(context, child),
      _medications(context, child),
      _allergies(context, child),
      _care(context, child),
    ];
    return CustomScrollView(
      key: const Key('health-safety-detail-scroll'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(padding),
          sliver: SliverList.separated(
            itemCount: sections.length,
            itemBuilder: (_, index) => sections[index],
            separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space4),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, HealthSafetyChild child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        color: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Wrap(
            spacing: CoeloSpacing.space4,
            runSpacing: CoeloSpacing.space3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.science_outlined),
              const Text('Demonstração local'),
              Chip(label: Text('Perfil: ${_detailProfileLabel(widget.controller.profile)}')),
              Text(
                widget.controller.isReadOnly ? 'Somente leitura' : 'Correção excepcional auditada',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      LayoutBuilder(
        builder: (context, constraints) {
          final avatar = CoeloAvatar(
            semanticLabel: 'Avatar de ${child.displayName}',
            initials: 'CD',
            size: CoeloAvatarSize.large,
          );
          final labels = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(child.displayName, style: Theme.of(context).textTheme.headlineSmall),
              const Text('Pessoa global • cadastro demonstrativo'),
            ],
          );
          return constraints.maxWidth < CoeloBreakpoints.medium.minWidth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(height: CoeloSpacing.space3),
                    labels,
                  ],
                )
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: CoeloSpacing.space4),
                    Expanded(child: labels),
                  ],
                );
        },
      ),
      const SizedBox(height: CoeloSpacing.space3),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final link in child.links.where((link) => link.active && link.authorized))
            Chip(
              label: Text(
                '${_institutionLabel(link.institutionId)} → ${_unitLabel(link.unitId)} → ${_groupLabel(link.groupOrActivityId)}',
              ),
            ),
        ],
      ),
    ],
  );

  Widget _medications(BuildContext context, HealthSafetyChild child) => _SurfaceCard(
    title: 'Medicamentos',
    subtitle: 'Ciclo, horários exatos, responsáveis e administrações.',
    action: widget.controller.canEdit
        ? TextButton.icon(
            key: const Key('health-medication-create'),
            onPressed: () => _createMedication(child),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar'),
          )
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final medication in child.medications) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${medication.currentVersion.name} • ${medication.currentVersion.dose} ${medication.currentVersion.doseUnit} • ${medication.currentVersion.route}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (widget.controller.canEdit)
                TextButton(
                  key: Key('health-medication-correct-${medication.id}'),
                  onPressed: () {
                    final callback = widget.onEditMedication;
                    if (callback != null) {
                      callback(medication.id);
                    } else {
                      _correctMedication(child, medication);
                    }
                  },
                  child: const Text('Corrigir'),
                ),
            ],
          ),
          Text(
            'Status: ${_reviewStatusLabel(medication.currentVersion.status)} • frequência ${medication.currentVersion.frequencyPerDay}x/dia',
          ),
          for (final schedule in medication.currentVersion.schedules)
            Text(
              '${_time(schedule.time)} • ${schedule.atHome ? 'Casa' : _institutionLabel(schedule.institutionId!)}',
            ),
        ],
        const SizedBox(height: CoeloSpacing.space3),
        const Text(
          'Responsáveis/assignees: profissional demo professor e profissional demo enfermagem',
        ),
        for (final dose in child.doses)
          Text(
            '${_dateTime(dose.dueAt)} • ${_doseSituationLabel(dose.situation)}${dose.claimedBy == null ? '' : ' • administração assumida'}${dose.reason == null ? '' : ' • motivo: ${dose.reason}'}',
          ),
        const SizedBox(height: CoeloSpacing.space2),
        const Text(
          'Estados demonstrados: claim/conflito, atrasada, recusada, pausada e administrada.',
        ),
      ],
    ),
  );

  Widget _allergies(BuildContext context, HealthSafetyChild child) => _SurfaceCard(
    title: 'Alergias e restrições',
    subtitle: 'Itens ativos entram em vigor imediatamente e preservam histórico.',
    action: widget.controller.canEdit
        ? TextButton.icon(
            key: const Key('health-allergy-create'),
            onPressed: () => _createAllergy(child),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar'),
          )
        : null,
    child: Column(
      children: [
        for (final allergy in child.allergies)
          Card(
            color: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              side: BorderSide(
                color: allergy.active && allergy.type == HealthSafetyAllergyType.medication
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: allergy.active && allergy.type == HealthSafetyAllergyType.medication
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              title: Text(allergy.label),
              subtitle: Text(
                '${_allergyTypeLabel(allergy.type)} • ${allergy.active ? 'Ativa e proeminente' : 'Inativa'}',
              ),
              trailing: widget.controller.canEdit && allergy.active
                  ? TextButton(
                      key: Key('health-allergy-inactivate-${allergy.id}'),
                      onPressed: () {
                        final callback = widget.onEditAllergy;
                        if (callback != null) {
                          callback(allergy.id);
                        } else {
                          _inactivateAllergy(child, allergy);
                        }
                      },
                      child: const Text('Inativar'),
                    )
                  : null,
            ),
          ),
      ],
    ),
  );

  Widget _care(BuildContext context, HealthSafetyChild child) => _SurfaceCard(
    title: 'Perfil de Cuidado',
    subtitle: 'Linguagem de apoio; não representa diagnóstico.',
    action: widget.controller.canEdit
        ? TextButton(
            onPressed: widget.onEditCareProfile ?? () => _editCareProfile(child),
            child: const Text('Editar'),
          )
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in child.careProfile) Text('• ${_catalogLabel(item)}'),
        const SizedBox(height: CoeloSpacing.space3),
        for (final acknowledgement in child.acknowledgements)
          Text(
            'Ciência ${acknowledgement.receivedAt == null ? 'pendente' : 'concluída'} • ${_acknowledgementLabel(acknowledgement.subject)}',
          ),
      ],
    ),
  );

  Future<void> _createMedication(HealthSafetyChild child) => showHealthMedicationDialog(
    context,
    institutionIds: child.links
        .where((link) => link.active && link.authorized)
        .map((link) => link.institutionId)
        .toSet()
        .toList(),
    onSave: (draft) async {
      await widget.controller.createMedication(
        HealthMedicationCreateCommand(
          childId: child.id,
          name: draft.name,
          dose: draft.dose,
          doseUnit: draft.doseUnit,
          route: draft.route,
          startsAt: draft.startsAt,
          endsAt: draft.endsAt,
          schedules: draft.schedules,
          documentName: draft.documentName,
          documentType: draft.documentType,
        ),
      );
    },
  );

  Future<void> _correctMedication(HealthSafetyChild child, HealthMedication medication) async {
    await showHealthOwnerCorrectionDialog(
      context,
      before: medication.currentVersion.name,
      onSave: (draft) => widget.controller.correctMedication(
        HealthMedicationCorrectionCommand(
          childId: child.id,
          medicationId: medication.id,
          name: draft.after,
          justification: draft.justification,
        ),
      ),
    );
  }

  Future<void> _createAllergy(HealthSafetyChild child) => showHealthAllergyDialog(
    context,
    onSave: (draft) => widget.controller.createAllergy(
      HealthAllergyCreateCommand(childId: child.id, label: draft.label, type: draft.type),
    ),
  );

  Future<void> _inactivateAllergy(HealthSafetyChild child, HealthSafetyAllergy allergy) async {
    await showHealthOwnerCorrectionDialog(
      context,
      before: '${allergy.label} • ativa',
      onSave: (draft) => widget.controller.inactivateAllergy(
        HealthAllergyInactivationCommand(
          childId: child.id,
          allergyId: allergy.id,
          justification: draft.justification,
        ),
      ),
    );
  }

  Future<void> _editCareProfile(HealthSafetyChild child) async {
    HealthSafetyCareProfileItem? selected;
    await showHealthCareProfileDialog(context, onSave: (item) => selected = item);
    if (!mounted || selected == null) return;
    await showHealthOwnerCorrectionDialog(
      context,
      before: child.careProfile.map((item) => item.catalogItemId).join(', '),
      onSave: (draft) => widget.controller.updateCareProfile(
        HealthCareProfileUpdateCommand(
          childId: child.id,
          items: [selected!],
          justification: draft.justification,
        ),
      ),
    );
  }
}

String _detailProfileLabel(DemoHealthSafetyProfile value) => switch (value) {
  DemoHealthSafetyProfile.owner => 'Owner',
  DemoHealthSafetyProfile.sensitiveReader => 'Leitor sensível',
  DemoHealthSafetyProfile.minimized => 'Operador minimizado',
};

final class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
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
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space2,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              ?action,
            ],
          ),
          Text(subtitle),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      ),
    ),
  );
}

String _time(HealthSafetyTimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _catalogLabel(HealthSafetyCareProfileItem item) {
  if (item.catalogItemId == 'other') return item.otherText!;
  return healthSafetyCareProfileCatalog
      .expand((group) => group.items)
      .firstWhere((catalog) => catalog.id == item.catalogItemId)
      .label;
}

String _institutionLabel(String id) => switch (id) {
  'institution-demo-a' => 'Instituição Demo A',
  'institution-demo-b' => 'Instituição Demo B',
  _ => 'Instituição demonstrativa',
};
String _unitLabel(String? id) => switch (id) {
  'unit-demo-a' => 'Unidade Demo A',
  'unit-demo-b' => 'Unidade Demo B',
  _ => 'Sem unidade',
};
String _groupLabel(String? id) => switch (id) {
  'group-demo-a' => 'Grupo Demo A',
  'group-demo-b' => 'Grupo Demo B',
  _ => 'Sem grupo',
};
String _reviewStatusLabel(HealthMedicationReviewStatus value) => switch (value) {
  HealthMedicationReviewStatus.requested => 'Solicitado',
  HealthMedicationReviewStatus.underReview => 'Em análise',
  HealthMedicationReviewStatus.approved => 'Aprovado',
  HealthMedicationReviewStatus.refused => 'Recusado',
  HealthMedicationReviewStatus.active => 'Ativo',
  HealthMedicationReviewStatus.ended => 'Encerrado',
  HealthMedicationReviewStatus.rejected => 'Rejeitado',
  HealthMedicationReviewStatus.invalidated => 'Invalidado',
};
String _doseSituationLabel(HealthMedicationDoseSituation value) => switch (value) {
  HealthMedicationDoseSituation.scheduled => 'Agendada',
  HealthMedicationDoseSituation.claimed => 'Administração assumida',
  HealthMedicationDoseSituation.administered => 'Administrada',
  HealthMedicationDoseSituation.notAdministered => 'Não administrada',
  HealthMedicationDoseSituation.refused => 'Recusada',
  HealthMedicationDoseSituation.paused => 'Pausada',
  HealthMedicationDoseSituation.late => 'Atrasada',
};
String _allergyTypeLabel(HealthSafetyAllergyType value) => switch (value) {
  HealthSafetyAllergyType.medication => 'Medicamentosa',
  HealthSafetyAllergyType.food => 'Alimentar',
  HealthSafetyAllergyType.restriction => 'Restrição',
  HealthSafetyAllergyType.other => 'Outra',
};
String _acknowledgementLabel(HealthSafetyAcknowledgementSubject value) => switch (value) {
  HealthSafetyAcknowledgementSubject.medication => 'Medicamento',
  HealthSafetyAcknowledgementSubject.allergyOrRestriction => 'Alergia ou restrição',
  HealthSafetyAcknowledgementSubject.careProfile => 'Perfil de Cuidado',
};
