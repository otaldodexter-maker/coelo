import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'health_care_responsive_surface.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/health_care.dart';
import 'health_care_controller.dart';

final class HealthCareProfileDetailPage extends StatefulWidget {
  const HealthCareProfileDetailPage({
    required this.controller,
    required this.childId,
    required this.logout,
    this.onEditCareProfile,
    this.onMedicationPlans,
    super.key,
  });

  final HealthCareController controller;
  final String childId;
  final LogoutAction logout;
  final VoidCallback? onEditCareProfile;
  final VoidCallback? onMedicationPlans;

  @override
  State<HealthCareProfileDetailPage> createState() => _HealthCareProfileDetailPageState();
}

final class _HealthCareProfileDetailPageState extends State<HealthCareProfileDetailPage> {
  var _currentSection = 0;

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
  void didUpdateWidget(covariant HealthCareProfileDetailPage oldWidget) {
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
    currentDestination: 'health-care-profiles',
    title: 'Perfil de cuidado',
    subtitle: 'Alergias, restrições e características permanentes da criança.',
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
  ).withHealthCareResponsiveSurface();

  Widget _body(BuildContext context, double padding) {
    if (widget.controller.state == HealthCareLoadState.loading) {
      return const CoeloStatePanel(
        title: 'Carregando',
        message: 'Buscando detalhe sensível.',
        loading: true,
      );
    }
    if (widget.controller.state == HealthCareLoadState.minimized) {
      return const Padding(
        padding: EdgeInsets.all(CoeloSpacing.space6),
        child: CoeloStatePanel(
          title: 'Resumo minimizado',
          message:
              'Este perfil recebe apenas contagens, pendências e status; detalhes sensíveis foram omitidos.',
        ),
      );
    }
    if (widget.controller.state == HealthCareLoadState.unauthorized) {
      return const CoeloStatePanel(
        title: 'Sem permissão',
        message: 'O contexto ativo não autoriza dados sensíveis desta criança.',
      );
    }
    if (widget.controller.state == HealthCareLoadState.error) {
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
    final steps = <SuperadminFormStep>[
      for (var index = 0; index < _sectionLabels.length; index++)
        SuperadminFormStep(
          label: _sectionLabels[index],
          status: index == _currentSection
              ? SuperadminFormStepStatus.current
              : SuperadminFormStepStatus.incomplete,
        ),
    ];
    return CustomScrollView(
      key: const Key('health-care-detail-scroll'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(padding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pageActions(context),
                const SizedBox(height: CoeloSpacing.space4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final navigation = SuperadminFormStepNavigation(
                      steps: steps,
                      currentIndex: _currentSection,
                      onStepSelected: _selectSection,
                    );
                    final content = _section(context, child);
                    if (constraints.maxWidth >= CoeloBreakpoints.medium.minWidth) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          navigation,
                          const SizedBox(width: CoeloSpacing.space6),
                          Expanded(child: content),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        navigation,
                        const SizedBox(height: CoeloSpacing.space4),
                        content,
                        const SizedBox(height: CoeloSpacing.space4),
                        _compactSectionActions(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _selectSection(int index) => setState(() => _currentSection = index);

  Widget _section(BuildContext context, HealthCareChild child) => switch (_currentSection) {
    0 => _summary(context, child),
    1 => _allergies(context, child),
    2 => _care(context, child),
    _ => _medicationPlansLink(context, child),
  };

  Widget _pageActions(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space2,
      children: [
        OutlinedButton.icon(
          key: const Key('health-care-profile-back'),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Voltar'),
        ),
        if (widget.controller.canEdit)
          FilledButton.icon(
            key: const Key('health-care-profile-edit'),
            onPressed: widget.onEditCareProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar perfil'),
          ),
      ],
    ),
  );

  Widget _compactSectionActions() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('health-care-detail-previous-section'),
          onPressed: _currentSection == 0 ? null : () => _selectSection(_currentSection - 1),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Anterior'),
        ),
      ),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('health-care-detail-next-section'),
          onPressed: _currentSection == _sectionLabels.length - 1
              ? null
              : () => _selectSection(_currentSection + 1),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Próxima'),
        ),
      ),
    ],
  );

