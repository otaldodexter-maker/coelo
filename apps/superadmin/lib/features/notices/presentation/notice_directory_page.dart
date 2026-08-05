import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/fake_notice_repository.dart';
import '../domain/platform_notice.dart';
import 'notice_form_page.dart';

enum _NoticeStatusFilter { all, draft, scheduled, active, paused, ended, canceled }

extension _NoticeStatusFilterLabel on _NoticeStatusFilter {
  String get label => switch (this) {
    _NoticeStatusFilter.all => 'Todos',
    _NoticeStatusFilter.draft => 'Rascunho',
    _NoticeStatusFilter.scheduled => 'Agendado',
    _NoticeStatusFilter.active => 'Ativo',
    _NoticeStatusFilter.paused => 'Pausado',
    _NoticeStatusFilter.ended => 'Expirado',
    _NoticeStatusFilter.canceled => 'Inativo',
  };

  NoticeStatus? get status => switch (this) {
    _NoticeStatusFilter.all => null,
    _NoticeStatusFilter.draft => NoticeStatus.draft,
    _NoticeStatusFilter.scheduled => NoticeStatus.scheduled,
    _NoticeStatusFilter.active => NoticeStatus.active,
    _NoticeStatusFilter.paused => NoticeStatus.paused,
    _NoticeStatusFilter.ended => NoticeStatus.ended,
    _NoticeStatusFilter.canceled => NoticeStatus.cancelled,
  };
}

enum _NoticeTargetFilter { all, web, mobile, tablet }

extension _NoticeTargetFilterValue on _NoticeTargetFilter {
  NoticeTargetDevice? get device => switch (this) {
    _NoticeTargetFilter.all => null,
    _NoticeTargetFilter.web => NoticeTargetDevice.web,
    _NoticeTargetFilter.mobile => NoticeTargetDevice.mobile,
    _NoticeTargetFilter.tablet => NoticeTargetDevice.tablet,
  };

  String get label => switch (this) {
    _NoticeTargetFilter.all => 'Todos os dispositivos',
    _NoticeTargetFilter.web => 'Web',
    _NoticeTargetFilter.mobile => 'Mobile',
    _NoticeTargetFilter.tablet => 'Tablet',
  };
}

enum _NoticePeriodFilter { all, now, upcoming, ended }

extension _NoticePeriodFilterLabel on _NoticePeriodFilter {
  String get label => switch (this) {
    _NoticePeriodFilter.all => 'Período',
    _NoticePeriodFilter.now => 'Ativos agora',
    _NoticePeriodFilter.upcoming => 'Próximos',
    _NoticePeriodFilter.ended => 'Expirados',
  };
}

enum _NoticeCardAction { edit, duplicate, publish, pause, resume, cancel }

final class NoticeDirectoryPage extends StatefulWidget {
  const NoticeDirectoryPage({required this.repository, this.onCreate, this.onEdit, super.key});
  final FakeNoticeRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  @override
  State<NoticeDirectoryPage> createState() => _NoticeDirectoryPageState();
}

