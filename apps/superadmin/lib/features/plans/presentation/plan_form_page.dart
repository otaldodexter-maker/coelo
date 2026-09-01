import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_catalog_repository.dart';
import 'widgets/plan_capability_matrix.dart';

final class PlanFormPage extends StatefulWidget {
  const PlanFormPage({
    required this.repository,
    this.planId,
    this.onSaved,
    this.onCancel,
    super.key,
  });

  final PlanCatalogRepository repository;
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
  PlanCatalog? _original;
  List<PlanLinkedInstitution> _linked = const [];
  PlanDataState _loadState = PlanDataState.loading;
  late Set<PlanFeature> _features;
  late PlanStatus _status;
  int _step = 0;
  int _furthestStep = 0;
  bool _saving = false;
  bool _capabilityError = false;
  bool _auditReasonError = false;
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
    _name = TextEditingController();
    _code = TextEditingController();
    _description = TextEditingController();
    _units = TextEditingController(text: '1');
    _memberships = TextEditingController(text: '100');
    _storage = TextEditingController(text: '10');
    _media = TextEditingController(text: '2');
    _reason = TextEditingController();
    _features = {};
    _status = PlanStatus.active;
    if (widget.planId == null) {
      _loadState = PlanDataState.ready;
    } else {
      unawaited(_loadPlan());
    }
  }

  Future<void> _loadPlan() async {
    setState(() => _loadState = PlanDataState.loading);
    try {
      final details = await widget.repository.get(widget.planId!);
      if (!mounted) return;
      setState(() {
        _original = details.plan;
        _linked = details.linkedInstitutions;
        _name.text = details.plan.name;
        _code.text = details.plan.code;
        _description.text = details.plan.description;
        _units.text = '${details.plan.limits.units}';
        _memberships.text = '${details.plan.limits.memberships}';
        _storage.text = '${details.plan.limits.storageGb}';
        _media.text = '${details.plan.limits.mediaGb}';
        _features = {...details.plan.features};
        _status = details.plan.status;
        _loadState = PlanDataState.ready;
      });
    } on PlanRepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadState = error.kind == PlanRepositoryFailureKind.unauthorized
            ? PlanDataState.unauthorized
            : PlanDataState.error;
      });
    }
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
  Widget build(BuildContext context) {
    if (widget.planId != null && _loadState != PlanDataState.ready) {
      return Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: CoeloStatePanel(
          title: _loadState == PlanDataState.unauthorized
              ? 'Acesso não autorizado'
              : _loadState == PlanDataState.error
              ? 'Não foi possível carregar o plano'
              : 'Carregando plano',
          message: _loadState == PlanDataState.unauthorized
              ? 'Você não possui autorização para consultar este plano.'
              : _loadState == PlanDataState.error
              ? 'Tente novamente sem perder a navegação atual.'
              : 'Aguarde enquanto preparamos a edição.',
          icon: _loadState == PlanDataState.loading ? null : Icons.cloud_off_outlined,
          loading: _loadState == PlanDataState.loading,
          actionLabel: _loadState == PlanDataState.error ? 'Tentar novamente' : null,
          onAction: _loadState == PlanDataState.error ? () => unawaited(_loadPlan()) : null,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final navigation = SuperadminFormStepNavigation(
          steps: [
            for (var index = 0; index < _stepLabels.length; index++)
              SuperadminFormStep(
                label: _stepLabels[index],
                status:
                    index == 1 && _capabilityError ||
                        index == _reviewStep && index == _step && _auditReasonError
                    ? SuperadminFormStepStatus.error
                    : index == _step
                    ? SuperadminFormStepStatus.current
                    : index < _step
                    ? SuperadminFormStepStatus.complete
                    : SuperadminFormStepStatus.incomplete,
                enabled: index <= _furthestStep,
              ),
          ],
          currentIndex: _step,
          onStepSelected: (value) => setState(() => _step = value),
        );
        final content = Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                key: const Key('plan-form-content-column'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
                      child: _stepContent(),
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
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
            ],
          ),
        );
      },
    );
  }

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

  Widget _capabilities() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeader(
        'Capacidades incluídas',
        'Fixtures locais de oferta comercial. Não representam permissões de pessoas.',
      ),
      PlanCapabilityMatrix(
        searchController: _capabilitySearch,
        selected: _features,
        errorText: _capabilityError ? 'Selecione ao menos uma capacidade.' : null,
        onChanged: (features) => setState(() {
          _features = features;
          if (_features.isNotEmpty) _capabilityError = false;
        }),
      ),
    ],
  );

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
    final linked = _linked;
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
        errorText: _auditReasonError ? 'Informe o motivo de auditoria.' : null,
        onChanged: (value) {
          if (_auditReasonError && value.trim().isNotEmpty) {
            setState(() => _auditReasonError = false);
          }
        },
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
      setState(() => _capabilityError = true);
      return;
    }
    if (_step == 2 && !_limitsAreValid()) return;
    setState(() {
      _step += 1;
      if (_step > _furthestStep) _furthestStep = _step;
    });
  }

  bool _limitsAreValid() => [
    _units,
    _memberships,
    _storage,
    _media,
  ].every((controller) => (int.tryParse(controller.text) ?? 0) > 0);

  Future<void> _save() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _auditReasonError = true);
      return;
    }
    if (!_identityValuesAreValid()) {
      setState(() => _step = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _identityKey.currentState?.validate();
      });
      return;
    }
    if (_features.isEmpty) {
      setState(() {
        _step = 1;
        _capabilityError = true;
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
      final saved = await widget.repository.save(
        PlanSaveCommand(
          requestId: newPlanRequestId(),
          expectedRevision: _original?.revision,
          reason: _reason.text,
          draft: PlanDraft(
            id: _original?.id ?? '',
            name: _name.text.trim(),
            code: _code.text.trim(),
            description: _description.text.trim(),
            status: _status,
            features: Set.unmodifiable(_features),
            limits: limits,
          ),
        ),
      );
      _original = saved.plan;
      _linked = saved.linkedInstitutions;
      widget.onSaved?.call();
    } on PlanRepositoryException catch (error) {
      setState(() {
        _conflictMessage = error.kind == PlanRepositoryFailureKind.conflict
            ? 'O plano mudou desde que esta edição começou. Seu draft foi preservado.'
            : error.message;
      });
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
