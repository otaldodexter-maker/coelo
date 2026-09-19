import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/staff_access.dart';
import 'staff_access_presentation.dart';
import 'staff_access_rule_fields.dart';

enum _Section { membership, surfaces, schedule, validity, popup }

const _sectionLabels = ['Vínculo', 'Superfícies', 'Horários', 'Vigência', 'Popup'];

enum _LoadState { loading, ready, failure, unauthorized }

/// Regra de acesso de um vínculo profissional. Baseline: Criar/Editar
/// instituição (`SuperadminFormFrame` + `SuperadminFormActionFooter`).
/// O servidor valida tudo (`staff_access_rule_save_v1`); versão defasada
/// (PT409) mostra o conflito com "Recarregar".
final class StaffAccessFormPage extends StatefulWidget {
  const StaffAccessFormPage({
    required this.repository,
    required this.membershipId,
    required this.onCancel,
    this.onSaved,
    this.onOpenLeaves,
    this.onCreateLeave,
    this.logout = unavailableSuperadminLogout,
    this.onDestinationSelected,
    super.key,
  });

  final StaffAccessRepository repository;
  final String membershipId;
  final VoidCallback onCancel;
  final ValueChanged<StaffAccessItem>? onSaved;
  final VoidCallback? onOpenLeaves;
  final ValueChanged<String>? onCreateLeave;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<StaffAccessFormPage> createState() => _StaffAccessFormPageState();
}

final class _StaffAccessFormPageState extends State<StaffAccessFormPage> {
  _LoadState _loadState = _LoadState.loading;
  StaffAccessItem? _item;
  _Section _section = _Section.membership;
  bool _saving = false;
  bool _conflict = false;
  String? _saveError;
  double _footerHeight = 0;
  int _revision = 0;