final class _NoticeDirectoryPageState extends State<NoticeDirectoryPage> {
  final _search = TextEditingController();
  _NoticeStatusFilter _statusFilter = _NoticeStatusFilter.all;
  _NoticeTargetFilter _targetFilter = _NoticeTargetFilter.all;
  _NoticePeriodFilter _periodFilter = _NoticePeriodFilter.all;
  String? _selectedNoticeId;
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.large.minWidth;
      final contentPadding = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
      final notices = _filteredNotices();
      final all = widget.repository.list();
      final theme = Theme.of(context);
      final pageBackground = theme.brightness == Brightness.light
          ? Colors.white
          : theme.colorScheme.surface;
      return Container(
        color: pageBackground,
        child: Padding(
          padding: EdgeInsets.all(contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Avisos', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                'Compose e ajuste avisos com lista e editor no mesmo contexto.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _toolbar(context, all),
              const SizedBox(height: CoeloSpacing.space4),
              if (compact)
                Expanded(child: _list(context, notices: notices, useDesktopLayout: false))
              else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 44,
                        child: _list(context, notices: notices, useDesktopLayout: true),
                      ),
                      const SizedBox(width: CoeloSpacing.space4),
                      Expanded(flex: 56, child: _editor(context)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _toolbar(BuildContext context, List<PlatformNotice> all) {
    final statusMap = <_NoticeStatusFilter, int>{
      _NoticeStatusFilter.all: all.length,
      _NoticeStatusFilter.draft: all.where((item) => item.status == NoticeStatus.draft).length,
      _NoticeStatusFilter.scheduled: all
          .where((item) => item.status == NoticeStatus.scheduled)
          .length,
      _NoticeStatusFilter.active: all.where((item) => item.status == NoticeStatus.active).length,
      _NoticeStatusFilter.paused: all.where((item) => item.status == NoticeStatus.paused).length,
      _NoticeStatusFilter.ended: all.where((item) => item.status == NoticeStatus.ended).length,
      _NoticeStatusFilter.canceled: all
          .where((item) => item.status == NoticeStatus.cancelled)
          .length,
    };

    final searchWidth = MediaQuery.of(context).size.width < CoeloBreakpoints.medium.minWidth
        ? null
        : 320.0;
    final filters = Wrap(
      runSpacing: CoeloSpacing.space2,
      spacing: CoeloSpacing.space3,
      children: [
        SizedBox(
          width: searchWidth ?? double.infinity,
          height: CoeloSize.touchMin,
          child: CoeloSearchField(
            controller: _search,
            hintText: 'Buscar aviso',
            semanticLabel: 'Buscar aviso por título ou destinatário',
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          width: 220,
          child: CoeloAdminSingleSelectField<_NoticeStatusFilter>(
            value: _statusFilter,
            label: 'Estado',
            options: _NoticeStatusFilter.values,
            optionLabel: (value) => '${value.label} (${statusMap[value]})',
            onChanged: (value) => setState(() => _statusFilter = value),
            prefixIcon: Icons.bar_chart_rounded,
          ),
        ),
        SizedBox(
          width: 190,
          child: CoeloAdminSingleSelectField<_NoticeTargetFilter>(
            value: _targetFilter,
            label: 'Plataforma',
            options: _NoticeTargetFilter.values,
            optionLabel: (value) => value.label,
            onChanged: (value) => setState(() => _targetFilter = value),
            prefixIcon: Icons.devices_rounded,
          ),
        ),
        SizedBox(
          width: 210,
          child: CoeloAdminSingleSelectField<_NoticePeriodFilter>(
            value: _periodFilter,
            label: 'Período',
            options: _NoticePeriodFilter.values,
            optionLabel: (value) => value.label,
            onChanged: (value) => setState(() => _periodFilter = value),
            prefixIcon: Icons.calendar_month_rounded,
          ),
        ),
      ],
    );

    final actions = SizedBox(
      height: CoeloSize.touchMin,
      child: FilledButton.icon(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo aviso'),
      ),
    );

    return CoeloAdminListingToolbar(search: filters, filters: const [], actions: [actions]);
  }

  Widget _editor(BuildContext context) {
    if (!_creating && _selectedNoticeId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editor de aviso', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: CoeloSpacing.space2),
              const Text('Selecione um aviso ou crie um novo para começar.'),
            ],
          ),
        ),
      );
    }

    return NoticeFormPage(
      repository: widget.repository,
      noticeId: _selectedNoticeId,
      embedded: true,
      onSaved: (notice) {
        setState(() {
          _creating = false;
          _selectedNoticeId = notice.id;
        });
      },
      onCancel: () {
        setState(() {
          _selectedNoticeId = null;
          _creating = false;
        });
      },
    );
  }

