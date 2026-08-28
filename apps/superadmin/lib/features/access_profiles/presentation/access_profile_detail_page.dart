import 'dart:math';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/access_profile.dart';

final class AccessProfileDetailPage extends StatefulWidget {
  const AccessProfileDetailPage({
    required this.repository,
    required this.logout,
    required this.domain,
    required this.profileId,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.currentDestination = 'profiles',
    super.key,
  });

  final AccessProfileRepository repository;
  final LogoutAction logout;
  final AccessProfileDomain domain;
  final String profileId;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String currentDestination;

  @override
  State<AccessProfileDetailPage> createState() => _AccessProfileDetailPageState();
}

final class _AccessProfileDetailPageState extends State<AccessProfileDetailPage> {
  late final SuperadminActivityController _activityController;
  AccessProfile? _profile;
  String? _error;
  bool _deleting = false;
  String? _pendingDeleteRequestId;

  @override
  void initState() {
    super.initState();
    _activityController = SuperadminActivityController();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.repository.fetchDetail(widget.domain, widget.profileId);
      if (mounted) setState(() => _profile = profile);
    } on AccessProfileException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar o perfil.');
      }
    }
  }

  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final profile = _profile!;
    AccessProfilePage page;
    try {
      page = await widget.repository.fetchProfiles(
        AccessProfileQuery(
          domain: profile.domain,
          pageSize: 100,
          layout: AccessProfileLayout.table,
        ),
      );
    } on AccessProfileException catch (error) {
      if (mounted) {
        showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      }
      return;
    }
    if (!mounted) return;
    final options = [
      const _ReplacementOption(null, 'Sem substituto'),
      ...page.items
          .where((item) => item.id != profile.id && item.status == AccessProfileStatus.active)
          .map((item) => _ReplacementOption(item.id, item.name)),
    ];
    var replacement = options.first;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: 'Excluir perfil',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                profile.membershipCount > 0
                    ? 'Os ${profile.membershipCount} vínculos serão realocados na mesma transação.'
                    : 'Esta ação remove o perfil permanentemente.',
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloAdminSingleSelectField(
                label: 'Perfil substituto',
                value: replacement,
                options: options,
                optionLabel: (value) => value.label,
                onChanged: (value) => setDialogState(() => replacement = value),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                controller: reasonController,
                labelText: 'Motivo da exclusão',
                prefixIcon: Icons.notes_rounded,
                maxLines: 1,
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed:
                reasonController.text.trim().isEmpty ||
                    (profile.membershipCount > 0 && replacement.id == null)
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir e realocar'),
          ),
        ),
      ),
    );
    if (confirmed != true) {
      reasonController.dispose();
      return;
    }
    _pendingDeleteRequestId ??= _newRequestId();
    if (mounted) setState(() => _deleting = true);
    try {
      await widget.repository.deleteAndReassign(
        requestId: _pendingDeleteRequestId!,
        domain: profile.domain,
        profileId: profile.id,
        expectedVersion: profile.version,
        replacementProfileId: replacement.id,
        reason: reasonController.text.trim(),
      );
      _pendingDeleteRequestId = null;
      if (mounted) widget.onDeleted();
    } on AccessProfileException catch (error) {
      if (mounted) {
        showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: _profile?.name ?? 'Detalhes do perfil',
    subtitle: widget.domain.title,
    currentDestination: widget.currentDestination,
    activityController: _activityController,
    showChatLauncher: widget.onConversationsOpen != null,
    onDestinationSelected: widget.onDestinationSelected,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    onOpenConversations: widget.onConversationsOpen,
    child: _profile == null
        ? _error == null
              ? const CoeloStatePanel(
                  title: 'Carregando perfil',
                  message: 'Aguarde enquanto consultamos os detalhes.',
                  loading: true,
                )
              : CoeloStatePanel(
                  title: 'Não foi possível carregar o perfil',
                  message: _error!,
                  icon: Icons.error_outline_rounded,
                  actionLabel: 'Voltar',
                  onAction: widget.onBack,
                )
        : LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                  ? CoeloSpacing.space10
                  : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                  ? CoeloSpacing.space6
                  : CoeloSpacing.space4;
              return ListView(
                key: const Key('access-profile-detail-scroll'),
                padding: EdgeInsets.all(padding),
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: CoeloSpacing.space3,
                    runSpacing: CoeloSpacing.space2,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Voltar'),
                      ),
                      Wrap(
                        spacing: CoeloSpacing.space2,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Excluir'),
                          ),
                          FilledButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar perfil'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _ProfileSummary(profile: _profile!),
                  const SizedBox(height: CoeloSpacing.space4),
                  _PermissionSummary(profile: _profile!),
                  const SizedBox(height: CoeloSpacing.space4),
                  _ImpactSummary(profile: _profile!),
                ],
              );
            },
          ),
  );
}

