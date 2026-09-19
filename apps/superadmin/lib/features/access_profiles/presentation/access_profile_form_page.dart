import 'dart:async';
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
import '../../support/domain/support_ticket.dart';
import '../domain/access_profile.dart';
import 'access_permission_labels.dart';

String? _profileNameError(String? value) =>
    value == null || value.trim().isEmpty ? 'Informe o nome do perfil.' : null;

String? _profileCodeError(String? value) {
  final code = value?.trim() ?? '';
  if (code.isEmpty) return 'Informe o código.';
  // Hifen aceito: o servidor gera codigos como professor-qa-r05-19fa6f3d e a
  // edicao de um perfil existente nao pode falhar na validacao do cliente.
  if (!RegExp(r'^[a-z][a-z0-9._-]*$').hasMatch(code)) {
    return 'Use o formato exemplo.perfil.';
  }
  return null;
}

String? _profileDescriptionError(String? value) =>
    value == null || value.trim().isEmpty ? 'Explique o propósito do perfil.' : null;

String _generatedProfileCode(String name) {
  final code = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return code.isEmpty ? 'perfil-novo' : code;
}

final class AccessProfileFormPage extends StatefulWidget {
  const AccessProfileFormPage({
    required this.repository,
    required this.logout,
    required this.domain,
    required this.onCancel,
    required this.onSaved,
    this.profileId,
    this.sourceProfileId,
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

  /// Perfil (normalmente um modelo do sistema, P31) cujas permissões e escopo
  /// preenchem o rascunho de criação. Só vale sem [profileId].
  final String? sourceProfileId;
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
  VoidCallback? _confirmedCompletion;
  int _contextRevision = 0;
  final Set<DialogRoute<bool>> _ownedDialogs = {};
  bool _confirmingExit = false;

  bool _isCurrent(int revision) => mounted && revision == _contextRevision;

  bool get _editing => widget.profileId != null;

  List<String> get _stepLabels => [
    'Perfil e escopo',
    'Permissões',
    if (_editing) 'Pessoas vinculadas',
    'Revisão',
  ];

  bool get _lastStep => _currentStep == _stepLabels.length - 1;

  bool get _isDirty {
    if (_confirmedCompletion != null) return false;
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

  @override
  void didUpdateWidget(covariant AccessProfileFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.domain != widget.domain ||
        oldWidget.profileId != widget.profileId) {
      _contextRevision++;
      _confirmedCompletion = null;
      _dismissOwnedDialogs();
      _confirmingExit = false;
      _original = null;
      _loading = true;
      _saving = false;
      _error = null;
      _pendingSaveRequestId = null;
      _pendingSaveFingerprint = null;
      _permissions = const [];
      _status = AccessProfileStatus.active;
      _scope = AccessProfileScope.platform;
      _currentStep = 0;
      _furthestStep = 0;
      _showIdentityErrors = false;
      for (final controller in [
        _nameController,
        _codeController,
        _descriptionController,
        _permissionSearchController,
        _reasonController,
      ]) {
        controller.clear();
      }
      _load();
    }
  }

  Future<void> _load() async {
    final revision = _contextRevision;
    try {
      final profile = _editing
          ? await widget.repository.fetchDetail(widget.domain, widget.profileId!)
          : await widget.repository.fetchTemplate(widget.domain);
      // A partir de um modelo (P31): o original continua o rascunho em branco,
      // para a revisão listar as permissões herdadas como adicionadas; só o
      // que o operador vê no formulário vem do modelo.
      final sourceProfileId = widget.sourceProfileId;
      final draft = !_editing && sourceProfileId != null
          ? _draftFromSource(
              profile,
              await widget.repository.fetchDetail(widget.domain, sourceProfileId),
            )
          : profile;
      if (!_isCurrent(revision)) return;
      _original = profile;
      _nameController.text = draft.name;
      _codeController.text = draft.code;
      _descriptionController.text = draft.description;
      setState(() {
        _status = draft.status;
        _scope = draft.maxScope;
        _permissions = draft.permissions;
        _loading = false;
      });
    } on AccessProfileUnauthorizedException catch (error) {
      if (!_isCurrent(revision)) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!_isCurrent(revision)) return;
      setState(() {
        _error = 'Não foi possível carregar o formulário.';
        _loading = false;
      });
    }
  }

  /// Rascunho novo (id vazio) com as permissões e o escopo do modelo de
  /// origem; nome e código ficam em branco para o operador definir.
  static AccessProfile _draftFromSource(AccessProfile template, AccessProfile source) {
    final selected = source.permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    return template.copyWith(
      description: source.description,
      maxScope: source.maxScope,
      permissions: template.permissions
          .map((permission) => permission.withSelection(selected.contains(permission.code)))
          .toList(growable: false),
    );
  }

  Future<void> _requestExit() => _confirmExit(widget.onCancel);

  Future<void> _requestDestination(String destination) {
    final onDestinationSelected = widget.onDestinationSelected;
    return _confirmExit(() => onDestinationSelected?.call(destination));
  }

  Future<void> _confirmExit(VoidCallback onConfirmed) async {
    if (_confirmingExit) return;
    final revision = _contextRevision;
    _confirmingExit = true;
    try {
      if (!_isDirty || await _showExitDialog()) {
        if (!_isCurrent(revision)) return;
        onConfirmed();
      }
    } finally {
      if (_isCurrent(revision)) _confirmingExit = false;
    }
  }

  // Preserve the approved Institutions confirmation content with a route owned
  // by this form, so teardown cannot leave it over a different access context.
  Future<bool> _showExitDialog() => _showOwnedDialog(
    builder: (context) => CoeloAdminDialogShell(
      dialogKey: const Key('institution-confirm-exit-dialog'),
      title: 'Sair sem salvar?',
      closeTooltip: 'Fechar confirmação',
      closeButtonKey: const Key('institution-dialog-close'),
      body: Text('As alterações feitas nesta ${widget.entityLabel} serão descartadas.'),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Continuar editando'),
      ),
      primaryAction: FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Sair sem salvar'),
      ),
    ),
  );

  Future<bool> _showOwnedDialog({required WidgetBuilder builder}) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      barrierColor: context.coeloScrim,
      builder: builder,
    );
    _ownedDialogs.add(route);
    try {
      unawaited(navigator.push<bool>(route));
      return await route.completed ?? false;
    } finally {
      _ownedDialogs.remove(route);
    }
  }

  void _dismissOwnedDialogs() {
    final routes = _ownedDialogs.toList(growable: false);
    _ownedDialogs.clear();
    if (routes.isEmpty) return;
    // didUpdateWidget/dispose can run while Navigator is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _contextRevision++;
    _dismissOwnedDialogs();
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _permissionSearchController.dispose();
    _reasonController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  /// Rascunho atual, para testes de widget.
  @visibleForTesting
  AccessProfile get debugDraft => _draft();

  AccessProfile _draft() => _original!.copyWith(
    name: _nameController.text.trim(),
    // Keep the technical identifier in the contract without exposing it in
    // the operational form. Existing identifiers remain immutable to users.
    code: _editing
        ? _codeController.text.trim().toLowerCase()
        : _generatedProfileCode(_nameController.text),
    description: _descriptionController.text.trim(),
    status: _status,
    maxScope: _scope,
    permissions: _permissions,
  );

  bool get _identityDraftIsValid =>
      _profileNameError(_nameController.text) == null &&
      _profileCodeError(
            _editing ? _codeController.text : _generatedProfileCode(_nameController.text),
          ) ==
          null &&
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
    if (_confirmedCompletion != null) return;
    if (index > _furthestStep || index == _currentStep) return;
    if (index > _currentStep && !_validateIdentity()) return;
    setState(() => _currentStep = index);
  }

  void _continue() {
    if (_confirmedCompletion != null) return;
    if (_currentStep == 0 && !_validateIdentity()) return;
    if (_lastStep) return;
    setState(() {
      _currentStep += 1;
      _furthestStep = math.max(_furthestStep, _currentStep);
    });
  }

  void _previous() {
    if (_confirmedCompletion != null) return;
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
  }

  Future<void> _save() async {
    if (_saving || _loading || _original == null) return;
    if (_confirmedCompletion != null) {
      _confirmedCompletion!();
      return;
    }
    if (!_validateIdentity()) return;
    if (_reasonController.text.trim().isEmpty) return;
    final draft = _draft();
    final revision = _contextRevision;
    final onSaved = widget.onSaved;
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
      if (!_isCurrent(revision)) return;
      _pendingSaveRequestId = null;
      _pendingSaveFingerprint = null;
      // Confirmation survives navigation failures and is bound to this context.
      _confirmedCompletion = () {
        if (!_isCurrent(revision)) return;
        try {
          onSaved(saved);
        } on Object {
          if (!_isCurrent(revision)) return;
          showSuperadminNotice(
            context,
            'Gravação confirmada. Não foi possível concluir a navegação. Tente novamente.',
            icon: Icons.error_outline_rounded,
          );
        }
      };
      _confirmedCompletion!();
    } on AccessProfileConflictException {
      if (!mounted || !_isCurrent(revision)) return;
      _pendingSaveRequestId = null;
      _pendingSaveFingerprint = null;
      final reload = await _showOwnedDialog(
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
      if (!_isCurrent(revision)) return;
      if (reload == true) await _reloadReferencePreservingDraft();
    } on AccessProfileException catch (error) {
      if (mounted && _isCurrent(revision)) {
        showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (_isCurrent(revision)) setState(() => _saving = false);
    }
  }

  Future<void> _reloadReferencePreservingDraft() async {
    final revision = _contextRevision;
    final selectedCodes = _permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    try {
      final latest = await widget.repository.fetchDetail(widget.domain, widget.profileId!);
      if (!mounted || !_isCurrent(revision)) return;
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
      if (mounted && _isCurrent(revision)) {
        showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      }
    }
  }

  List<SuperadminFormStep> _steps() => [
    for (var index = 0; index < _stepLabels.length; index++)
      SuperadminFormStep(
        label: _stepLabels[index],
        enabled: _confirmedCompletion == null && index <= _furthestStep,
        status: index == _currentStep
            ? SuperadminFormStepStatus.current
            : index <= _furthestStep
            ? SuperadminFormStepStatus.complete
            : SuperadminFormStepStatus.incomplete,
      ),
  ];

  Widget _stepContent() {
    if (_confirmedCompletion != null) {
      return const CoeloStatePanel(
        key: Key('access-profile-confirmed-save'),
        title: 'Gravação confirmada',
        message: 'Continue para concluir.',
        icon: Icons.check_circle_outline_rounded,
      );
    }
    if (_currentStep == 0) {
      return _IdentitySection(
        nameController: _nameController,
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

  Widget _confirmedFooter() => SuperadminFormActionFooter(
    surfaceKey: const Key('access-profile-form-footer-surface'),
    onHeightChanged: (height) {
      if (mounted && _footerHeight != height) setState(() => _footerHeight = height);
    },
    tertiaryAction: TextButton(
      key: const Key('access-profile-cancel'),
      onPressed: _requestExit,
      child: const Text('Voltar'),
    ),
    continuationActions: [
      FilledButton(
        key: const Key('access-profile-complete'),
        onPressed: _saving ? null : _confirmedCompletion,
        child: const Text('Continuar'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: _editing ? 'Editar ${widget.entityLabel}' : 'Criar ${widget.entityLabel}',
    subtitle: '${widget.domain.title} · configure identidade, escopo e permissões.',
    currentDestination: widget.currentDestination,
    activityController: _activityController,
    showChatLauncher: false, // Decisao 7: sem balao de chat em criar/editar
    chatLauncherBottomInset: 0,
    onDestinationSelected: widget.onDestinationSelected == null ? null : _requestDestination,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    onOpenConversations: widget.onConversationsOpen,
    child: _loading
        ? const SingleChildScrollView(
            padding: EdgeInsets.all(CoeloSpacing.space4),
            child: CoeloStatePanel(
              title: 'Carregando perfil',
              message: 'Aguarde enquanto consultamos o catálogo.',
              loading: true,
            ),
          )
        : _error != null
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: CoeloStatePanel(
              title: 'Não foi possível abrir o perfil',
              message: _error!,
              icon: Icons.error_outline_rounded,
              actionLabel: 'Voltar',
              onAction: widget.onCancel,
            ),
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
                                _confirmedCompletion != null
                                    ? _confirmedFooter()
                                    : _FormFooter(
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
    required this.descriptionController,
    required this.status,
    required this.scope,
    required this.domain,
    required this.onStatusChanged,
    required this.onScopeChanged,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final AccessProfileStatus status;
  final AccessProfileScope scope;
  final AccessProfileDomain domain;
  final ValueChanged<AccessProfileStatus> onStatusChanged;
  final ValueChanged<AccessProfileScope> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final scopes = switch (domain) {
      AccessProfileDomain.platform => const [
        AccessProfileScope.platform,
        AccessProfileScope.institution,
      ],
      AccessProfileDomain.institution => const [
        AccessProfileScope.institution,
        AccessProfileScope.unit,
        AccessProfileScope.group,
      ],
      AccessProfileDomain.principal => const [AccessProfileScope.group],
    };
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

  void _toggleWhere(bool Function(AccessPermission permission) matches, bool selected) {
    widget.onChanged(
      widget.permissions
          .map(
            (permission) => matches(permission) && permission.grantable && !permission.inherited
                ? permission.withSelection(selected)
                : permission,
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
    final appSelectable = widget.permissions
        .where((permission) => permission.grantable && !permission.inherited)
        .toList(growable: false);
    final appSelected =
        appSelectable.isNotEmpty && appSelectable.every((permission) => permission.selected);
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
          const SizedBox(height: CoeloSpacing.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('permission-app-select-all'),
              onPressed: appSelectable.isEmpty
                  ? null
                  : () => _toggleWhere((_) => true, !appSelected),
              icon: Icon(
                appSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                size: CoeloSize.iconSm,
              ),
              label: Text(appSelected ? 'Limpar app' : 'Selecionar todo o app'),
            ),
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
                selectionPermissions: widget.permissions
                    .where((permission) => permission.module == modules.keys.elementAt(index))
                    .toList(growable: false),
                onToggle: _toggle,
                onToggleAll: (selected) => _toggleWhere(
                  (permission) => permission.module == modules.keys.elementAt(index),
                  selected,
                ),
                onToggleScreen: (screen, selected) => _toggleWhere(
                  (permission) =>
                      permission.module == modules.keys.elementAt(index) &&
                      permission.screenCode == screen,
                  selected,
                ),
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
    required this.selectionPermissions,
    required this.onToggle,
    required this.onToggleAll,
    required this.onToggleScreen,
  });

  final String module;
  final List<AccessPermission> permissions;
  final List<AccessPermission> selectionPermissions;
  final void Function(AccessPermission permission, bool selected) onToggle;
  final ValueChanged<bool> onToggleAll;
  final void Function(String screen, bool selected) onToggleScreen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = permissionMatrixRows(permissions);
    final actions = permissions.map((item) => item.actionCode).toSet().toList()
      ..sort((left, right) => _actionOrder(left).compareTo(_actionOrder(right)));
    final unavailable = permissions
        .where((item) => !item.grantable || item.inherited)
        .toList(growable: false);
    final selectable = selectionPermissions
        .where((item) => item.grantable && !item.inherited)
        .toList();
    final allSelected = selectable.isNotEmpty && selectable.every((item) => item.selected);
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  permissionModuleLabel(permissions.first),
                  style: Theme.of(context).textTheme.titleMedium,
                );
                final selectAll = TextButton.icon(
                  key: Key('permission-module-select-all-$module'),
                  onPressed: selectable.isEmpty ? null : () => onToggleAll(!allSelected),
                  icon: Icon(
                    allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                    size: CoeloSize.iconSm,
                  ),
                  label: Text(allSelected ? 'Limpar módulo' : 'Selecionar módulo'),
                );
                final count = Text(
                  '${permissions.where((item) => item.selected).length} de ${permissions.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                );
                if (constraints.maxWidth < 480) {
                  // Tela estreita: título em cima e ações quebrando linha, sem
                  // estourar a largura disponível.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: CoeloSpacing.space2,
                        children: [selectAll, count],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    selectAll,
                    const SizedBox(width: CoeloSpacing.space2),
                    count,
                  ],
                );
              },
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
                    rows: rows,
                    actions: actions,
                    onToggle: onToggle,
                    onToggleScreen: onToggleScreen,
                  );
                }
                return _StackedPermissionMatrix(
                  module: module,
                  rows: rows,
                  onToggle: onToggle,
                  onToggleScreen: onToggleScreen,
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
    required this.rows,
    required this.actions,
    required this.onToggle,
    required this.onToggleScreen,
  });

  final String module;
  final List<PermissionMatrixRow> rows;
  final List<String> actions;
  final void Function(AccessPermission permission, bool selected) onToggle;
  final void Function(String screen, bool selected) onToggleScreen;

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
                  _actionColumnLabel(rows, action),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space2),
        for (final row in rows)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
            child: Row(
              children: [
                Expanded(
                  child: _ScreenSelectionHeader(
                    module: module,
                    screen: row.screenCode,
                    label: row.label,
                    permissions: row.permissions,
                    onToggleAll: onToggleScreen,
                  ),
                ),
                for (final action in actions)
                  SizedBox(
                    width: 112,
                    child: switch (row.permissions
                        .where((item) => item.actionCode == action)
                        .firstOrNull) {
                      null => Center(
                        child: Text('—', style: TextStyle(color: colors.onSurfaceVariant)),
                      ),
                      final permission => _PermissionActionCell(
                        permission: permission,
                        showLabel: false,
                        onToggle: onToggle,
                      ),
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

final class _StackedPermissionMatrix extends StatelessWidget {
  const _StackedPermissionMatrix({
    required this.module,
    required this.rows,
    required this.onToggle,
    required this.onToggleScreen,
  });

  final String module;
  final List<PermissionMatrixRow> rows;
  final void Function(AccessPermission permission, bool selected) onToggle;
  final void Function(String screen, bool selected) onToggleScreen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          Container(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScreenSelectionHeader(
                  module: module,
                  screen: rows[index].screenCode,
                  label: rows[index].label,
                  permissions: rows[index].permissions,
                  onToggleAll: onToggleScreen,
                ),
                const SizedBox(height: CoeloSpacing.space2),
                for (final permission in rows[index].permissions)
                  _PermissionActionCell(
                    permission: permission,
                    showLabel: true,
                    onToggle: onToggle,
                  ),
              ],
            ),
          ),
          if (index < rows.length - 1) const SizedBox(height: CoeloSpacing.space3),
        ],
      ],
    );
  }
}

final class _ScreenSelectionHeader extends StatelessWidget {
  const _ScreenSelectionHeader({
    required this.module,
    required this.screen,
    required this.label,
    required this.permissions,
    required this.onToggleAll,
  });

  final String module;
  final String screen;
  final String label;
  final List<AccessPermission> permissions;
  final void Function(String screen, bool selected) onToggleAll;

  @override
  Widget build(BuildContext context) {
    final selectable = permissions.where((item) => item.grantable && !item.inherited).toList();
    final allSelected = selectable.isNotEmpty && selectable.every((item) => item.selected);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          key: Key('permission-screen-select-all-$module-$screen'),
          tooltip: allSelected ? 'Limpar tela' : 'Selecionar tela',
          onPressed: selectable.isEmpty ? null : () => onToggleAll(screen, !allSelected),
          icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
        ),
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
  final _tooltipKey = GlobalKey<TooltipState>();
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
          '${permissionActionInScreen(permission)}'
          '${reason == null ? '' : '. Indisponível. $reason'}',
      child: Tooltip(
        key: _tooltipKey,
        message: _permissionTooltip(permission),
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
          // Teclado: a explicação de sensibilidade/MFA/auditoria aparece
          // também ao focar a célula, não só ao pairar ou tocar.
          onShowFocusHighlight: (value) {
            setState(() => _focused = value);
            if (value) _tooltipKey.currentState?.ensureTooltipVisible();
          },
          child: MouseRegion(
            onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
            onExit: enabled ? (_) => setState(() => _hovered = false) : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => widget.onToggle(permission, !permission.selected) : null,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : CoeloMotion.fast,
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
                              children: [Text(permissionActionLabel(permission))],
                            ),
                          ),
                        ]
                      : [
                          Expanded(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [checkbox]),
                          ),
                        ],
                ),
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

  List<String> _describePermissions(List<String> codes) {
    final catalog = {
      for (final permission in [...original.permissions, ...draft.permissions])
        permission.code: permission,
    };
    return codes
        .map((code) {
          final permission = catalog[code];
          if (permission == null) return 'Permissão sem descrição no catálogo ($code)';
          final availability = permission.grantable ? '' : ' — ${_unavailableReason(permission)}';
          return '${permissionPath(permission)}$availability';
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => _FormSurface(
    title: 'Revisão',
    description: 'Confirme o impacto antes de enviar a alteração auditável ao servidor.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewGroup(
          title: 'Permissões adicionadas',
          values: _describePermissions(review.addedCodes),
          emptyLabel: 'Nenhuma permissão adicionada.',
          icon: Icons.add_circle_outline_rounded,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ReviewGroup(
          title: 'Permissões removidas',
          values: _describePermissions(review.removedCodes),
          emptyLabel: 'Nenhuma permissão removida.',
          icon: Icons.remove_circle_outline_rounded,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ReviewFact(
          icon: Icons.badge_outlined,
          title: 'Identidade e status',
          value:
              'Nome: de ${original.name} para ${draft.name}\n'
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
        const Text(
          'Estas são as permissões configuradas no perfil. O acesso efetivo depende '
          'do vínculo, do contexto e da autorização do servidor em cada ação.',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _ReviewFact(
          icon: Icons.people_outline_rounded,
          title: '${original.membershipCount} vínculos impactados',
          value:
              draft.permissions.any((permission) => permission.selected && permission.requiresMfa)
              ? 'Há permissões com indicação de MFA. No Superadmin, a exigência fica para o gate formal do MVP.'
              : 'Nenhuma permissão selecionada tem indicação de MFA.',
        ),
        if (review.isSensitive) ...[
          const SizedBox(height: CoeloSpacing.space4),
          const CoeloStatePanel(
            title: 'Alteração sensível',
            message: 'O servidor revalidará autoridade, escopo e concorrência antes de salvar.',
            icon: Icons.gpp_maybe_outlined,
          ),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          fieldKey: const Key('access-profile-review-reason'),
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

String _permissionTooltip(AccessPermission permission) {
  if (permission.risk == 'critical' && permission.requiresMfa) {
    return 'Ação sensível: altera ou remove dados e exige MFA e trilha de auditoria no servidor.';
  }
  if (permission.risk == 'critical') {
    return 'Ação sensível: altera ou remove dados e deixa trilha de auditoria no servidor.';
  }
  if (permission.requiresMfa) {
    return 'Esta ação exige MFA e validação de autoridade no servidor.';
  }
  if (permission.risk == 'high') {
    return 'Ação de risco elevado: fica registrada na trilha de auditoria do servidor.';
  }
  return 'Permissão ${permissionActionInScreen(permission)}.';
}

int _actionOrder(String action) => switch (action) {
  'read' || 'view' || 'list' => 0,
  'create' => 1,
  'update' || 'edit' => 2,
  'delete' => 3,
  _ => 4,
};

String _actionColumnLabel(List<PermissionMatrixRow> rows, String action) {
  for (final row in rows) {
    for (final permission in row.permissions) {
      if (permission.actionCode == action) return permissionActionLabel(permission);
    }
  }
  return humanizePermissionCode(action);
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