  Widget _list(
    BuildContext context, {
    required List<PlatformNotice> notices,
    required bool useDesktopLayout,
  }) {
    final cards = [
      CoeloAdminCreateAction(
        label: 'Novo aviso',
        description: 'Criar novo aviso.',
        icon: Icons.post_add_rounded,
        onPressed: () => _openCreate(context),
      ),
      ...notices.map((notice) => _noticeCard(context, notice: notice)),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = useDesktopLayout && constraints.maxWidth >= 380 ? 2 : 1;
        if (columns == 1) {
          return ListView.separated(
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
            itemBuilder: (context, index) => cards[index],
          );
        }
        return GridView.builder(
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: CoeloSpacing.space4,
            crossAxisSpacing: CoeloSpacing.space4,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _noticeCard(BuildContext context, {required PlatformNotice notice}) {
    return CoeloAdminInteractiveCard(
      onPressed: () => _edit(context, notice),
      minHeight: 190,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notice.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                _statusChip(context, notice.status),
                const SizedBox(width: CoeloSpacing.space2),
                _rowActionMenu(context, notice),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text('${notice.audienceLabel} · ${notice.audience.label}'),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              '${notice.targetDevice.label} · ${_formatDate(notice.startsAt)}'
              '${notice.endsAt == null ? ' · sem data limite' : ' · até ${_formatDate(notice.endsAt!)}'}',
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text('Recorrência: ${notice.recurrenceLabel}'),
            const SizedBox(height: CoeloSpacing.space1),
            Text('Obrigatório: ${notice.mandatory ? 'Sim' : 'Não'}'),
            const Spacer(),
            Text('Entregues: ${notice.deliveredCount} · Aceites: ${notice.acceptedCount}'),
          ],
        ),
      ),
    );
  }

  Widget _rowActionMenu(BuildContext context, PlatformNotice notice) {
    final actions = _rowActions(notice);
    return CoeloAdminFlyout<_NoticeCardAction>(
      itemWidth: 210,
      items: [
        if (actions.contains(_NoticeCardAction.edit))
          CoeloAdminFlyoutItem(
            value: _NoticeCardAction.edit,
            icon: Icons.edit_outlined,
            label: 'Editar',
          ),
        if (actions.contains(_NoticeCardAction.publish))
          CoeloAdminFlyoutItem(
            value: _NoticeCardAction.publish,
            icon: Icons.send_rounded,
            label: 'Publicar',
          ),
        if (actions.contains(_NoticeCardAction.pause))
          CoeloAdminFlyoutItem(
            value: _NoticeCardAction.pause,
            icon: Icons.pause_circle_outline_rounded,
            label: 'Pausar',
          ),
        if (actions.contains(_NoticeCardAction.resume))
          CoeloAdminFlyoutItem(
            value: _NoticeCardAction.resume,
            icon: Icons.play_circle_outline_rounded,
            label: 'Reativar',
          ),
        if (actions.contains(_NoticeCardAction.cancel))
          CoeloAdminFlyoutItem(
            value: _NoticeCardAction.cancel,
            icon: Icons.block,
            label: 'Inativar',
            startsGroup: true,
            tone: CoeloAdminFlyoutTone.negative,
          ),
        CoeloAdminFlyoutItem(
          value: _NoticeCardAction.duplicate,
          icon: Icons.copy_all_outlined,
          label: 'Duplicar',
        ),
      ],
      onSelected: (action) => _runAction(action, notice),
      builder: (context, controller) => IconButton(
        tooltip: 'Ações do aviso',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }

  Set<_NoticeCardAction> _rowActions(PlatformNotice notice) {
    final available = <_NoticeCardAction>{_NoticeCardAction.duplicate};
    if (notice.canEdit) {
      available.add(_NoticeCardAction.edit);
      available.add(_NoticeCardAction.publish);
    }
    if (notice.status == NoticeStatus.active) {
      available.add(_NoticeCardAction.pause);
    }
    if (notice.status == NoticeStatus.paused) {
      available.add(_NoticeCardAction.resume);
    }
    if (notice.status == NoticeStatus.active ||
        notice.status == NoticeStatus.scheduled ||
        notice.status == NoticeStatus.paused) {
      available.add(_NoticeCardAction.cancel);
    }
    return available;
  }

  void _runAction(_NoticeCardAction action, PlatformNotice notice) {
    try {
      switch (action) {
        case _NoticeCardAction.edit:
          _edit(context, notice);
          return;
        case _NoticeCardAction.duplicate:
          final duplicated = widget.repository.duplicate(notice.id);
          setState(() {
            _creating = false;
            _selectedNoticeId = duplicated.id;
          });
          _feedback('Aviso duplicado: ${duplicated.title}');
          return;
        case _NoticeCardAction.publish:
          final updated = widget.repository.publish(notice.id);
          _feedback('Aviso publicado: ${updated.title}');
          setState(() {});
          return;
        case _NoticeCardAction.pause:
          final paused = widget.repository.pause(notice.id);
          _feedback('Aviso pausado: ${paused.title}');
          setState(() {});
          return;
        case _NoticeCardAction.resume:
          final resumed = widget.repository.resume(notice.id);
          _feedback('Aviso reativado: ${resumed.title}');
          setState(() {});
          return;
        case _NoticeCardAction.cancel:
          final canceled = widget.repository.cancel(notice.id);
          _feedback('Aviso inativado: ${canceled.title}');
          setState(() {});
          return;
      }
    } on StateError catch (error) {
      _feedback(error.toString().replaceFirst('Exception: ', ''));
    }
    setState(() {});
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _edit(BuildContext context, PlatformNotice notice) {
    final compact = MediaQuery.of(context).size.width < CoeloBreakpoints.large.minWidth;
    if (compact) {
      _openEditorSheet(notice.id);
    } else {
      setState(() {
        _selectedNoticeId = notice.id;
        _creating = false;
      });
    }
  }

  void _openCreate(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < CoeloBreakpoints.large.minWidth;
    if (compact) {
      _openEditorSheet(null);
    } else {
      setState(() {
        _selectedNoticeId = null;
        _creating = true;
      });
    }
  }

  Future<void> _openEditorSheet(String? id) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<PlatformNotice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.brightness == Brightness.light
          ? Colors.white
          : theme.colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        widthFactor: 1,
        child: NoticeFormPage(
          repository: widget.repository,
          noticeId: id,
          embedded: true,
          onCancel: () => Navigator.pop(context),
          onSaved: (notice) => Navigator.pop(context, notice),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _creating = false;
        _selectedNoticeId = result.id;
      });
    }
  }

