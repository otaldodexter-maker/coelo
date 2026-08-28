import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/presentation/widgets/institution_form_dialogs.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/access_profile.dart';

String? _profileNameError(String? value) =>
    value == null || value.trim().isEmpty ? 'Informe o nome do perfil.' : null;

String? _profileCodeError(String? value) {
  final code = value?.trim() ?? '';
  if (code.isEmpty) return 'Informe o código.';
  if (!RegExp(r'^[a-z][a-z0-9._]*$').hasMatch(code)) {
    return 'Use o formato exemplo.perfil.';
  }
  return null;
}

String? _profileDescriptionError(String? value) =>
    value == null || value.trim().isEmpty ? 'Explique o propósito do perfil.' : null;

final class AccessProfileFormPage extends StatefulWidget {
  const AccessProfileFormPage({
    required this.repository,
    required this.logout,
    required this.domain,
    required this.onCancel,
    required this.onSaved,
    this.profileId,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.entityLabel = 'perfil',
    this.currentDestination = 'profiles',
    super.key,
  });

  final AccessProfileRepository repository;
  final LogoutAction logout;
  final AccessProfileDomain domain;
  final String? profileId;
  final VoidCallback onCancel;
  final ValueChanged<AccessProfile> onSaved;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String entityLabel;
  final String currentDestination;

  @override
  State<AccessProfileFormPage> createState() => _AccessProfileFormPageState();
}