  // rascunho
  Set<StaffAccessSurface> _surfaces = StaffAccessSurface.values.toSet();
  List<StaffAccessWindow> _windows = [];
  DateTime? _validFrom;
  DateTime? _validUntil;
  Set<StaffAccessSurface> _validitySurfaces = StaffAccessSurface.values.toSet();
  bool _popupEnabled = false;
  bool _popupShowValidity = false;
  bool _restricted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant StaffAccessFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.membershipId != widget.membershipId) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loadState = _LoadState.loading;
      _conflict = false;
      _saveError = null;
    });
    try {
      final item = await widget.repository.fetchDetail(widget.membershipId);
      if (!mounted || revision != _revision) return;
      setState(() {
        _item = item;
        // Sem regra própria o rascunho parte do padrão do perfil (herdado).
        _applyRule(item.rule ?? item.profileRule);
        _restricted = item.rule != null;
        _loadState = _LoadState.ready;
      });
    } on StaffAccessUnauthorizedException {
      if (mounted && revision == _revision) setState(() => _loadState = _LoadState.unauthorized);
    } on Object {
      if (mounted && revision == _revision) setState(() => _loadState = _LoadState.failure);
    }
  }

  void _applyRule(StaffAccessRule? rule) {
    _restricted = rule != null;
    _surfaces = rule?.surfaces.isNotEmpty == true ? {...rule!.surfaces} : StaffAccessSurface.values.toSet();
    _windows = [...?rule?.windows];
    _validFrom = rule?.validFrom;
    _validUntil = rule?.validUntil;
    _validitySurfaces = rule?.validitySurfaces.isNotEmpty == true
        ? {...rule!.validitySurfaces}
        : StaffAccessSurface.values.toSet();
    _popupEnabled = rule?.popupEnabled ?? false;
    _popupShowValidity = rule?.popupShowValidity ?? false;
  }

  bool get _valid {
    if (!_restricted) return true;
    if (_surfaces.isEmpty) return false;
    if (_validFrom != null && _validUntil != null && _validUntil!.isBefore(_validFrom!)) return false;
    return true;
  }

  Future<void> _save() async {
    final item = _item;
    if (item == null || _saving || !_valid) return;
    final revision = _revision;
    setState(() {
      _saving = true;
      _saveError = null;
      _conflict = false;
    });
    try {
      final draft = StaffAccessRuleDraft(
        surfaces: _surfaces,
        windows: _windows,
        validFrom: _validFrom,
        validUntil: _validUntil,
        validitySurfaces: _validitySurfaces,
        popupEnabled: _popupEnabled,
        popupShowValidity: _popupShowValidity,
        clear: !_restricted,
      );
      if (!_restricted && item.rule == null) {
        // Nada a limpar: só volta.
        widget.onSaved?.call(item);
        return;
      }
      final saved = await widget.repository.saveRule(widget.membershipId, item.rule?.version, draft);
      if (!mounted || revision != _revision) return;
      widget.onSaved?.call(saved);
    } on StaffAccessConflictException {
      if (mounted && revision == _revision) setState(() => _conflict = true);
    } on StaffAccessUnauthorizedException {
      if (mounted && revision == _revision) {
        setState(() => _saveError = 'Sua autorização mudou. Recarregue e tente novamente.');
      }
    } on StaffAccessValidationException catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _saveError = _validationMessage(error.code));
      }
    } on Object {
      if (mounted && revision == _revision) {
        setState(() => _saveError = 'Não foi possível salvar a regra. Tente novamente.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _saving = false);
    }
  }

  String _validationMessage(String code) => switch (code) {
    'STAFF_ACCESS_SURFACES_REQUIRED' => 'Escolha ao menos uma superfície liberada.',
    'STAFF_ACCESS_VALIDITY_INVALID' => 'A vigência precisa terminar depois de começar.',
    'STAFF_ACCESS_WINDOW_EMPTY' => 'Uma janela não pode começar e terminar na mesma hora.',
    'STAFF_ACCESS_NOT_STAFF_MEMBERSHIP' => 'Este vínculo não é de funcionário.',
    'STAFF_ACCESS_SERVICE_PERSON' => 'Este vínculo pertence a uma conta de serviço.',
    'STAFF_ACCESS_MEMBERSHIP_INACTIVE' => 'O vínculo não está ativo.',
    _ => 'O servidor recusou a regra. Revise os campos.',
  };

  /// "Voltar ao padrão do perfil": apaga a regra própria (auditada no servidor);
  /// o vínculo volta a herdar o horário do perfil.
  Future<void> _resetToProfile() async {
    final item = _item;
    if (item == null || item.rule == null || _saving) return;
    final revision = _revision;
    setState(() {
      _saving = true;
      _saveError = null;
      _conflict = false;
    });
    try {
      final saved = await widget.repository.saveRule(
        widget.membershipId,
        item.rule!.version,
        StaffAccessRuleDraft(
          surfaces: const {},
          windows: const [],
          validFrom: null,
          validUntil: null,
          validitySurfaces: const {},
          popupEnabled: false,
          popupShowValidity: false,
          clear: true,
        ),
      );
      if (!mounted || revision != _revision) return;
      widget.onSaved?.call(saved);
    } on StaffAccessConflictException {
      if (mounted && revision == _revision) setState(() => _conflict = true);
    } on Object {
      if (mounted && revision == _revision) {
        setState(() => _saveError = 'Não foi possível voltar ao padrão do perfil. Tente novamente.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _saving = false);
    }
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _saveError = null;
  });

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Acesso do funcionário',
    subtitle: _item == null ? 'Regra de acesso do vínculo profissional.' : '${_item!.personName} · ${_item!.scopeLabel}',
    currentDestination: 'staff-access',
    onDestinationSelected: widget.onDestinationSelected,
    showChatLauncher: false,
    chatLauncherBottomInset: 0,
    child: LayoutBuilder(
      builder: (context, constraints) => ColoredBox(
        key: const Key('staff-access-form-surface'),
        color: Theme.of(context).colorScheme.surface,
        child: switch (_loadState) {
          _LoadState.loading => const Center(child: CircularProgressIndicator()),
          _LoadState.failure => Center(
            child: CoeloStatePanel(
              title: 'Vínculo indisponível',
              message: 'Não foi possível carregar a regra deste vínculo.',
              icon: Icons.error_outline_rounded,
              actionLabel: 'Tentar novamente',
              onAction: _load,
            ),
          ),
          _LoadState.unauthorized => const Center(
            child: CoeloStatePanel(
              title: 'Acesso não autorizado',
              message: 'Seu contexto atual não permite gerir o acesso deste vínculo.',
              icon: Icons.lock_outline_rounded,
            ),
          ),
          _LoadState.ready => SuperadminFormFrame(
            viewportWidth: constraints.maxWidth,
            scrollKey: const Key('staff-access-form-scroll'),
            navigation: SuperadminFormStepNavigation(
              steps: [
                for (var index = 0; index < _sectionLabels.length; index++)
                  SuperadminFormStep(
                    label: _sectionLabels[index],
                    status: index == _section.index
                        ? SuperadminFormStepStatus.current
                        : SuperadminFormStepStatus.complete,
                    enabled: !_saving && (_restricted || index == 0),
                  ),
              ],
              currentIndex: _section.index,
              onStepSelected: (index) => setState(() => _section = _Section.values[index]),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_conflict) ...[
                  _ConflictBanner(onReload: _load),
                  const SizedBox(height: CoeloSpacing.space4),
                ],
                if (_saveError != null) ...[
                  _ErrorBanner(message: _saveError!),
                  const SizedBox(height: CoeloSpacing.space4),
                ],
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.fast,
                  child: KeyedSubtree(key: ValueKey(_section), child: _body()),
                ),
              ],
            ),
            footer: SuperadminFormActionFooter(
              surfaceKey: const Key('staff-access-form-footer-surface'),
              onHeightChanged: (value) {
                if (!mounted || (_footerHeight - value).abs() < .5) return;
                setState(() => _footerHeight = value);
              },
              tertiaryAction: TextButton(
                key: const Key('staff-access-form-cancel'),
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Cancelar'),
              ),
              continuationActions: [
                if (_section.index > 0 && _restricted)
                  OutlinedButton(
                    key: const Key('staff-access-form-previous'),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _section = _Section.values[_section.index - 1]),
                    child: const Text('Anterior'),
                  ),
                if (_section.index < _Section.values.length - 1 && _restricted)
                  OutlinedButton(
                    key: const Key('staff-access-form-continue'),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _section = _Section.values[_section.index + 1]),
                    child: const Text('Continuar'),
                  ),
                FilledButton(
                  key: const Key('staff-access-form-save'),
                  onPressed: _saving || _conflict || !_valid ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: CoeloSize.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar alterações'),
                ),
              ],
            ),
          ),
        },
      ),
    ),
  );

  Widget _body() => switch (_section) {
    _Section.membership => _membershipSection(),
    _Section.surfaces => _surfacesSection(),
    _Section.schedule => _scheduleSection(),
    _Section.validity => _validitySection(),
    _Section.popup => _popupSection(),
  };

  Widget _membershipSection() {
    final item = _item!;
    final theme = Theme.of(context);
    return _SectionCard(
      title: 'Vínculo profissional',
      description: 'A regra vale só para este vínculo. A pessoa segue usando o contexto familiar e os outros vínculos.',
      children: [
        _ReadOnlyRow(label: 'Funcionário', value: item.personName),
        _ReadOnlyRow(label: 'Papel', value: item.roleName),
        _ReadOnlyRow(label: 'Instituição', value: item.institutionName),
        if (item.unitName != null) _ReadOnlyRow(label: 'Unidade', value: item.unitName!),
        if (item.groupName != null) _ReadOnlyRow(label: 'Turma', value: item.groupName!),
        _ReadOnlyRow(label: 'Fuso horário', value: item.timezone),
        Row(
          children: [
            Text('Estado agora', style: theme.textTheme.labelMedium),
            const SizedBox(width: CoeloSpacing.space3),
            Flexible(child: StaffAccessStateChip(state: item.state)),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (item.source == StaffAccessSource.own && item.profileName != null) ...[
          CoeloTourAnchor(
            id: 'staff-access.source',
            child: _SourceBanner(
              key: const Key('staff-access-source-own'),
              icon: Icons.tune_rounded,
              text: 'Este vínculo está fora do padrão do perfil ${item.profileName}.',
              action: TextButton(
                key: const Key('staff-access-reset-to-profile'),
                onPressed: _saving ? null : _resetToProfile,
                child: const Text('Voltar ao padrão do perfil'),
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ] else if (item.source == StaffAccessSource.profile) ...[
          CoeloTourAnchor(
            id: 'staff-access.source',
            child: StaffAccessInfoBanner(
              key: const Key('staff-access-source-profile'),
              icon: Icons.badge_outlined,
              text: 'Herda o horário do perfil ${item.profileName}. Ligue a restrição abaixo para ajustar só este vínculo.',
            ),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        CoeloAdminToggleField(
          key: const Key('staff-access-restricted-toggle'),
          label: item.profileRule != null
              ? 'Ajustar o acesso só deste vínculo'
              : 'Restringir o acesso deste vínculo',
          description: _restricted
              ? 'Superfícies, horários, vigência e popup nas próximas seções.'
              : item.profileRule != null
              ? 'Desligado: vale o padrão do perfil.'
              : 'Desligado: tudo liberado (sem configuração).',
          value: _restricted,
          onChanged: (value) => _update(() {
            _restricted = value;
            if (value && _section == _Section.membership) _section = _Section.surfaces;
          }),
        ),
        if (item.currentLeave != null) ...[
          const SizedBox(height: CoeloSpacing.space4),
          StaffAccessInfoBanner(
            icon: Icons.beach_access_outlined,
            text:
                'Afastado até ${staffAccessDateLabel(item.currentLeave!.endsOn)}. O afastamento prevalece sobre horário e vigência.',
          ),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          children: [
            if (widget.onCreateLeave != null)
              OutlinedButton.icon(
                key: const Key('staff-access-create-leave'),
                onPressed: () => widget.onCreateLeave!(item.membershipId),
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Registrar afastamento'),
              ),
            if (widget.onOpenLeaves != null && item.leavesCount > 0)
              TextButton.icon(
                key: const Key('staff-access-open-leaves'),
                onPressed: widget.onOpenLeaves,
                icon: const Icon(Icons.list_alt_outlined),
                label: Text('Ver afastamentos (${item.leavesCount})'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _surfacesSection() => _SectionCard(
    title: 'Superfícies liberadas',
    description: 'Onde este vínculo pode usar o app. O cliente declara a superfície; o servidor aplica a regra à superfície declarada.',
    children: [
      StaffAccessSurfaceToggles(
        surfaces: _surfaces,
        onChanged: (value) => _update(() => _surfaces = value),
      ),
    ],
  );

  Widget _scheduleSection() => _SectionCard(
    title: 'Dias e horários',
    description: 'Sem janelas = qualquer horário. Uma janela que termina antes de começar (22:00–02:00) cruza a meia-noite e pertence ao dia de início. Fuso: ${_item!.timezone}.',
    children: [
      StaffAccessWindowsEditor(
        windows: _windows,
        onChanged: (value) => _update(() => _windows = value),
      ),
    ],
  );

  Widget _validitySection() => _SectionCard(
    title: 'Vigência do acesso',
    description: 'Datas inclusivas. Fora da vigência o acesso é negado, nas superfícies escolhidas abaixo.',
    children: [
      StaffAccessValidityFields(
        validFrom: _validFrom,
        validUntil: _validUntil,
        validitySurfaces: _validitySurfaces,
        onChanged: (from, until, surfaces) => _update(() {
          _validFrom = from;
          _validUntil = until;
          _validitySurfaces = surfaces;
        }),
      ),
    ],
  );

  Widget _popupSection() => _SectionCard(
    title: 'Popup informativo',
    description: 'Só informa. Desligar o popup não desliga a restrição: sem ele, o funcionário vê "Este contexto não está disponível agora".',
    children: [
      StaffAccessPopupFields(
        popupEnabled: _popupEnabled,
        popupShowValidity: _popupShowValidity,
        windows: _windows,
        validFrom: _validFrom,
        validUntil: _validUntil,
        onChanged: (enabled, showValidity) => _update(() {
          _popupEnabled = enabled;
          _popupShowValidity = showValidity;
        }),
      ),
    ],
  );
}

final class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.description, required this.children});
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          ...children,
        ],
      ),
    );
  }
}

final class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Aviso de origem do horário (fora do padrão do perfil) com ação.
final class _SourceBanner extends StatelessWidget {
  const _SourceBanner({required this.icon, required this.text, required this.action, super.key});
  final IconData icon;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final status = context.coeloStatusColors;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: status.warningContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: CoeloSize.iconSm, color: status.onWarningContainer),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: status.onWarningContainer),
                ),
              ),
            ],
          ),
          Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

final class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final status = context.coeloStatusColors;
    return Container(
      key: const Key('staff-access-form-error'),
      margin: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: status.errorContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: CoeloSize.iconSm, color: status.onErrorContainer),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: status.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Versão defasada (PT409): a regra mudou em outro lugar; recarregar antes de salvar.
final class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.onReload});
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final status = context.coeloStatusColors;
    return Container(
      key: const Key('staff-access-form-conflict'),
      margin: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: status.warningContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_outlined, size: CoeloSize.iconSm, color: status.onWarningContainer),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Text(
              'Esta regra foi alterada por outra pessoa. Recarregue para continuar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: status.onWarningContainer),
            ),
          ),
          TextButton(
            key: const Key('staff-access-form-reload'),
            onPressed: onReload,
            child: const Text('Recarregar'),
          ),
        ],
      ),
    );
  }
}