final class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});
  final AccessProfile profile;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Resumo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space4),
          Wrap(
            spacing: CoeloSpacing.space8,
            runSpacing: CoeloSpacing.space4,
            children: [
              _Detail(label: 'Código', value: profile.code),
              _Detail(label: 'Status', value: profile.status.label),
              _Detail(label: 'Escopo máximo', value: profile.maxScope.label),
              _Detail(label: 'Versão', value: '${profile.version}'),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Text(profile.description),
        ],
      ),
    ),
  );
}

final class _PermissionSummary extends StatelessWidget {
  const _PermissionSummary({required this.profile});
  final AccessProfile profile;

  @override
  Widget build(BuildContext context) {
    final selected = profile.permissions.where((permission) => permission.selected).toList();
    final modules = <String, List<AccessPermission>>{};
    for (final permission in selected) {
      modules.putIfAbsent(permission.module, () => []).add(permission);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Permissões configuradas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CoeloSpacing.space4),
            if (modules.isEmpty)
              const Text('Nenhuma permissão configurada.')
            else
              for (final entry in modules.entries)
                ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(entry.key),
                  subtitle: Text('${entry.value.length} permissões'),
                  children: [
                    for (final permission in entry.value)
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(permission.name),
                        subtitle: Text(permission.code),
                        trailing: permission.requiresMfa
                            ? const Tooltip(
                                message: 'Exige MFA',
                                child: Icon(Icons.phonelink_lock_outlined),
                              )
                            : null,
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

final class _ImpactSummary extends StatelessWidget {
  const _ImpactSummary({required this.profile});
  final AccessProfile profile;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vínculos, impacto e auditoria', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link_outlined),
            title: Text('${profile.membershipCount} vínculos associados'),
            subtitle: Text(
              profile.membershipCount == 0
                  ? 'Este perfil ainda não possui atribuições.'
                  : 'A exclusão exige realocação transacional.',
            ),
          ),
          if (profile.links.isNotEmpty) ...[
            const Divider(),
            for (final link in profile.links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(link.personName),
                subtitle: Text('Escopo efetivo: ${link.scope}'),
              ),
          ],
          if (!profile.auditAvailable)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded),
              title: Text('Auditoria protegida'),
              subtitle: Text('Eventos sensíveis só aparecem para quem possui audit.read.'),
            )
          else if (profile.auditEvents.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded),
              title: Text('Nenhum evento de auditoria'),
              subtitle: Text('Ainda não há alterações registradas para este perfil.'),
            )
          else
            for (final event in profile.auditEvents)
              Builder(
                builder: (context) {
                  final local = event.occurredAt.toLocal();
                  final localizations = MaterialLocalizations.of(context);
                  final occurredAt =
                      '${localizations.formatShortDate(local)} às '
                      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(_auditActionLabel(event.action)),
                    subtitle: Text(
                      event.reason == null ? occurredAt : '${event.reason}\n$occurredAt',
                    ),
                  );
                },
              ),
        ],
      ),
    ),
  );
}

String _auditActionLabel(String action) => switch (action) {
  'platform_permission_changed' => 'Permissões Superadmin alteradas',
  'permission_changed' => 'Permissões Admin alteradas',
  'membership_changed' => 'Vínculos realocados',
  _ => 'Alteração registrada',
};

final class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

final class _ReplacementOption {
  const _ReplacementOption(this.id, this.label);
  final String? id;
  final String label;
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