final class _AccessProfileFormPageState extends State<AccessProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _permissionSearchController = TextEditingController();
  final _reasonController = TextEditingController();
  late final SuperadminActivityController _activityController;
  AccessProfile? _original;
  AccessProfileStatus _status = AccessProfileStatus.active;
  AccessProfileScope _scope = AccessProfileScope.platform;
  List<AccessPermission> _permissions = const [];
  int _currentStep = 0;
  int _furthestStep = 0;
  bool _loading = true;
  bool _saving = false;
  bool _showIdentityErrors = false;
  double _footerHeight = 0;
  String? _error;
  String? _pendingSaveRequestId;
  String? _pendingSaveFingerprint;

  bool get _editing => widget.profileId != null;

  List<String> get _stepLabels => [
    'Perfil e escopo',
    'Permissões',
    if (_editing) 'Pessoas vinculadas',
    'Revisão',
  ];

  bool get _lastStep => _currentStep == _stepLabels.length - 1;

  bool get _isDirty {
    final original = _original;
    if (original == null) return false;
    final selected = _permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    final originalSelected = original.permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    return _nameController.text.trim() != original.name ||
        _codeController.text.trim().toLowerCase() != original.code ||
        _descriptionController.text.trim() != original.description ||
        _status != original.status ||
        _scope != original.maxScope ||
        selected.length != originalSelected.length ||
        !selected.containsAll(originalSelected);
  }

  @override
  void initState() {
    super.initState();
    _activityController = SuperadminActivityController();
    for (final controller in [
      _nameController,
      _codeController,
      _descriptionController,
      _reasonController,
    ]) {
      controller.addListener(_onDraftChanged);
    }
    _load();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final profile = _editing
          ? await widget.repository.fetchDetail(widget.domain, widget.profileId!)
          : await widget.repository.fetchTemplate(widget.domain);
      if (!mounted) return;
      _original = profile;
      _nameController.text = profile.name;
      _codeController.text = profile.code;
      _descriptionController.text = profile.description;
      setState(() {
        _status = profile.status;
        _scope = profile.maxScope;
        _permissions = profile.permissions;
        _loading = false;
      });
    } on AccessProfileUnauthorizedException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o formulário.';
        _loading = false;
      });
    }
  }

  Future<void> _requestExit() async {
    if (!_isDirty || await showInstitutionExitDialog(context, entityLabel: widget.entityLabel)) {
      widget.onCancel();
    }
  }

  Future<void> _requestDestination(String destination) async {
    if (!_isDirty || await showInstitutionExitDialog(context, entityLabel: widget.entityLabel)) {
      widget.onDestinationSelected?.call(destination);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _permissionSearchController.dispose();
    _reasonController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  AccessProfile _draft() => _original!.copyWith(
    name: _nameController.text.trim(),
    code: _codeController.text.trim().toLowerCase(),
    description: _descriptionController.text.trim(),
    status: _status,
    maxScope: _scope,
    permissions: _permissions,
  );

  bool get _identityDraftIsValid =>
      _profileNameError(_nameController.text) == null &&
      _profileCodeError(_codeController.text) == null &&
      _profileDescriptionError(_descriptionController.text) == null;

  bool _validateIdentity() {
    if (_currentStep == 0) {
      if (!_showIdentityErrors) setState(() => _showIdentityErrors = true);
      return _formKey.currentState?.validate() ?? false;
    }
    if (_identityDraftIsValid) return true;
    setState(() {
      _currentStep = 0;
      _showIdentityErrors = true;
    });
    return false;
  }

  void _selectStep(int index) {
    if (index > _furthestStep || index == _currentStep) return;
    if (index > _currentStep && !_validateIdentity()) return;
    setState(() => _currentStep = index);
  }

  void _continue() {
    if (_currentStep == 0 && !_validateIdentity()) return;
    if (_lastStep) return;
    setState(() {
      _currentStep += 1;
      _furthestStep = math.max(_furthestStep, _currentStep);
    });
  }

  void _previous() {
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
  }

  Future<void> _save() async {
    if (!_validateIdentity()) return;
    if (_reasonController.text.trim().isEmpty) return;
    final draft = _draft();
    setState(() => _saving = true);
    final fingerprint = '${draft.toDraftJson()}|${_reasonController.text.trim()}';
    if (_pendingSaveFingerprint != fingerprint) {
      _pendingSaveFingerprint = fingerprint;
      _pendingSaveRequestId = _newRequestId();
    }
    try {
      final saved = await widget.repository.save(
        requestId: _pendingSaveRequestId!,
        expectedVersion: _original!.version,
        reason: _reasonController.text.trim(),
        draft: draft,
      );
      if (!mounted) return;
      _pendingSaveRequestId = null;
      _pendingSaveFingerprint = null;
      widget.onSaved(saved);
    } on AccessProfileConflictException {
      _pendingSaveRequestId = null;
      _pendingSaveFingerprint = null;
      if (!mounted) return;
      final reload = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => CoeloAdminDialogShell(
          title: 'Alterações em conflito',
          body: const Text(
            'Outra pessoa alterou este perfil. Recarregue a referência; seu rascunho será preservado.',
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Agora não'),
          ),
          primaryAction: FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Recarregar referência'),
          ),
        ),
      );
      if (reload == true) await _reloadReferencePreservingDraft();
    } on AccessProfileException catch (error) {
      if (mounted) {
        showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadReferencePreservingDraft() async {
    final selectedCodes = _permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    try {
      final latest = await widget.repository.fetchDetail(widget.domain, widget.profileId!);
      if (!mounted) return;
      setState(() {
        _original = latest;
        _permissions = latest.permissions
            .map((permission) => permission.withSelection(selectedCodes.contains(permission.code)))
            .toList(growable: false);
      });
      showSuperadminNotice(
        context,
        'Referência atualizada. Revise novamente o rascunho preservado.',
        icon: Icons.sync_rounded,
      );
    } on AccessProfileException catch (error) {
      if (mounted) {
        showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      }
    }
  }

  List<SuperadminFormStep> _steps() => [
    for (var index = 0; index < _stepLabels.length; index++)
      SuperadminFormStep(
        label: _stepLabels[index],
        enabled: index <= _furthestStep,
        status: index == _currentStep
            ? SuperadminFormStepStatus.current
            : index <= _furthestStep
            ? SuperadminFormStepStatus.complete
            : SuperadminFormStepStatus.incomplete,
      ),
  ];

  Widget _stepContent() {
    if (_currentStep == 0) {
      return _IdentitySection(
        nameController: _nameController,
        codeController: _codeController,
        descriptionController: _descriptionController,
        status: _status,
        scope: _scope,
        domain: widget.domain,
        onStatusChanged: (value) => setState(() => _status = value),
        onScopeChanged: (value) => setState(() => _scope = value),
      );
    }
    if (_currentStep == 1) {
      return _PermissionMatrix(
        permissions: _permissions,
        searchController: _permissionSearchController,
        onChanged: (permissions) => setState(() => _permissions = permissions),
      );
    }
    if (_editing && _currentStep == 2) {
      return _MembershipSection(links: _original!.links);
    }
    final draft = _draft();
    return _ReviewSection(
      original: _original!,
      draft: draft,
      review: AccessProfileReview.compare(_original!, draft),
      reasonController: _reasonController,
    );
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: _editing ? 'Editar ${widget.entityLabel}' : 'Criar ${widget.entityLabel}',
    subtitle: '${widget.domain.title} · configure identidade, escopo e permissões.',
    currentDestination: widget.currentDestination,
    activityController: _activityController,
    showChatLauncher: widget.onConversationsOpen != null,
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    onDestinationSelected: widget.onDestinationSelected == null ? null : _requestDestination,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    onOpenConversations: widget.onConversationsOpen,
    child: _loading
        ? const CoeloStatePanel(
            title: 'Carregando perfil',
            message: 'Aguarde enquanto consultamos o catálogo.',
            loading: true,
          )
        : _error != null
        ? CoeloStatePanel(
            title: 'Não foi possível abrir o perfil',
            message: _error!,
            icon: Icons.error_outline_rounded,
            actionLabel: 'Voltar',
            onAction: widget.onCancel,
          )
        : PopScope<void>(
            canPop: !_isDirty,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _requestExit();
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sideNavigation = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
                final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                    ? CoeloSpacing.space10
                    : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                    ? CoeloSpacing.space6
                    : CoeloSpacing.space4;
                final navigation = SuperadminFormStepNavigation(
                  steps: _steps(),
                  currentIndex: _currentStep,
                  onStepSelected: _selectStep,
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sideNavigation) ...[
                        navigation,
                        const SizedBox(width: CoeloSpacing.space6),
                      ],
                      Expanded(
                        child: IgnorePointer(
                          ignoring: _saving,
                          child: Form(
                            key: _formKey,
                            autovalidateMode: _showIdentityErrors
                                ? AutovalidateMode.always
                                : AutovalidateMode.disabled,
                            child: Column(
                              children: [
                                if (!sideNavigation) ...[
                                  navigation,
                                  const SizedBox(height: CoeloSpacing.space4),
                                ],
                                Expanded(
                                  child: SingleChildScrollView(
                                    key: const Key('access-profile-form-scroll'),
                                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 1000),
                                        child: AnimatedSwitcher(
                                          duration: MediaQuery.disableAnimationsOf(context)
                                              ? Duration.zero
                                              : CoeloMotion.short,
                                          child: KeyedSubtree(
                                            key: ValueKey(_currentStep),
                                            child: _stepContent(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _FormFooter(
                                  editing: _editing,
                                  currentStep: _currentStep,
                                  lastStep: _lastStep,
                                  saving: _saving,
                                  canSave: _reasonController.text.trim().isNotEmpty,
                                  onCancel: _requestExit,
                                  onPrevious: _previous,
                                  onContinue: _continue,
                                  onSave: _save,
                                  onHeightChanged: (height) {
                                    if ((_footerHeight - height).abs() < .5) return;
                                    setState(() => _footerHeight = height);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
  );
}

final class _FormFooter extends StatelessWidget {
  const _FormFooter({
    required this.editing,
    required this.currentStep,
    required this.lastStep,
    required this.saving,
    required this.canSave,
    required this.onCancel,
    required this.onPrevious,
    required this.onContinue,
    required this.onSave,
    required this.onHeightChanged,
  });

  final bool editing;
  final int currentStep;
  final bool lastStep;
  final bool saving;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onPrevious;
  final VoidCallback onContinue;
  final VoidCallback onSave;
  final ValueChanged<double> onHeightChanged;

  @override
  Widget build(BuildContext context) => SuperadminFormActionFooter(
    surfaceKey: const Key('access-profile-form-footer-surface'),
    onHeightChanged: onHeightChanged,
    tertiaryAction: TextButton(
      key: const Key('access-profile-cancel'),
      onPressed: saving ? null : onCancel,
      child: const Text('Cancelar'),
    ),
    continuationActions: [
      if (currentStep > 0)
        OutlinedButton(
          key: const Key('access-profile-previous'),
          onPressed: saving ? null : onPrevious,
          child: const Text('Anterior'),
        ),
      if (!lastStep)
        if (editing)
          OutlinedButton(
            key: const Key('access-profile-continue'),
            onPressed: saving ? null : onContinue,
            child: const Text('Continuar'),
          )
        else
          FilledButton(
            key: const Key('access-profile-continue'),
            onPressed: saving ? null : onContinue,
            child: const Text('Continuar'),
          ),
      if (lastStep)
        FilledButton(
          key: const Key('access-profile-save'),
          onPressed: saving || !canSave ? null : onSave,
          child: saving
              ? const SizedBox.square(
                  dimension: CoeloSize.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(editing ? 'Salvar alterações' : 'Criar perfil'),
        ),
    ],
  );
}

final class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.nameController,
    required this.codeController,
    required this.descriptionController,
    required this.status,
    required this.scope,
    required this.domain,
    required this.onStatusChanged,
    required this.onScopeChanged,
  });

  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController descriptionController;
  final AccessProfileStatus status;
  final AccessProfileScope scope;
  final AccessProfileDomain domain;
  final ValueChanged<AccessProfileStatus> onStatusChanged;
  final ValueChanged<AccessProfileScope> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final scopes = domain == AccessProfileDomain.platform
        ? const [AccessProfileScope.platform, AccessProfileScope.institution]
        : const [AccessProfileScope.institution, AccessProfileScope.unit, AccessProfileScope.group];
    return _FormSurface(
      title: 'Perfil e escopo',
      description:
          'Este perfil pertence ao contexto ${domain.label}; o escopo máximo limita futuras atribuições.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          final identityFields = [
            CoeloFormTextField(
              controller: nameController,
              labelText: 'Nome do perfil',
              prefixIcon: Icons.badge_outlined,
              validator: _profileNameError,
            ),
            CoeloFormTextField(
              controller: codeController,
              labelText: 'Código',
              prefixIcon: Icons.code_rounded,
              hintText: 'exemplo.perfil',
              validator: _profileCodeError,
            ),
          ];
          return Column(
            children: [
              _ResponsiveFieldRow(stacked: stacked, children: identityFields),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                controller: descriptionController,
                labelText: 'Descrição',
                prefixIcon: Icons.description_outlined,
                maxLines: 2,
                validator: _profileDescriptionError,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _ResponsiveFieldRow(
                stacked: stacked,
                children: [
                  CoeloAdminSingleSelectField(
                    label: 'Status',
                    value: status,
                    options: AccessProfileStatus.values,
                    optionLabel: (value) => value.label,
                    onChanged: onStatusChanged,
                  ),
                  CoeloAdminSingleSelectField(
                    label: 'Escopo máximo',
                    value: scope,
                    options: scopes,
                    optionLabel: (value) => value.label,
                    onChanged: onScopeChanged,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({required this.stacked, required this.children});

  final bool stacked;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: CoeloSpacing.space4),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index < children.length - 1) const SizedBox(width: CoeloSpacing.space3),
        ],
      ],
    );
  }
}

final class _PermissionMatrix extends StatefulWidget {
  const _PermissionMatrix({
    required this.permissions,
    required this.searchController,
    required this.onChanged,
  });

  final List<AccessPermission> permissions;
  final TextEditingController searchController;
  final ValueChanged<List<AccessPermission>> onChanged;

  @override
  State<_PermissionMatrix> createState() => _PermissionMatrixState();
}

final class _PermissionMatrixState extends State<_PermissionMatrix> {
  late String _search;

  @override
  void initState() {
    super.initState();
    _search = widget.searchController.text;
  }

  void _toggle(AccessPermission target, bool selected) {
    widget.onChanged(
      widget.permissions
          .map(
            (permission) =>
                permission.code == target.code ? permission.withSelection(selected) : permission,
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = widget.permissions
        .where((permission) {
          return query.isEmpty ||
              permission.name.toLowerCase().contains(query) ||
              permission.module.toLowerCase().contains(query) ||
              permission.screenCode.toLowerCase().contains(query) ||
              permission.actionCode.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final modules = <String, List<AccessPermission>>{};
    for (final permission in filtered) {
      modules.putIfAbsent(permission.module, () => []).add(permission);
    }
    return _FormSurface(
      surfaceKey: const Key('access-profile-permission-matrix'),
      title: 'Permissões',
      description:
          'A matriz usa módulo, tela e ações reais. Itens herdados ou indisponíveis explicam por que não podem ser alterados.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloSearchField(
            controller: widget.searchController,
            hintText: 'Buscar permissão',
            semanticLabel: 'Buscar permissão por módulo, tela ou ação',
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          if (modules.isEmpty)
            const CoeloStatePanel(
              title: 'Nenhuma permissão encontrada',
              message: 'Revise o termo pesquisado.',
              icon: Icons.search_off_rounded,
            )
          else
            for (var index = 0; index < modules.length; index++) ...[
              _PermissionModule(
                module: modules.keys.elementAt(index),
                permissions: modules.values.elementAt(index),
                onToggle: _toggle,
              ),
              if (index < modules.length - 1) const SizedBox(height: CoeloSpacing.space4),
            ],
        ],
      ),
    );
  }
}

final class _PermissionModule extends StatelessWidget {
  const _PermissionModule({
    required this.module,
    required this.permissions,
    required this.onToggle,
  });

  final String module;
  final List<AccessPermission> permissions;
  final void Function(AccessPermission permission, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screens = <String, List<AccessPermission>>{};
    for (final permission in permissions) {
      screens.putIfAbsent(permission.screenCode, () => []).add(permission);
    }
    final actions = permissions.map((item) => item.actionCode).toSet().toList()
      ..sort((left, right) => _actionOrder(left).compareTo(_actionOrder(right)));
    final unavailable = permissions
        .where((item) => !item.grantable || item.inherited)
        .toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              children: [
                Expanded(child: Text(module, style: Theme.of(context).textTheme.titleMedium)),
                Text(
                  '${permissions.where((item) => item.selected).length} de ${permissions.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final requiredWidth = 220 + actions.length * 112;
                if (constraints.maxWidth >= requiredWidth) {
                  return _DesktopPermissionMatrix(
                    module: module,
                    screens: screens,
                    actions: actions,
                    onToggle: onToggle,
                  );
                }
                return _StackedPermissionMatrix(
                  module: module,
                  screens: screens,
                  onToggle: onToggle,
                );
              },
            ),
          ),
          if (unavailable.isNotEmpty) ...[
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Restrições', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: CoeloSpacing.space2),
                  for (final permission in unavailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
                      child: Text(
                        '${permission.name}: ${_unavailableReason(permission)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _DesktopPermissionMatrix extends StatelessWidget {
  const _DesktopPermissionMatrix({
    required this.module,
    required this.screens,
    required this.actions,
    required this.onToggle,
  });

  final String module;
  final Map<String, List<AccessPermission>> screens;
  final List<String> actions;
  final void Function(AccessPermission permission, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tela',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            for (final action in actions)
              SizedBox(
                width: 112,
                child: Text(
                  _actionLabel(action),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space2),
        for (var index = 0; index < screens.length; index++) ...[
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _screenLabel(screens.keys.elementAt(index), module),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final action in actions)
                  SizedBox(
                    width: 112,
                    child:
                        screens.values
                                .elementAt(index)
                                .where((item) => item.actionCode == action)
                                .firstOrNull ==
                            null
                        ? Center(
                            child: Text('—', style: TextStyle(color: colors.onSurfaceVariant)),
                          )
                        : _PermissionActionCell(
                            permission: screens.values
                                .elementAt(index)
                                .firstWhere((item) => item.actionCode == action),
                            showLabel: false,
                            onToggle: onToggle,
                          ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

final class _StackedPermissionMatrix extends StatelessWidget {
  const _StackedPermissionMatrix({
    required this.module,
    required this.screens,
    required this.onToggle,
  });

  final String module;
  final Map<String, List<AccessPermission>> screens;
  final void Function(AccessPermission permission, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var index = 0; index < screens.length; index++) ...[
          Container(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _screenLabel(screens.keys.elementAt(index), module),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: CoeloSpacing.space2),
                for (final permission in screens.values.elementAt(index))
                  _PermissionActionCell(
                    permission: permission,
                    showLabel: true,
                    onToggle: onToggle,
                  ),
              ],
            ),
          ),
          if (index < screens.length - 1) const SizedBox(height: CoeloSpacing.space3),
        ],
      ],
    );
  }
}

final class _PermissionActionCell extends StatefulWidget {
  const _PermissionActionCell({
    required this.permission,
    required this.showLabel,
    required this.onToggle,
  });

  final AccessPermission permission;
  final bool showLabel;
  final void Function(AccessPermission permission, bool selected) onToggle;

  @override
  State<_PermissionActionCell> createState() => _PermissionActionCellState();
}

final class _PermissionActionCellState extends State<_PermissionActionCell> {
  late final FocusNode _focusNode = FocusNode(debugLabel: 'permission-${widget.permission.code}');
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permission = widget.permission;
    final enabled = permission.grantable && !permission.inherited;
    final colors = Theme.of(context).colorScheme;
    final reason = enabled ? null : _unavailableReason(permission);
    final checkbox = ExcludeSemantics(
      child: ExcludeFocus(
        child: IgnorePointer(
          child: Checkbox(
            value: permission.selected,
            onChanged: enabled ? (value) => widget.onToggle(permission, value ?? false) : null,
          ),
        ),
      ),
    );
    return Semantics(
      key: Key('permission-${permission.code}'),
      container: true,
      enabled: enabled,
      checked: permission.selected,
      label:
          '${_actionLabel(permission.actionCode)} em ${_screenLabel(permission.screenCode, permission.module)}'
          '${reason == null ? '' : '. Indisponível. $reason'}',
      child: FocusableActionDetector(
        key: Key('permission-focus-${permission.code}'),
        focusNode: _focusNode,
        enabled: enabled,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle(permission, !permission.selected);
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: MouseRegion(
          onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
          onExit: enabled ? (_) => setState(() => _hovered = false) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => widget.onToggle(permission, !permission.selected) : null,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.fast,
              constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
              padding: const EdgeInsets.symmetric(
                horizontal: CoeloSpacing.space1,
                vertical: CoeloSpacing.space1,
              ),
              decoration: BoxDecoration(
                color: _hovered || _focused ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(CoeloRadius.md),
              ),
              child: Row(
                children: widget.showLabel
                    ? [
                        checkbox,
                        const SizedBox(width: CoeloSpacing.space1),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_actionLabel(permission.actionCode)),
                              if (permission.requiresMfa || permission.risk == 'critical')
                                Text(
                                  [
                                    if (permission.requiresMfa) 'MFA',
                                    if (permission.risk == 'critical') 'Crítico',
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              checkbox,
                              if (permission.requiresMfa || permission.risk == 'critical')
                                Text(
                                  [
                                    if (permission.requiresMfa) 'MFA',
                                    if (permission.risk == 'critical') 'Crítico',
                                  ].join(' · '),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _MembershipSection extends StatelessWidget {
  const _MembershipSection({required this.links});

  final List<AccessProfileLink> links;

  @override
  Widget build(BuildContext context) => _FormSurface(
    title: 'Pessoas vinculadas',
    description:
        'Consulta somente leitura das pessoas que recebem este perfil e do escopo efetivo atual.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (links.isEmpty) ...[
          const CoeloStatePanel(
            title: 'Nenhuma pessoa vinculada',
            message: 'Este perfil ainda não possui vínculos ativos.',
            icon: Icons.people_outline_rounded,
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        CoeloAdminResizableTable<AccessProfileLink>(
          key: const Key('access-profile-membership-table'),
          items: links,
          rowKey: (link) => link.id,
          pinnedColumn: CoeloAdminTableColumn(
            id: 'person',
            label: 'Pessoa',
            initialWidth: 300,
            minWidth: 220,
            maxWidth: 420,
            cellBuilder: (context, link) =>
                Text(link.personName, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          columns: [
            CoeloAdminTableColumn(
              id: 'scope',
              label: 'Escopo efetivo',
              initialWidth: 320,
              minWidth: 220,
              maxWidth: 480,
              cellBuilder: (context, link) =>
                  Text(link.scope, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
          headerHeight: 56,
          rowHeight: 64,
        ),
      ],
    ),
  );
}

final class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.original,
    required this.draft,
    required this.review,
    required this.reasonController,
  });

  final AccessProfile original;
  final AccessProfile draft;
  final AccessProfileReview review;
  final TextEditingController reasonController;

  @override
  Widget build(BuildContext context) => _FormSurface(
    title: 'Revisão',
    description: 'Confirme o impacto antes de enviar a alteração auditável ao servidor.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewGroup(
          title: 'Permissões adicionadas',
          values: review.addedCodes,
          emptyLabel: 'Nenhuma permissão adicionada.',
          icon: Icons.add_circle_outline_rounded,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ReviewGroup(
          title: 'Permissões removidas',
          values: review.removedCodes,
          emptyLabel: 'Nenhuma permissão removida.',
          icon: Icons.remove_circle_outline_rounded,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ReviewFact(
          icon: Icons.badge_outlined,
          title: 'Identidade e status',
          value:
              'Nome: de ${original.name} para ${draft.name}\n'
              'Código: de ${original.code} para ${draft.code}\n'
              'Status: de ${original.status.label} para ${draft.status.label}',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _ReviewFact(
          icon: Icons.layers_outlined,
          title: 'Escopo máximo',
          value: review.scopeChanged
              ? 'De ${original.maxScope.label} para ${draft.maxScope.label}.'
              : 'Sem alteração (${draft.maxScope.label}).',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _ReviewFact(
          icon: Icons.people_outline_rounded,
          title: '${original.membershipCount} vínculos impactados',
          value:
              draft.permissions.any((permission) => permission.selected && permission.requiresMfa)
              ? 'O perfil inclui permissões que exigem MFA.'
              : 'Nenhuma permissão selecionada exige MFA adicional.',
        ),
        if (review.isSensitive) ...[
          const SizedBox(height: CoeloSpacing.space4),
          const CoeloStatePanel(
            title: 'Alteração sensível',
            message:
                'O servidor revalidará MFA, autoridade, escopo e concorrência antes de salvar.',
            icon: Icons.gpp_maybe_outlined,
          ),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: reasonController,
          labelText: 'Motivo da alteração',
          prefixIcon: Icons.notes_rounded,
          hintText: 'Obrigatório para a trilha de auditoria.',
          maxLines: 2,
        ),
      ],
    ),
  );
}

final class _ReviewFact extends StatelessWidget {
  const _ReviewFact({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: CoeloSize.iconSm),
      const SizedBox(width: CoeloSpacing.space2),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CoeloSpacing.space1),
            Text(value),
          ],
        ),
      ),
    ],
  );
}

final class _ReviewGroup extends StatelessWidget {
  const _ReviewGroup({
    required this.title,
    required this.values,
    required this.emptyLabel,
    required this.icon,
  });

  final String title;
  final List<String> values;
  final String emptyLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: CoeloSize.iconSm),
          const SizedBox(width: CoeloSpacing.space2),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(values.isEmpty ? emptyLabel : values.join('\n')),
    ],
  );
}

final class _FormSurface extends StatelessWidget {
  const _FormSurface({
    required this.title,
    required this.description,
    required this.child,
    this.surfaceKey,
  });

  final String title;
  final String description;
  final Widget child;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: surfaceKey,
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space6),
          child,
        ],
      ),
    );
  }
}

String _unavailableReason(AccessPermission permission) {
  if (permission.inherited) return 'Herdada; não pode ser alterada neste perfil.';
  return permission.unavailableReason ?? 'Indisponível para concessão.';
}

int _actionOrder(String action) => switch (action) {
  'read' || 'view' || 'list' => 0,
  'create' => 1,
  'update' || 'edit' => 2,
  'delete' => 3,
  _ => 4,
};

String _actionLabel(String action) => switch (action) {
  'read' || 'view' || 'list' => 'Ver',
  'create' => 'Criar',
  'update' || 'edit' => 'Editar',
  'delete' => 'Excluir',
  'manage' => 'Gerenciar',
  'moderate' => 'Moderar',
  'access' => 'Acessar',
  _ => _humanize(action),
};

String _screenLabel(String screen, String module) => switch (screen) {
  'general' => module,
  'platform' => 'Plataforma',
  'audit' => 'Auditoria',
  'access_profiles' => 'Perfis e permissões',
  'support' => 'Suporte',
  'people' => 'Pessoas',
  'attendance' => 'Frequência',
  'chat' => 'Conversas',
  _ => _humanize(screen),
};

String _humanize(String value) {
  final words = value.replaceAll('_', ' ').replaceAll('.', ' ').trim();
  if (words.isEmpty) return 'Geral';
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

String _newRequestId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String part(int start, int end) =>
      bytes.sublist(start, end).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${part(0, 4)}-${part(4, 6)}-${part(6, 8)}-'
      '${part(8, 10)}-${part(10, 16)}';
}
