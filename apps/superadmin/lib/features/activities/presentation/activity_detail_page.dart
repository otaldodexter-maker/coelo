import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_directory.dart';

enum _ActivityDetailState { loading, success, notFound, failure, unauthorized }

final class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    required this.activityId,
    required this.repository,
    required this.logout,
    required this.onBack,
    this.onEdit,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    super.key,
  });

  final String activityId;
  final ActivityDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

final class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late final SuperadminActivityController _activityController;
  _ActivityDetailState _state = _ActivityDetailState.loading;
  ActivityDetail? _detail;

  @override
  void initState() {
    super.initState();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _ActivityDetailState.loading);
    try {
      final detail = await widget.repository.fetchById(widget.activityId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _state = detail == null ? _ActivityDetailState.notFound : _ActivityDetailState.success;
      });
    } on ActivityDirectoryUnauthorizedException {
      if (mounted) setState(() => _state = _ActivityDetailState.unauthorized);
    } on Exception {
      if (mounted) setState(() => _state = _ActivityDetailState.failure);
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    activityController: _activityController,
    title: 'Visualizar atividade',
    subtitle: 'Consulte os dados e vínculos desta atividade.',
    currentDestination: 'activities',
    showChatLauncher: false,
    onDestinationSelected: widget.onDestinationSelected,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return ListView(
          key: const Key('activity-detail-scroll'),
          padding: EdgeInsets.all(padding),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            _body(),
          ],
        );
      },
    ),
  );

  Widget _body() => switch (_state) {
    _ActivityDetailState.loading => const Center(
      child: Padding(
        padding: EdgeInsets.all(CoeloSpacing.space10),
        child: CircularProgressIndicator(),
      ),
    ),
    _ActivityDetailState.notFound => CoeloStatePanel(
      title: 'Atividade não encontrada',
      message: 'O registro pode não existir ou não estar visível para sua conta.',
      icon: Icons.search_off_rounded,
      actionLabel: 'Voltar',
      onAction: widget.onBack,
    ),
    _ActivityDetailState.unauthorized => const CoeloStatePanel(
      title: 'Acesso não autorizado',
      message: 'Você não tem permissão para visualizar esta atividade.',
      icon: Icons.lock_outline_rounded,
    ),
    _ActivityDetailState.failure => CoeloStatePanel(
      title: 'Não foi possível carregar a atividade',
      message: 'Tente novamente.',
      icon: Icons.cloud_off_outlined,
      actionLabel: 'Tentar novamente',
      onAction: _load,
    ),
    _ActivityDetailState.success => _ActivityDetailContent(detail: _detail!, onEdit: widget.onEdit),
  };
}

final class _ActivityDetailContent extends StatelessWidget {
  const _ActivityDetailContent({required this.detail, required this.onEdit});

  final ActivityDetail detail;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (onEdit != null) ...[
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar atividade'),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      _DetailSection(
        title: 'Identidade',
        icon: Icons.badge_outlined,
        child: _ResponsiveFields(
          fields: [
            _Field('Nome', detail.item.name),
            _Field('Instituição', detail.item.institutionName),
            _Field('Status', detail.item.status.label),
            _Field('Descrição', detail.item.description ?? 'Não informada'),
          ],
        ),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _DetailSection(
        title: 'Governança',
        icon: Icons.policy_outlined,
        child: _ResponsiveFields(
          fields: [
            _Field('Origem', detail.item.origin.label),
            if (detail.originUnitName != null) _Field('Unidade de origem', detail.originUnitName!),
            _Field('Distribuição', detail.item.distribution.label),
            _Field('Política', detail.item.governance.label),
            _Field('Criação', _formatDateTime(detail.createdAt)),
            _Field('Atualização', _formatDateTime(detail.item.updatedAt)),
            if (detail.archivedAt != null)
              _Field('Arquivamento', _formatDateTime(detail.archivedAt!)),
          ],
        ),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _DetailSection(
        title: 'Unidades vinculadas',
        icon: Icons.apartment_outlined,
        child: detail.units.isEmpty
            ? const Text('Nenhuma unidade vinculada.')
            : Column(
                children: [
                  for (final unit in detail.units)
                    _LinkedRecord(
                      title: unit.name,
                      values: [
                        ('Status', unit.status.label),
                        ('Início', _formatDateTime(unit.startsAt)),
                        (
                          'Fim',
                          unit.endsAt == null ? 'Sem término' : _formatDateTime(unit.endsAt!),
                        ),
                      ],
                    ),
                ],
              ),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _DetailSection(
        title: 'Grupos vinculados',
        icon: Icons.groups_outlined,
        child: detail.groups.isEmpty
            ? const Text('Nenhum grupo vinculado.')
            : Column(
                children: [
                  for (final group in detail.groups)
                    _LinkedRecord(
                      title: group.name,
                      values: [
                        ('Unidade', group.unitName),
                        ('Participação', group.participation.label),
                        ('Status', group.status.label),
                        ('Profissionais atribuídos', '${group.assigneeCount}'),
                        ('Participantes', '${group.participantCount}'),
                      ],
                    ),
                ],
              ),
      ),
    ],
  );
}

final class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: CoeloSpacing.space2),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space5),
            child,
          ],
        ),
      ),
    );
  }
}

final class _Field {
  const _Field(this.label, this.value);

  final String label;
  final String value;
}

final class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.fields});

  final List<_Field> fields;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) / columns;
      return Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space4,
        children: [
          for (final field in fields)
            SizedBox(
              width: width,
              child: _ReadOnlyField(field: field),
            ),
        ],
      );
    },
  );
}

final class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.field});

  final _Field field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${field.label}: ${field.value}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          SelectableText(field.value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

final class _LinkedRecord extends StatelessWidget {
  const _LinkedRecord({required this.title, required this.values});

  final String title;
  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          _ResponsiveFields(fields: [for (final value in values) _Field(value.$1, value.$2)]),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