  Widget _summary(BuildContext context, HealthCareChild child) => _SurfaceCard(
    title: 'Resumo',
    subtitle: 'Identidade, contexto autorizado e ciências deste perfil.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoeloAvatar(
              semanticLabel: 'Avatar de ${child.displayName}',
              initials: 'CD',
              size: CoeloAvatarSize.large,
            ),
            const SizedBox(width: CoeloSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.displayName, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: CoeloSpacing.space1),
                  const Text('Pessoa global • cadastro demonstrativo'),
                  const SizedBox(height: CoeloSpacing.space2),
                  Text(
                    'Demonstração local • Perfil: ${_detailProfileLabel(widget.controller.profile)} • '
                    '${widget.controller.isReadOnly ? 'Somente leitura' : 'Correção excepcional auditada'}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: CoeloSpacing.space6),
        Text('Vínculos ativos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        for (final link in child.links.where((link) => link.active && link.authorized))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
            child: Text(
              '${_institutionLabel(link.institutionId)} → ${_unitLabel(link.unitId)} → ${_groupLabel(link.groupOrActivityId)}',
            ),
          ),
        const Divider(height: CoeloSpacing.space6),
        Text('Ciência', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        for (final acknowledgement in child.acknowledgements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
            child: Text(
              '${_acknowledgementLabel(acknowledgement.subject)} • '
              '${acknowledgement.receivedAt == null ? 'Pendente' : 'Concluída'}',
            ),
          ),
      ],
    ),
  );

  Widget _medicationPlansLink(BuildContext context, HealthCareChild child) => _SurfaceCard(
    title: 'Planos de medicação',
    subtitle: 'Vigência, horários e registros de doses ficam em uma área irmã.',
    action: TextButton.icon(
      onPressed: widget.onMedicationPlans,
      icon: const Icon(Icons.open_in_new_rounded),
      label: const Text('Ver planos da criança'),
    ),
    child: Text(
      child.medications.isEmpty
          ? 'Nenhum plano vinculado.'
          : '${child.medications.length} plano(s) vinculado(s).',
    ),
  );
  Widget _allergies(BuildContext context, HealthCareChild child) => _SurfaceCard(
    title: 'Alergias e restrições',
    subtitle: 'Itens ativos entram em vigor imediatamente e preservam histórico.',
    child: Column(
      children: [
        for (var index = 0; index < child.allergies.length; index++) ...[
          if (index > 0) const Divider(height: CoeloSpacing.space6),
          _AllergySummary(allergy: child.allergies[index]),
        ],
      ],
    ),
  );

  Widget _care(BuildContext context, HealthCareChild child) => _SurfaceCard(
    title: 'Orientações de cuidado',
    subtitle: 'Linguagem de apoio; não representa diagnóstico.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in child.careProfile)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(child: Text(_catalogLabel(item))),
              ],
            ),
          ),
      ],
    ),
  );
}

const _sectionLabels = [
  'Resumo',
  'Alergias e restrições',
  'Orientações de cuidado',
  'Planos de medicação',
];

final class _AllergySummary extends StatelessWidget {
  const _AllergySummary({required this.allergy});

  final HealthCareAllergy allergy;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.warning_amber_rounded,
        color: allergy.active && allergy.type == HealthCareAllergyType.medication
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(allergy.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space2),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_allergyTypeLabel(allergy.type)),
                _allergyStatusChip(context, allergy.status),
                if (allergy.episodeSeverity case final severity?)
                  _episodeSeverityChip(context, severity),
              ],
            ),
            if (allergy.observedReaction.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Text(allergy.observedReaction),
            ],
            if (allergy.guidance.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Text(allergy.guidance),
            ],
          ],
        ),
      ),
    ],
  );
}

String _detailProfileLabel(DemoHealthCareProfile value) => switch (value) {
  DemoHealthCareProfile.owner => 'Owner',
  DemoHealthCareProfile.sensitiveReader => 'Leitor sensível',
  DemoHealthCareProfile.minimized => 'Operador minimizado',
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

String _catalogLabel(HealthCareProfileItem item) {
  if (item.catalogItemId == 'other') return item.otherText!;
  return healthCareProfileCatalog
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
  'group-demo-a' => 'Turma Demo A',
  'group-demo-b' => 'Turma Demo B',
  _ => 'Sem turma',
};
Widget _allergyStatusChip(BuildContext context, HealthCareAllergyStatus status) {
  final theme = Theme.of(context);
  final colors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  final presentation = switch (status) {
    HealthCareAllergyStatus.active => (
      label: 'Ativo',
      icon: Icons.check_circle_outline,
      background: colors.successContainer,
      foreground: colors.onSuccessContainer,
    ),
    HealthCareAllergyStatus.monitoring => (
      label: 'Em acompanhamento',
      icon: Icons.monitor_heart_outlined,
      background: colors.infoContainer,
      foreground: colors.onInfoContainer,
    ),
    HealthCareAllergyStatus.history => (
      label: 'Histórico',
      icon: Icons.history_rounded,
      background: colors.historyContainer,
      foreground: colors.onHistoryContainer,
    ),
  };
  return CoeloStatusChip(
    label: presentation.label,
    icon: presentation.icon,
    backgroundColor: presentation.background,
    foregroundColor: presentation.foreground,
  );
}

Widget _episodeSeverityChip(BuildContext context, HealthCareEpisodeSeverity severity) {
  final theme = Theme.of(context);
  final colors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  final presentation = switch (severity) {
    HealthCareEpisodeSeverity.mild => (
      label: 'Episódio leve',
      icon: Icons.eco_outlined,
      background: colors.successContainer,
      foreground: colors.onSuccessContainer,
    ),
    HealthCareEpisodeSeverity.moderate => (
      label: 'Episódio moderado',
      icon: Icons.warning_amber_rounded,
      background: colors.warningContainer,
      foreground: colors.onWarningContainer,
    ),
    HealthCareEpisodeSeverity.severe => (
      label: 'Episódio grave',
      icon: Icons.error_outline_rounded,
      background: theme.colorScheme.errorContainer,
      foreground: theme.colorScheme.onErrorContainer,
    ),
  };
  return CoeloStatusChip(
    label: presentation.label,
    icon: presentation.icon,
    backgroundColor: presentation.background,
    foregroundColor: presentation.foreground,
  );
}

String _allergyTypeLabel(HealthCareAllergyType value) => switch (value) {
  HealthCareAllergyType.medication => 'Medicamentosa',
  HealthCareAllergyType.food => 'Alimentar',
  HealthCareAllergyType.restriction => 'Restrição',
  HealthCareAllergyType.other => 'Outra',
};
String _acknowledgementLabel(HealthCareAcknowledgementSubject value) => switch (value) {
  HealthCareAcknowledgementSubject.medication => 'Medicamento',
  HealthCareAcknowledgementSubject.allergyOrRestriction => 'Alergia ou restrição',
  HealthCareAcknowledgementSubject.careProfile => 'Perfil de Cuidado',
};
