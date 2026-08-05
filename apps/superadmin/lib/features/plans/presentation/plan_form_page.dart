import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../data/fake_plan_catalog_repository.dart';
import '../domain/plan_catalog.dart';

final class PlanFormPage extends StatefulWidget {
  const PlanFormPage({
    required this.repository,
    this.planId,
    this.onSaved,
    this.onCancel,
    super.key,
  });

  final FakePlanCatalogRepository repository;
  final String? planId;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  @override
  State<PlanFormPage> createState() => _PlanFormPageState();
}

final class _PlanFormPageState extends State<PlanFormPage> {
  final _identityKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _description;
  late final TextEditingController _units;
  late final TextEditingController _memberships;
  late final TextEditingController _storage;
  late final TextEditingController _media;
  late final TextEditingController _reason;
  final _capabilitySearch = TextEditingController();
  late final PlanCatalog? _original;
  late Set<PlanFeature> _features;
  late PlanStatus _status;
  int _step = 0;
  bool _saving = false;
  String? _conflictMessage;

  bool get _editing => _original != null;

  List<String> get _stepLabels => _editing
      ? const [
          'Identificação',
          'Capacidades incluídas',
          'Limites',
          'Instituições vinculadas',
          'Revisão',
        ]
      : const ['Identificação', 'Capacidades incluídas', 'Limites', 'Revisão'];

  int get _reviewStep => _stepLabels.length - 1;

