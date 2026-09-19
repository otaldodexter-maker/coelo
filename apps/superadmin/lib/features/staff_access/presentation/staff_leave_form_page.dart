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

enum _LoadState { loading, ready, failure, unauthorized }

/// Criar/editar afastamento. Sem `leaveId` cria; com ele edita (e permite
/// remover). O servidor valida escopo, período e versão (PT409).
final class StaffLeaveFormPage extends StatefulWidget {
  const StaffLeaveFormPage({
    required this.repository,
    required this.onCancel,
    this.leave,
    this.initialMembershipId,
    this.onSaved,
    this.logout = unavailableSuperadminLogout,
    this.onDestinationSelected,
    super.key,
  });

  final StaffAccessRepository repository;
  final VoidCallback onCancel;

  /// Afastamento em edição (vem do diretório) ou null para criar.
  final StaffLeave? leave;

  /// Vínculo pré-selecionado ao criar (vindo da tela de acesso).
  final String? initialMembershipId;
  final ValueChanged<StaffLeave?>? onSaved;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  bool get editing => leave != null;

  @override
  State<StaffLeaveFormPage> createState() => _StaffLeaveFormPageState();
}

final class _StaffLeaveFormPageState extends State<StaffLeaveFormPage> {
  _LoadState _loadState = _LoadState.loading;
  List<StaffAccessItem> _memberships = const [];
  String? _membershipId;
  DateTime? _startsOn;
  DateTime? _endsOn;
  bool _popupEnabled = false;
  late final TextEditingController _note = TextEditingController(text: widget.leave?.internalNote ?? '');
  bool _saving = false;
  bool _conflict = false;
  String? _saveError;
  double _footerHeight = 0;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    final leave = widget.leave;
    _membershipId = leave?.membershipId ?? widget.initialMembershipId;
    _startsOn = leave?.startsOn;
    _endsOn = leave?.endsOn;
    _popupEnabled = leave?.popupEnabled ?? false;
    unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loadState = _LoadState.loading;
      _conflict = false;
      _saveError = null;
    });
    try {
      if (widget.editing) {
        // Recarrega o vínculo (com afastamentos) para ter a versão atual.
        final item = await widget.repository.fetchDetail(widget.leave!.membershipId);
        if (!mounted || revision != _revision) return;
        final current = item.leaves.where((l) => l.id == widget.leave!.id).firstOrNull;
        setState(() {
          _memberships = [item];
          _currentLeave = current ?? widget.leave;
          _startsOn = _currentLeave!.startsOn;
          _endsOn = _currentLeave!.endsOn;
          _popupEnabled = _currentLeave!.popupEnabled;
          _note.text = _currentLeave!.internalNote ?? '';
          _loadState = _LoadState.ready;
        });
      } else {
        final page = await widget.repository.fetchPage(const StaffAccessQuery(pageSize: 100));
        if (!mounted || revision != _revision) return;
        setState(() {
          _memberships = page.items;
          if (_membershipId != null && !page.items.any((i) => i.membershipId == _membershipId)) {
            _membershipId = null;
          }
          _loadState = _LoadState.ready;
        });
      }
    } on StaffAccessUnauthorizedException {
      if (mounted && revision == _revision) setState(() => _loadState = _LoadState.unauthorized);
    } on Object {
      if (mounted && revision == _revision) setState(() => _loadState = _LoadState.failure);
    }
  }

  StaffLeave? _currentLeave;

  bool get _valid =>
      _membershipId != null &&
      _startsOn != null &&
      _endsOn != null &&
      !_endsOn!.isBefore(_startsOn!) &&
      _note.text.length <= 500;

  Future<void> _save({bool remove = false}) async {
    if (_saving || (!remove && !_valid)) return;
    final revision = _revision;
    setState(() {
      _saving = true;
      _saveError = null;
      _conflict = false;
    });
    try {
      final saved = await widget.repository.saveLeave(
        leaveId: _currentLeave?.id,
        membershipId: _membershipId!,
        expectedVersion: _currentLeave?.version,
        draft: remove
            ? StaffLeaveDraft(startsOn: _startsOn!, endsOn: _endsOn!, popupEnabled: _popupEnabled, remove: true)
            : StaffLeaveDraft(
                startsOn: _startsOn!,
                endsOn: _endsOn!,
                popupEnabled: _popupEnabled,
                internalNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
      );
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
        setState(
          () => _saveError = switch (error.code) {
            'STAFF_ACCESS_LEAVE_PERIOD_INVALID' => 'O período precisa terminar depois de começar.',
            'STAFF_ACCESS_NOT_STAFF_MEMBERSHIP' => 'Este vínculo não é de funcionário.',
            'STAFF_ACCESS_SERVICE_PERSON' => 'Este vínculo pertence a uma conta de serviço.',
            _ => 'O servidor recusou o afastamento. Revise os campos.',
          },
        );
      }
    } on Object {
      if (mounted && revision == _revision) {
        setState(() => _saveError = 'Não foi possível salvar o afastamento. Tente novamente.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _saving = false);
    }
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Text('Remover afastamento?'),
        content: const Text('O acesso do vínculo volta a seguir só a regra de horário e vigência.'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: FilledButton(
                  key: const Key('staff-leave-remove-confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Remover'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save(remove: true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _memberships.where((i) => i.membershipId == _membershipId).firstOrNull;
    return SuperadminShell(
      logout: widget.logout,
      title: widget.editing ? 'Editar afastamento' : 'Registrar afastamento',
      subtitle: selected == null
          ? 'Período em que o vínculo não acessa o app.'
          : '${selected.personName} · ${selected.scopeLabel}',
      currentDestination: 'staff-leaves',
      onDestinationSelected: widget.onDestinationSelected,
      showChatLauncher: false,
      chatLauncherBottomInset: 0,
      child: LayoutBuilder(
        builder: (context, constraints) => ColoredBox(
          key: const Key('staff-leave-form-surface'),
          color: Theme.of(context).colorScheme.surface,
          child: switch (_loadState) {
            _LoadState.loading => const Center(child: CircularProgressIndicator()),
            _LoadState.failure => Center(
              child: CoeloStatePanel(
                title: 'Dados indisponíveis',
                message: 'Não foi possível carregar os vínculos.',
                icon: Icons.error_outline_rounded,
                actionLabel: 'Tentar novamente',
                onAction: _load,
              ),
            ),
            _LoadState.unauthorized => const Center(
              child: CoeloStatePanel(
                title: 'Acesso não autorizado',
                message: 'Seu contexto atual não permite registrar afastamentos.',
                icon: Icons.lock_outline_rounded,
              ),
            ),
            _LoadState.ready => SuperadminFormFrame(
              viewportWidth: constraints.maxWidth,
              scrollKey: const Key('staff-leave-form-scroll'),
              navigation: SuperadminFormStepNavigation(
                steps: [
                  SuperadminFormStep(
                    label: 'Vínculo',
                    status: _membershipId == null
                        ? SuperadminFormStepStatus.incomplete
                        : SuperadminFormStepStatus.complete,
                    enabled: false,
                  ),
                  const SuperadminFormStep(
                    label: 'Período e aviso',
                    status: SuperadminFormStepStatus.current,
                    enabled: false,
                  ),
                ],
                currentIndex: 1,
                onStepSelected: (_) {},
              ),
              body: _body(selected),
              footer: SuperadminFormActionFooter(
                surfaceKey: const Key('staff-leave-form-footer-surface'),
                onHeightChanged: (value) {
                  if (!mounted || (_footerHeight - value).abs() < .5) return;
                  setState(() => _footerHeight = value);
                },
                tertiaryAction: TextButton(
                  key: const Key('staff-leave-form-cancel'),
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text('Cancelar'),
                ),
                continuationActions: [
                  if (widget.editing)
                    OutlinedButton.icon(
                      key: const Key('staff-leave-form-remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _saving || _conflict ? null : _confirmRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remover'),
                    ),
                  FilledButton(
                    key: const Key('staff-leave-form-save'),
                    onPressed: _saving || _conflict || !_valid ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: CoeloSize.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.editing ? 'Salvar alterações' : 'Registrar'),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _body(StaffAccessItem? selected) {
    final theme = Theme.of(context);
    final status = context.coeloStatusColors;
    final invalidPeriod = _startsOn != null && _endsOn != null && _endsOn!.isBefore(_startsOn!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_conflict)
            Container(
              key: const Key('staff-leave-form-conflict'),
              margin: const EdgeInsets.only(bottom: CoeloSpacing.space4),
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
                      'Este afastamento foi alterado por outra pessoa. Recarregue para continuar.',
                      style: theme.textTheme.bodySmall?.copyWith(color: status.onWarningContainer),
                    ),
                  ),
                  TextButton(
                    key: const Key('staff-leave-form-reload'),
                    onPressed: _load,
                    child: const Text('Recarregar'),
                  ),
                ],
              ),
            ),
          if (_saveError != null)
            Container(
              key: const Key('staff-leave-form-error'),
              margin: const EdgeInsets.only(bottom: CoeloSpacing.space4),
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              decoration: BoxDecoration(
                color: status.errorContainer,
                borderRadius: BorderRadius.circular(CoeloRadius.md),
              ),
              child: Text(
                _saveError!,
                style: theme.textTheme.bodySmall?.copyWith(color: status.onErrorContainer),
              ),
            ),
          Text('Afastamento', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            'No período o funcionário não acessa o app por este vínculo; o afastamento prevalece sobre horário e vigência. Datas inclusivas.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          if (widget.editing)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vínculo',
                prefixIcon: Icon(Icons.badge_outlined),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              child: Text(selected == null ? '—' : '${selected.personName} · ${selected.scopeLabel}'),
            )
          else if (_memberships.isEmpty)
            const CoeloStatePanel(
              title: 'Nenhum vínculo disponível',
              message: 'Não há funcionários sob a sua gestão para afastar.',
              icon: Icons.badge_outlined,
            )
          else
            CoeloAdminSingleSelectField<String>(
              key: const Key('staff-leave-membership'),
              label: 'Vínculo',
              value: _membershipId ?? '',
              unselectedValue: '',
              options: ['', for (final item in _memberships) item.membershipId],
              optionLabel: (id) => id.isEmpty
                  ? 'Selecionar funcionário'
                  : () {
                      final item = _memberships.firstWhere((i) => i.membershipId == id);
                      return '${item.personName} · ${item.scopeLabel}';
                    }(),
              onChanged: (value) => setState(() => _membershipId = value.isEmpty ? null : value),
              prefixIcon: Icons.badge_outlined,
              searchable: true,
              searchHintText: 'Buscar funcionário',
            ),
          const SizedBox(height: CoeloSpacing.space4),
          LayoutBuilder(
            builder: (context, constraints) {
              final from = _LeaveDateField(
                key: const Key('staff-leave-starts-on'),
                label: 'De',
                value: _startsOn,
                onChanged: (value) => setState(() => _startsOn = value),
              );
              final until = _LeaveDateField(
                key: const Key('staff-leave-ends-on'),
                label: 'Até',
                value: _endsOn,
                onChanged: (value) => setState(() => _endsOn = value),
              );
              if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
                return Column(children: [from, const SizedBox(height: CoeloSpacing.space3), until]);
              }
              return Row(
                children: [
                  Expanded(child: from),
                  const SizedBox(width: CoeloSpacing.space4),
                  Expanded(child: until),
                ],
              );
            },
          ),
          if (invalidPeriod)
            Padding(
              padding: const EdgeInsets.only(top: CoeloSpacing.space2),
              child: Text(
                'O período precisa terminar depois de começar.',
                key: const Key('staff-leave-period-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminToggleField(
            key: const Key('staff-leave-popup-toggle'),
            label: 'Avisar o funcionário com popup',
            description: _popupEnabled
                ? 'Ao entrar no vínculo: "Você está afastado do app entre ${_startsOn == null ? '…' : staffAccessDateLabel(_startsOn!)} e ${_endsOn == null ? '…' : staffAccessDateLabel(_endsOn!)}".'
                : 'Sem popup, o funcionário vê "Este contexto não está disponível agora".',
            value: _popupEnabled,
            onChanged: (value) => setState(() => _popupEnabled = value),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            fieldKey: const Key('staff-leave-note'),
            controller: _note,
            labelText: 'Motivo interno (opcional)',
            hintText: 'Visível só para quem administra',
            maxLength: 500,
            prefixIcon: Icons.notes_outlined,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

final class _LeaveDateField extends StatelessWidget {
  const _LeaveDateField({required this.label, required this.value, required this.onChanged, super.key});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: '$label: ${value == null ? 'Não informada' : staffAccessDateLabel(value!)}',
    minHeight: CoeloSize.touchMin,
    onPressed: () async {
      final now = DateUtils.dateOnly(DateTime.now());
      final selected = await showCoeloDateRangePicker(
        context: context,
        value: value == null ? null : DateTimeRange(start: value!, end: value!),
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 10, 12, 31),
        currentDate: now,
        showQuickRanges: false,
        selectionMode: CoeloDateSelectionMode.single,
      );
      if (!context.mounted || selected == null) return;
      onChanged(DateUtils.dateOnly(selected.start));
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: Text(value == null ? 'Selecionar data' : staffAccessDateLabel(value!)),
    ),
  );
}