  Widget _statusChip(BuildContext context, NoticeStatus status) {
    final (background, foreground) = switch (status) {
      NoticeStatus.draft => (
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      NoticeStatus.scheduled => (
        Theme.of(context).colorScheme.secondaryContainer,
        Theme.of(context).colorScheme.onSecondaryContainer,
      ),
      NoticeStatus.active => (
        Theme.of(context).colorScheme.primaryContainer,
        Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      NoticeStatus.paused => (
        Theme.of(context).colorScheme.tertiaryContainer,
        Theme.of(context).colorScheme.onTertiaryContainer,
      ),
      NoticeStatus.ended => (
        Theme.of(context).colorScheme.surfaceDim,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      NoticeStatus.cancelled => (
        Theme.of(context).colorScheme.errorContainer,
        Theme.of(context).colorScheme.onErrorContainer,
      ),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: status.label,
      backgroundColor: background,
      foregroundColor: foreground,
      semanticLabel: 'Status ${status.label.toLowerCase()}',
    );
  }

  List<PlatformNotice> _filteredNotices() {
    final now = DateTime.now();
    final status = _statusFilter.status;
    final target = _targetFilter.device;
    final list = widget.repository.list(search: _search.text, status: status, target: target);
    return list
        .where((notice) {
          final inPeriod = switch (_periodFilter) {
            _NoticePeriodFilter.all => true,
            _NoticePeriodFilter.now =>
              notice.status == NoticeStatus.active &&
                  (notice.endsAt == null || notice.endsAt!.isAfter(now) || notice.endsAt == now),
            _NoticePeriodFilter.upcoming => notice.status == NoticeStatus.scheduled,
            _NoticePeriodFilter.ended => notice.status == NoticeStatus.ended,
          };
          return inPeriod &&
              (target == null ||
                  notice.targetDevice == NoticeTargetDevice.all ||
                  notice.targetDevice == target);
        })
        .toList(growable: false);
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}