  @override
  void initState() {
    super.initState();
    _original = widget.planId == null ? null : widget.repository.findById(widget.planId!);
    final plan = _original;
    _name = TextEditingController(text: plan?.name ?? '');
    _code = TextEditingController(text: plan?.code ?? '');
    _description = TextEditingController(text: plan?.description ?? '');
    _units = TextEditingController(text: '${plan?.limits.units ?? 1}');
    _memberships = TextEditingController(text: '${plan?.limits.memberships ?? 100}');
    _storage = TextEditingController(text: '${plan?.limits.storageGb ?? 10}');
    _media = TextEditingController(text: '${plan?.limits.mediaGb ?? 2}');
    _reason = TextEditingController();
    _features = {...?plan?.features};
    _status = plan?.status ?? PlanStatus.active;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    _units.dispose();
    _memberships.dispose();
    _storage.dispose();
    _media.dispose();
    _reason.dispose();
    _capabilitySearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final navigation = SuperadminFormStepNavigation(
        steps: [
          for (var index = 0; index < _stepLabels.length; index++)
            SuperadminFormStep(
              label: _stepLabels[index],
              status: index == _step
                  ? SuperadminFormStepStatus.current
                  : index < _step
                  ? SuperadminFormStepStatus.complete
                  : SuperadminFormStepStatus.incomplete,
            ),
        ],
        currentIndex: _step,
        onStepSelected: (value) => setState(() => _step = value),
      );
      final content = Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: _stepContent(),
            ),
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing ? 'Editar plano' : 'Novo plano',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              _editing
                  ? 'Revise o catálogo comercial sem alterar subscriptions diretamente.'
                  : 'Configure uma oferta local operada manualmente no MVP.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: CoeloSpacing.space5),
            Expanded(
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        navigation,
                        const SizedBox(height: CoeloSpacing.space4),
                        content,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        navigation,
                        const SizedBox(width: CoeloSpacing.space6),
                        content,
                      ],
                    ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            SuperadminFormActionFooter(
              tertiaryAction: TextButton(
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Cancelar'),
              ),
              continuationActions: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _step -= 1),
                    child: const Text('Voltar'),
                  ),
                FilledButton(
                  onPressed: _saving ? null : (_step == _reviewStep ? _save : _continue),
                  child: Text(
                    _saving
                        ? 'Salvando…'
                        : _step == _reviewStep
                        ? 'Salvar plano'
                        : 'Continuar',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _stepContent() {
    if (_step == 0) return _identity();
    if (_step == 1) return _capabilities();
    if (_step == 2) return _limits();
    if (_editing && _step == 3) return _linkedInstitutions();
    return _review();
  }

  Widget _sectionHeader(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: CoeloSpacing.space5),
    ],
  );

  Widget _identity() => Form(
    key: _identityKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'Identificação',
          'Dados estáveis e apresentação do plano no catálogo global.',
        ),
        CoeloFormTextField(
          key: const Key('plan-name-field'),
          controller: _name,
          labelText: 'Nome do plano',
          prefixIcon: Icons.loyalty_outlined,
          validator: _required,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: const Key('plan-code-field'),
          controller: _code,
          labelText: 'Código estável',
          prefixIcon: Icons.tag_rounded,
          enabled: !_editing,
          validator: _required,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]'))],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: const Key('plan-description-field'),
          controller: _description,
          labelText: 'Descrição',
          prefixIcon: Icons.notes_rounded,
          maxLines: 3,
          validator: _required,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<PlanStatus>(
          label: 'Status inicial',
          value: _status,
          options: PlanStatus.values,
          optionLabel: _statusLabel,
          prefixIcon: Icons.flag_outlined,
          enabled: !_editing,
          onChanged: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        const _InformationPanel(
          icon: Icons.handyman_outlined,
          title: 'Operação manual no MVP',
          message: 'Preço, cobrança, pagamento e automação permanecem fora desta tela.',
        ),
      ],
    ),
  );

  Widget _capabilities() {
    final term = _capabilitySearch.text.trim().toLowerCase();
    final visible = PlanFeature.values
        .where((feature) => term.isEmpty || feature.label.toLowerCase().contains(term))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'Capacidades incluídas',
          'Fixtures locais de oferta comercial. Não representam permissões de pessoas.',
        ),
        CoeloSearchField(
          controller: _capabilitySearch,
          semanticLabel: 'Buscar capacidades do plano',
          hintText: 'Buscar capacidade',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Text('${_features.length} selecionadas', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: CoeloSpacing.space4),
        for (final surface in PlanSurface.values) ...[
          _CapabilityGroup(
            surface: surface,
            features: visible.where((feature) => feature.surface == surface).toList(),
            selected: _features,
            onChanged: (feature, selected) => setState(() {
              selected ? _features.add(feature) : _features.remove(feature);
            }),
            onToggleAll: (features, selected) => setState(() {
              selected ? _features.addAll(features) : _features.removeAll(features);
            }),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
      ],
    );
  }

  Widget _limits() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeader(
        'Limites',
        'Valores informativos; não produzem bloqueio automático no cliente.',
      ),
      const _InformationPanel(
        icon: Icons.info_outline_rounded,
        title: 'Informativo no MVP',
        message: 'O consumo real e a persistência produtiva dependem de contrato canônico futuro.',
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _limitField(_units, 'Unidades', Icons.apartment_outlined),
      const SizedBox(height: CoeloSpacing.space4),
      _limitField(_memberships, 'Memberships institucionais', Icons.groups_outlined),
      const SizedBox(height: CoeloSpacing.space4),
      _limitField(_storage, 'Armazenamento total (GB)', Icons.storage_outlined),
      const SizedBox(height: CoeloSpacing.space4),
      _limitField(_media, 'Cota de mídia (GB)', Icons.perm_media_outlined),
    ],
  );

  Widget _limitField(TextEditingController controller, String label, IconData icon) =>
      CoeloFormTextField(
        controller: controller,
        labelText: label,
        prefixIcon: icon,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: _positiveNumber,
      );

  Widget _linkedInstitutions() {
    final linked = widget.repository.linkedInstitutions(_original!.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'Instituições vinculadas',
          'Consulta somente leitura das subscriptions que utilizam este plano.',
        ),
        if (linked.isEmpty)
          const CoeloStatePanel(
            title: 'Nenhuma instituição vinculada',
            message: 'Este plano ainda não possui subscriptions.',
            icon: Icons.apartment_outlined,
          )
        else
          for (final institution in linked) ...[
            _LinkedInstitutionTile(institution: institution),
            const SizedBox(height: CoeloSpacing.space3),
          ],
      ],
    );
  }

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeader('Revisão', 'Confira o impacto antes de salvar como única ação primária.'),
      if ((_original?.usedByInstitutionCount ?? 0) > 0) ...[
        _InformationPanel(
          icon: Icons.warning_amber_rounded,
          title: 'Plano em uso',
          message:
              '${_original!.usedByInstitutionCount} instituições utilizam este plano. A tela não altera subscriptions automaticamente.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      _ReviewSection(
        title: 'Identificação',
        lines: [
          _name.text.trim(),
          _code.text.trim(),
          _statusLabel(_status),
          _description.text.trim(),
        ],
        onEdit: () => setState(() => _step = 0),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      _ReviewSection(
        title: 'Capacidades incluídas',
        lines:
            _features.isEmpty
                  ? const ['Nenhuma capacidade selecionada']
                  : _features.map((feature) => feature.label).toList()
              ..sort(),
        onEdit: () => setState(() => _step = 1),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      _ReviewSection(
        title: 'Limites informativos',
        lines: [
          '${_units.text} unidades',
          '${_memberships.text} memberships',
          '${_storage.text} GB de armazenamento',
          '${_media.text} GB de mídia',
        ],
        onEdit: () => setState(() => _step = 2),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        key: const Key('plan-audit-reason-field'),
        controller: _reason,
        labelText: 'Motivo de auditoria',
        prefixIcon: Icons.fact_check_outlined,
        maxLines: 3,
        validator: _required,
      ),
      if (_conflictMessage case final message?) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloStatePanel(
          title: 'Conflito ao salvar',
          message: message,
          icon: Icons.sync_problem_rounded,
          actionLabel: 'Revisar alterações',
          onAction: () => setState(() => _conflictMessage = null),
        ),
      ],
    ],
  );

  void _continue() {
    if (_step == 0 && !(_identityKey.currentState?.validate() ?? false)) return;
    if (_step == 1 && _features.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione ao menos uma capacidade.')));
      return;
    }
    if (_step == 2 && !_limitsAreValid()) return;
    setState(() => _step += 1);
  }

  bool _limitsAreValid() => [
    _units,
    _memberships,
    _storage,
    _media,
  ].every((controller) => (int.tryParse(controller.text) ?? 0) > 0);

  Future<void> _save() async {
    if (_reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe o motivo de auditoria.')));
      return;
    }
    if (!_identityValuesAreValid()) {
      setState(() => _step = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _identityKey.currentState?.validate();
      });
      return;
    }
    if (!_limitsAreValid()) {
      setState(() => _step = 2);
      return;
    }
    setState(() {
      _saving = true;
      _conflictMessage = null;
    });
    try {
      final limits = PlanLimits(
        units: int.parse(_units.text),
        memberships: int.parse(_memberships.text),
        storageGb: int.parse(_storage.text),
        mediaGb: int.parse(_media.text),
      );
      if (_original case final original?) {
        widget.repository.update(
          original.copyWith(
            name: _name.text.trim(),
            description: _description.text.trim(),
            status: _status,
            features: Set.unmodifiable(_features),
            limits: limits,
          ),
          reason: _reason.text,
        );
      } else {
        widget.repository.create(
          PlanDraft(
            id: _code.text.trim(),
            name: _name.text.trim(),
            code: _code.text.trim(),
            description: _description.text.trim(),
            status: _status,
            features: Set.unmodifiable(_features),
            limits: limits,
          ),
          reason: _reason.text,
        );
      }
      widget.onSaved?.call();
    } on PlanConflictException {
      setState(() {
        _conflictMessage = 'O plano mudou desde que esta edição começou. Seu draft foi preservado.';
      });
    } on StateError catch (error) {
      setState(() => _conflictMessage = error.message.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;

  bool _identityValuesAreValid() =>
      _name.text.trim().isNotEmpty &&
      _code.text.trim().isNotEmpty &&
      _description.text.trim().isNotEmpty;

  String? _positiveNumber(String? value) =>
      (int.tryParse(value ?? '') ?? 0) > 0 ? null : 'Informe um valor maior que zero';
}

final class _CapabilityGroup extends StatelessWidget {
  const _CapabilityGroup({
    required this.surface,
    required this.features,
    required this.selected,
    required this.onChanged,
    required this.onToggleAll,
  });

  final PlanSurface surface;
  final List<PlanFeature> features;
  final Set<PlanFeature> selected;
  final void Function(PlanFeature feature, bool selected) onChanged;
  final void Function(List<PlanFeature> features, bool selected) onToggleAll;

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) return const SizedBox.shrink();
    final selectedCount = features.where(selected.contains).length;
    final allSelected = selectedCount == features.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth <= CoeloBreakpoints.compact.maxWidth;
                final title = Text(
                  surface == PlanSurface.admin ? 'Admin' : 'Principal',
                  style: Theme.of(context).textTheme.titleMedium,
                );
                final action = TextButton(
                  onPressed: () => onToggleAll(features, !allSelected),
                  child: Text(allSelected ? 'Limpar grupo' : 'Selecionar grupo'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    action,
                  ],
                );
              },
            ),
            Text('$selectedCount de ${features.length} selecionadas'),
            const SizedBox(height: CoeloSpacing.space3),
            for (final feature in features)
              Semantics(
                checked: selected.contains(feature),
                child: CoeloAdminInteractiveCard(
                  semanticLabel: '${feature.label}, disponível no plano',
                  minHeight: CoeloSize.touchMin,
                  onPressed: () => onChanged(feature, !selected.contains(feature)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final checkbox = Checkbox(
                            value: selected.contains(feature),
                            onChanged: (value) => onChanged(feature, value ?? false),
                          );
                          if (constraints.maxWidth <= CoeloBreakpoints.compact.maxWidth) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                checkbox,
                                Text(feature.label),
                                const SizedBox(height: CoeloSpacing.space1),
                                const Text('Disponível no plano'),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              checkbox,
                              const SizedBox(width: CoeloSpacing.space2),
                              Expanded(child: Text(feature.label)),
                              const Text('Disponível no plano'),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _InformationPanel extends StatelessWidget {
  const _InformationPanel({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .3),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: CoeloSpacing.space1),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

final class _LinkedInstitutionTile extends StatelessWidget {
  const _LinkedInstitutionTile({required this.institution});

  final PlanLinkedInstitution institution;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.apartment_rounded),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(institution.name, style: Theme.of(context).textTheme.titleSmall),
                Text('${institution.subscriptionStatus} · desde ${_date(institution.startsAt)}'),
                Text(
                  institution.unitsWithOverride == 0
                      ? 'Nenhuma unidade com override'
                      : '${institution.unitsWithOverride} unidades com override',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

final class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.lines, required this.onEdit});

  final String title;
  final List<String> lines;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: onEdit, child: const Text('Editar')),
            ],
          ),
          for (final line in lines.where((line) => line.isNotEmpty)) Text(line),
        ],
      ),
    ),
  );
}

String _statusLabel(PlanStatus status) => status == PlanStatus.active ? 'Ativo' : 'Arquivado';

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
