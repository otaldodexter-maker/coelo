import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';

import '../activity/superadmin_activity.dart';

class SuperadminActivityCenter extends StatefulWidget {
  const SuperadminActivityCenter({required this.controller, this.buttonStyle, super.key});

  final SuperadminActivityController controller;
  final ButtonStyle? buttonStyle;

  @override
  State<SuperadminActivityCenter> createState() => _SuperadminActivityCenterState();
}

class _SuperadminActivityCenterState extends State<SuperadminActivityCenter> {
  final MenuController _menuController = MenuController();
  final FocusNode _triggerFocusNode = FocusNode(debugLabel: 'superadmin-notifications');

  @override
  void dispose() {
    _triggerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final viewport = MediaQuery.sizeOf(context);
        final availableWidth = math.max(0.0, viewport.width - CoeloSpacing.space8);
        final panelWidth = math.min(400.0, availableWidth);
        final panelHeight = widget.controller.activities.isEmpty
            ? 176.0
            : math.min(520.0, 84 + widget.controller.activities.length * 132.0);
        final unreadCount = widget.controller.unreadCount;
        return MenuAnchor(
          controller: _menuController,
          onOpen: () => widget.controller.setCenterOpen(true),
          onClose: () {
            widget.controller.setCenterOpen(false);
            if (mounted) {
              _triggerFocusNode.requestFocus();
            }
          },
          alignmentOffset: Offset(CoeloSize.touchMin - panelWidth, CoeloSpacing.space2),
          style: _activityMenuStyle(context, panelWidth),
          menuChildren: [
            SizedBox(
              key: const Key('superadmin-activity-panel'),
              width: panelWidth,
              height: panelHeight,
              child: _ActivityPanel(controller: widget.controller),
            ),
          ],
          builder: (context, controller, child) {
            final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';
            return Tooltip(
              message: 'Notificações',
              child: Semantics(
                button: true,
                label: unreadCount == 0
                    ? 'Abrir notificações'
                    : 'Abrir notificações, $badgeLabel não lidas',
                child: IconButton(
                  key: const Key('superadmin-notifications'),
                  focusNode: _triggerFocusNode,
                  onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                  style: widget.buttonStyle,
                  icon: Badge(
                    key: const Key('superadmin-notification-badge'),
                    isLabelVisible: unreadCount > 0,
                    label: Text(badgeLabel),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

MenuStyle _activityMenuStyle(BuildContext context, double width) {
  final colors = Theme.of(context).colorScheme;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(colors.surface),
    elevation: const WidgetStatePropertyAll(CoeloElevation.level2),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    minimumSize: WidgetStatePropertyAll(Size(width, 0)),
    maximumSize: WidgetStatePropertyAll(Size(width, 520)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
  );
}

class _ActivityPanel extends StatefulWidget {
  const _ActivityPanel({required this.controller});

  final SuperadminActivityController controller;

  @override
  State<_ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<_ActivityPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          MenuController.maybeOf(context)?.close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CoeloSpacing.space5,
              CoeloSpacing.space4,
              CoeloSpacing.space3,
              CoeloSpacing.space3,
            ),
            child: Row(
              children: [
                Expanded(child: Text('Notificações', style: theme.textTheme.titleMedium)),
                IconButton(
                  key: const Key('superadmin-activity-close'),
                  tooltip: 'Fechar notificações',
                  onPressed: () => MenuController.maybeOf(context)?.close(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          if (widget.controller.activities.isEmpty)
            const Expanded(child: Center(child: Text('Nenhuma notificação por enquanto.')))
          else
            Expanded(
              child: Scrollbar(
                key: const Key('superadmin-activity-scrollbar'),
                controller: _scrollController,
                thumbVisibility: widget.controller.activities.length > 3,
                child: ListView.separated(
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
                  itemCount: widget.controller.activities.length,
                  separatorBuilder: (context, index) => Padding(
                    key: Key('superadmin-activity-divider-$index'),
                    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space5),
                    child: const Divider(height: 1),
                  ),
                  itemBuilder: (context, index) =>
                      _ActivityTile(activity: widget.controller.activities[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final SuperadminActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canDownload = activity.kind != SuperadminActivityKind.announcement;
    return Material(
      key: Key('superadmin-activity-${activity.id}'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(CoeloRadius.md),
      child: InkWell(
        hoverColor: colors.primaryContainer,
        focusColor: colors.primaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        onTap: canDownload
            ? () {
                final fileName = activity.fileName;
                if (fileName == null) {
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                messenger
                  ..removeCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text('Download demonstrativo de $fileName preparado.')),
                  );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space4,
            vertical: CoeloSpacing.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: CoeloSize.touchMin,
                height: CoeloSize.touchMin,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: Icon(_activityIcon(activity.kind), color: colors.primary),
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_activityKindLabel(activity.kind)} · ${activity.subject}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(width: CoeloSpacing.space2),
                        SuperadminActivityStatusIndicator(
                          key: Key('superadmin-activity-status-${activity.id}'),
                          status: activity.status,
                        ),
                      ],
                    ),
                    if (activity.fileName case final fileName?) ...[
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      activity.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      _formatActivityTimestamp(activity.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    if (activity.progress case final progress?) ...[
                      const SizedBox(height: CoeloSpacing.space2),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: CoeloSpacing.space1,
                              borderRadius: BorderRadius.circular(CoeloRadius.xs),
                            ),
                          ),
                          const SizedBox(width: CoeloSpacing.space2),
                          Text('$progress%', style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SuperadminActivityStatusIndicator extends StatefulWidget {
  const SuperadminActivityStatusIndicator({required this.status, super.key});

  final SuperadminActivityStatus status;

  @override
  State<SuperadminActivityStatusIndicator> createState() =>
      _SuperadminActivityStatusIndicatorState();
}

class _SuperadminActivityStatusIndicatorState extends State<SuperadminActivityStatusIndicator> {
  var _hovered = false;
  var _focused = false;
  var _tapped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expanded = _hovered || _focused || _tapped;
    final (background, foreground) = _activityStatusColors(context, widget.status);
    final label = _activityStatusLabel(widget.status);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: CoeloSize.touchMin,
        minHeight: CoeloSize.touchMin,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          child: Semantics(
            label: 'Status: $label',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tapped = !_tapped),
              child: Center(
                child: AnimatedContainer(
                  duration: CoeloMotion.short,
                  curve: Curves.easeOut,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: EdgeInsets.symmetric(
                    horizontal: expanded ? CoeloSpacing.space2 : CoeloSpacing.space1,
                    vertical: CoeloSpacing.space1,
                  ),
                  decoration: BoxDecoration(
                    color: expanded ? background : foreground,
                    borderRadius: BorderRadius.circular(CoeloRadius.full),
                  ),
                  child: expanded
                      ? Text(label, style: theme.textTheme.labelSmall?.copyWith(color: foreground))
                      : const SizedBox.square(dimension: CoeloSpacing.space2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatActivityTimestamp(DateTime value) {
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}'
      ' · ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

String _activityKindLabel(SuperadminActivityKind kind) => switch (kind) {
  SuperadminActivityKind.import => 'Importação',
  SuperadminActivityKind.export => 'Exportação',
  SuperadminActivityKind.announcement => 'Novidade',
};

IconData _activityIcon(SuperadminActivityKind kind) => switch (kind) {
  SuperadminActivityKind.import => Icons.upload_file_outlined,
  SuperadminActivityKind.export => Icons.download_outlined,
  SuperadminActivityKind.announcement => Icons.campaign_outlined,
};

String _activityStatusLabel(SuperadminActivityStatus status) => switch (status) {
  SuperadminActivityStatus.inProgress => 'Em andamento',
  SuperadminActivityStatus.succeeded => 'Concluída',
  SuperadminActivityStatus.partial => 'Parcial',
  SuperadminActivityStatus.failed => 'Falhou',
};

(Color, Color) _activityStatusColors(BuildContext context, SuperadminActivityStatus status) {
  final theme = Theme.of(context);
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  return switch (status) {
    SuperadminActivityStatus.inProgress => (
      statusColors.infoContainer,
      statusColors.onInfoContainer,
    ),
    SuperadminActivityStatus.succeeded => (
      statusColors.successContainer,
      statusColors.onSuccessContainer,
    ),
    SuperadminActivityStatus.partial => (
      statusColors.warningContainer,
      statusColors.onWarningContainer,
    ),
    SuperadminActivityStatus.failed => (statusColors.errorContainer, statusColors.onErrorContainer),
  };
}

final _activityStatesPreviewController = SuperadminActivityController.seeded([
  SuperadminActivity(
    id: 'preview-import',
    kind: SuperadminActivityKind.import,
    status: SuperadminActivityStatus.inProgress,
    subject: 'Instituições',
    summary: 'Importando instituições',
    createdAt: DateTime(2026, 7, 21, 10, 30),
    fileName: 'instituicoes-julho.xlsx',
    progress: 55,
    isRead: true,
  ),
  SuperadminActivity(
    id: 'preview-success',
    kind: SuperadminActivityKind.export,
    status: SuperadminActivityStatus.succeeded,
    subject: 'Instituições',
    summary: 'Arquivo preparado',
    createdAt: DateTime(2026, 7, 21, 10),
    fileName: 'instituicoes.csv',
    progress: 100,
  ),
  SuperadminActivity(
    id: 'preview-partial',
    kind: SuperadminActivityKind.import,
    status: SuperadminActivityStatus.partial,
    subject: 'Unidades',
    summary: '24 importadas, 2 rejeitadas',
    createdAt: DateTime(2026, 7, 21, 9, 30),
    fileName: 'unidades.xlsx',
    progress: 100,
  ),
  SuperadminActivity(
    id: 'preview-error',
    kind: SuperadminActivityKind.import,
    status: SuperadminActivityStatus.failed,
    subject: 'Grupos',
    summary: 'O arquivo não usa o modelo esperado',
    createdAt: DateTime(2026, 7, 21, 9),
    fileName: 'grupos.xlsx',
    progress: 100,
  ),
  SuperadminActivity.announcement(
    id: 'preview-announcement',
    subject: 'Novidade no Superadmin',
    summary: 'Agora você pode acompanhar atividades pelo sininho.',
    createdAt: DateTime(2026, 7, 21, 8, 30),
  ),
]);

final _emptyActivityPreviewController = SuperadminActivityController();

@Preview(name: 'Notificações · estados · light', size: Size(400, 520))
Widget superadminActivityStatesLightPreview() {
  return _activityPanelPreview(_activityStatesPreviewController, CoeloTheme.light);
}

@Preview(name: 'Notificações · estados · dark', size: Size(400, 520))
Widget superadminActivityStatesDarkPreview() {
  return _activityPanelPreview(_activityStatesPreviewController, CoeloTheme.dark);
}

@Preview(name: 'Notificações · vazio', size: Size(400, 176))
Widget superadminActivityEmptyPreview() {
  return _activityPanelPreview(_emptyActivityPreviewController, CoeloTheme.light);
}

Widget _activityPanelPreview(SuperadminActivityController controller, ThemeData theme) {
  return Theme(
    data: theme,
    child: Material(
      color: theme.colorScheme.surface,
      child: _ActivityPanel(controller: controller),
    ),
  );
}
