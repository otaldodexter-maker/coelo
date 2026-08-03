import 'dart:math';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/presentation/widgets/institution_form_dialogs.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/access_profile.dart';

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
  bool _loading = true;
  bool _saving = false;
  double _footerHeight = 0;
  String? _error;
  String? _pendingSaveRequestId;
  String? _pendingSaveFingerprint;

  bool get _editing => widget.profileId != null;

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
    _nameController.addListener(_onDraftChanged);
    _codeController.addListener(_onDraftChanged);
    _descriptionController.addListener(_onDraftChanged);
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
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      setState(() {
        _error = 'Não foi possível carregar o formulário.';
        _loading = false;
      });
    }
  }

  Future<void> _requestExit() async {
    if (!_isDirty || await showInstitutionExitDialog(context, entityLabel: 'perfil')) {
      widget.onCancel();
    }
  }

  Future<void> _requestDestination(String destination) async {
    if (!_isDirty || await showInstitutionExitDialog(context, entityLabel: 'perfil')) {
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

  AccessProfile _draft() {
    final original = _original!;
    return original.copyWith(
      name: _nameController.text.trim(),
      code: _codeController.text.trim().toLowerCase(),
      description: _descriptionController.text.trim(),
      status: _status,
      maxScope: _scope,
      permissions: _permissions,
    );
  }

  Future<void> _review() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _draft();
    final review = AccessProfileReview.compare(_original!, draft);
    _reasonController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('access-profile-review-dialog'),
        title: 'Revisar alterações',
        maxWidth: 620,
        body: _ReviewBody(
          original: _original!,
          draft: draft,
          review: review,
          reasonController: _reasonController,
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Voltar'),
        ),
        primaryAction: ListenableBuilder(
          listenable: _reasonController,
          builder: (context, child) => FilledButton(
            key: const Key('confirm-access-profile-save'),
            onPressed: _reasonController.text.trim().isEmpty
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: Text(review.isSensitive ? 'Confirmar alteração sensível' : 'Salvar perfil'),
          ),
        ),
      ),
    );
    if (confirmed == true) await _save(draft);
  }

  Future<void> _save(AccessProfile draft) async {
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

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: _editing ? 'Editar perfil' : 'Criar perfil',
    subtitle: '${widget.domain.title} · revise identidade, escopo e permissões.',
    currentDestination: 'profiles',
    activityController: _activityController,
    showChatLauncher: widget.onConversationsOpen != null,
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
                final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                    ? CoeloSpacing.space10
                    : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                    ? CoeloSpacing.space6
                    : CoeloSpacing.space4;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      ignoring: _saving,
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          key: const Key('access-profile-form-scroll'),
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            padding,
                            padding,
                            padding + _footerHeight + CoeloSpacing.space4,
                          ),
                          children: [
                            _IdentitySection(
                              nameController: _nameController,
                              codeController: _codeController,
                              descriptionController: _descriptionController,
                              status: _status,
                              scope: _scope,
                              domain: widget.domain,
                              onStatusChanged: (value) => setState(() => _status = value),
                              onScopeChanged: (value) => setState(() => _scope = value),
                            ),
                            const SizedBox(height: CoeloSpacing.space6),
                            _AccessProfilePrototypeContext(domain: widget.domain),
                            const SizedBox(height: CoeloSpacing.space6),
                            _PermissionEditor(
                              permissions: _permissions,
                              searchController: _permissionSearchController,
                              onChanged: (permissions) =>
                                  setState(() => _permissions = permissions),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: padding,
                      right: padding,
                      bottom: padding,
                      child: SuperadminFormActionFooter(
                        surfaceKey: const Key('access-profile-form-footer-surface'),
                        onHeightChanged: (height) {
                          if ((_footerHeight - height).abs() < .5) return;
                          setState(() => _footerHeight = height);
                        },
                        tertiaryAction: TextButton(
                          onPressed: _saving ? null : _requestExit,
                          child: const Text('Cancelar'),
                        ),
                        continuationActions: [
                          FilledButton.icon(
                            key: const Key('review-access-profile'),
                            onPressed: _saving ? null : _review,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: CoeloSize.iconSm,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.fact_check_outlined),
                            label: const Text('Revisar alterações'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
  );
}

final class _AccessProfilePrototypeContext extends StatelessWidget {
  const _AccessProfilePrototypeContext({required this.domain});

  final AccessProfileDomain domain;

  @override
  Widget build(BuildContext context) {
    final profiles = domain == AccessProfileDomain.platform
        ? const [
            (
              name: 'Owner Coelo',
              description: 'Permite controle total da plataforma dentro das salvaguardas internas.',
            ),
            (
              name: 'Operações',
              description: 'Permite operar cadastros e suporte sem alterar o teto de segurança.',
            ),
            (
              name: 'Auditoria',
              description: 'Permite consultar trilhas e evidências em modo somente leitura.',
            ),
          ]
        : const [
            (
              name: 'Administrador institucional',
              description: 'Permite administrar a instituição nos contextos atribuídos.',
            ),
            (
              name: 'Coordenação',
              description: 'Permite acompanhar unidades, grupos e atividades atribuídos.',
            ),
            (
              name: 'Atendimento',
              description: 'Permite apoiar pessoas e rotinas sem ampliar permissões.',
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormSurface(
          title: 'Catálogo predefinido',
          description:
              'Referências locais do app ${domain.title}; cada app mantém seu próprio catálogo.',
          child: Column(
            children: [
              for (final profile in profiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(profile.name),
                  subtitle: Text(profile.description),
                ),
            ],
          ),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _FormSurface(
          title: 'Atribuições contextuais demonstrativas',
          description: 'Perfil define teto; atribuição define contexto efetivo.',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PrototypeAssignment(
                icon: Icons.account_balance_outlined,
                label: 'Instituição · Colégio Horizonte',
              ),
              _PrototypeAssignment(
                icon: Icons.apartment_outlined,
                label: 'Unidade · Unidade Centro',
              ),
              _PrototypeAssignment(icon: Icons.groups_outlined, label: 'Grupo (Turma) · Girassol'),
              _PrototypeAssignment(
                icon: Icons.local_activity_outlined,
                label: 'Atividade · Robótica',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _PrototypeAssignment extends StatelessWidget {
  const _PrototypeAssignment({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
    child: Row(
      children: [
        Icon(icon, size: CoeloSize.iconSm),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(label)),
      ],
    ),
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
      title: 'Identidade e escopo',
      description: 'O escopo máximo limita onde futuras atribuições podem operar.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          final fields = [
            CoeloFormTextField(
              controller: nameController,
              labelText: 'Nome do perfil',
              prefixIcon: Icons.badge_outlined,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Informe o nome do perfil.' : null,
            ),
            CoeloFormTextField(
              controller: codeController,
              labelText: 'Código',
              prefixIcon: Icons.code_rounded,
              hintText: 'exemplo.perfil',
              validator: (value) {
                final code = value?.trim() ?? '';
                if (code.isEmpty) return 'Informe o código.';
                if (!RegExp(r'^[a-z][a-z0-9._]*$').hasMatch(code)) {
                  return 'Use o formato exemplo.perfil.';
                }
                return null;
              },
            ),
          ];
          return Column(
            children: [
              if (stacked)
                ...fields.expand((field) => [field, const SizedBox(height: CoeloSpacing.space4)])
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields.first),
                    const SizedBox(width: CoeloSpacing.space4),
                    Expanded(child: fields.last),
                  ],
                ),
              if (!stacked) const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                controller: descriptionController,
                labelText: 'Descrição',
                prefixIcon: Icons.description_outlined,
                maxLines: 1,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Explique o propósito do perfil.'
                    : null,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              if (stacked) ...[
                CoeloAdminSingleSelectField(
                  label: 'Status',
                  value: status,
                  options: AccessProfileStatus.values,
                  optionLabel: (value) => value.label,
                  onChanged: onStatusChanged,
                ),
                const SizedBox(height: CoeloSpacing.space4),
                CoeloAdminSingleSelectField(
                  label: 'Escopo máximo',
                  value: scope,
                  options: scopes,
                  optionLabel: (value) => value.label,
                  onChanged: onScopeChanged,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: CoeloAdminSingleSelectField(
                        label: 'Status',
                        value: status,
                        options: AccessProfileStatus.values,
                        optionLabel: (value) => value.label,
                        onChanged: onStatusChanged,
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space4),
                    Expanded(
                      child: CoeloAdminSingleSelectField(
                        label: 'Escopo máximo',
                        value: scope,
                        options: scopes,
                        optionLabel: (value) => value.label,
                        onChanged: onScopeChanged,
                      ),
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

final class _PermissionEditor extends StatefulWidget {
  const _PermissionEditor({
    required this.permissions,
    required this.searchController,
    required this.onChanged,
  });

  final List<AccessPermission> permissions;
  final TextEditingController searchController;
  final ValueChanged<List<AccessPermission>> onChanged;

  @override
  State<_PermissionEditor> createState() => _PermissionEditorState();
}

final class _PermissionEditorState extends State<_PermissionEditor> {
  String _search = '';

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
    final filtered = widget.permissions.where((permission) {
      final query = _search.trim().toLowerCase();
      return query.isEmpty ||
          permission.name.toLowerCase().contains(query) ||
          permission.code.toLowerCase().contains(query) ||
          permission.module.toLowerCase().contains(query);
    }).toList();
    final modules = <String, List<AccessPermission>>{};
    for (final permission in filtered) {
      modules.putIfAbsent(permission.module, () => []).add(permission);
    }
    return _FormSurface(
      title: 'Permissões',
      description: 'Permissões indisponíveis ficam desabilitadas e informam o motivo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloSearchField(
            controller: widget.searchController,
            hintText: 'Buscar permissão',
            semanticLabel: 'Buscar permissão por nome, código ou domínio',
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
            for (final entry in modules.entries)
              Card(
                margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(entry.key),
                  subtitle: Text(
                    '${entry.value.where((item) => item.selected).length} de ${entry.value.length} selecionadas',
                  ),
                  children: [
                    for (final permission in entry.value)
                      Semantics(
                        container: true,
                        label: permission.grantable
                            ? null
                            : '${permission.name}. Indisponível. ${permission.unavailableReason}',
                        child: CheckboxListTile(
                          key: Key('permission-${permission.code}'),
                          value: permission.selected,
                          enabled: permission.grantable && !permission.inherited,
                          onChanged: (value) => _toggle(permission, value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(permission.name),
                          subtitle: Text(
                            [
                              permission.code,
                              if (permission.description != null) permission.description!,
                              if (permission.inherited) 'Herdada — não pode ser alterada aqui.',
                              if (!permission.grantable)
                                permission.unavailableReason ?? 'Indisponível para concessão.',
                              if (permission.requiresMfa) 'Exige MFA.',
                            ].join('\n'),
                          ),
                          secondary: permission.risk == 'critical'
                              ? const Tooltip(
                                  message: 'Risco crítico',
                                  child: Icon(Icons.warning_amber_rounded),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

final class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.title, required this.description, required this.child});

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space6),
          child,
        ],
      ),
    ),
  );
}

final class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
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
  Widget build(BuildContext context) => Column(
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
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Identidade e status'),
        subtitle: Text(
          'Nome: ${original.name} para ${draft.name}\n'
          'Código: ${original.code} para ${draft.code}\n'
          'Status: ${original.status.label} para ${draft.status.label}',
        ),
      ),
      const SizedBox(height: CoeloSpacing.space2),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.layers_outlined),
        title: const Text('Escopo máximo'),
        subtitle: Text(
          review.scopeChanged
              ? '${original.maxScope.label} para ${draft.maxScope.label}'
              : 'Sem alteração (${draft.maxScope.label}).',
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.people_outline_rounded),
        title: Text('${original.membershipCount} vínculos impactados'),
        subtitle: Text(
          draft.permissions.any((permission) => permission.selected && permission.requiresMfa)
              ? 'O perfil inclui permissões que exigem MFA.'
              : 'Nenhuma permissão selecionada exige MFA adicional.',
        ),
      ),
      if (review.isSensitive) ...[
        const SizedBox(height: CoeloSpacing.space3),
        const CoeloStatePanel(
          title: 'Alteração sensível',
          message: 'O servidor revalidará MFA, autoridade, escopo e concorrência antes de salvar.',
          icon: Icons.gpp_maybe_outlined,
        ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: reasonController,
        labelText: 'Motivo da alteração',
        prefixIcon: Icons.notes_rounded,
        hintText: 'Obrigatório para a trilha de auditoria.',
        maxLines: 1,
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

String _newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String part(int start, int end) =>
      bytes.sublist(start, end).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${part(0, 4)}-${part(4, 6)}-${part(6, 8)}-'
      '${part(8, 10)}-${part(10, 16)}';
}
