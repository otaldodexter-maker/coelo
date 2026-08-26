import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../domain/unit_backend_commands.dart';
import '../domain/unit_directory.dart';
import 'unit_directory_table_view.dart';
import 'unit_directory_view_model.dart';
import 'widgets/unit_directory_cards.dart';
import 'widgets/unit_directory_pagination.dart';
import 'widgets/unit_directory_states.dart';
import 'widgets/unit_directory_table.dart';
import 'widgets/unit_directory_toolbar.dart';

enum _UnitStatusSegment { all, active, onboarding, inactive }

String _newUnitRequestId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

final class UnitDirectoryPage extends StatefulWidget {
  const UnitDirectoryPage({
    required this.repository,
    required this.logout,
    this.backendCommands,
    this.requestIdFactory,
    this.onCreate,
    this.onEdit,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.successMessage,
    super.key,
  });

  final UnitDirectoryRepository repository;
  final UnitBackendCommandsGateway? backendCommands;
  final String Function()? requestIdFactory;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String? successMessage;

  @override
  State<UnitDirectoryPage> createState() => _UnitDirectoryPageState();
}

final class _UnitDirectoryPageState extends State<UnitDirectoryPage> {
  late final UnitDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  UnitDirectoryDisplay _display = UnitDirectoryDisplay.cards;
  UnitDirectoryTableView _tableView = UnitDirectoryTableView.grouped;
  bool _noticeShown = false;
  double _paginationFooterHeight = 0;

  void _changeDisplay(UnitDirectoryDisplay display) {
    if (display == _display) {
      return;
    }
    setState(() => _display = display);
    _viewModel.setPageSize(
      display == UnitDirectoryDisplay.cards ? 11 : 8,
      resetSort: display == UnitDirectoryDisplay.cards,
    );
  }

  void _changeTableView(UnitDirectoryTableView view) {
    final wasCards = _display == UnitDirectoryDisplay.cards;
    setState(() {
      _display = UnitDirectoryDisplay.table;
      _tableView = view;
    });
    if (wasCards) {
      _viewModel.setPageSize(8, resetSort: false);
    }
  }

  void _handlePaginationFooterHeightChanged(double height) {
    if ((_paginationFooterHeight - height).abs() < .5) {
      return;
    }
    setState(() => _paginationFooterHeight = height);
  }

  @override
  void initState() {
    super.initState();
    _viewModel = UnitDirectoryViewModel(widget.repository);
    _searchController = TextEditingController();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant UnitDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.successMessage != widget.successMessage) {
      _noticeShown = false;
    }
  }

  @override
  void dispose() {
    _activityController.dispose();
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: theme.colorScheme.surface),
      child: SuperadminShell(
        logout: widget.logout,
        title: 'Unidades',
        subtitle: 'Gerencie as unidades da plataforma.',
        currentDestination: 'units',
        activityController: _activityController,
        showChatLauncher: widget.onConversationsOpen != null,
        chatLauncherBottomInset: _paginationFooterHeight,
        onBugReportSubmitted: widget.onBugReportSubmitted,
        onOpenConversations: widget.onConversationsOpen,
        onDestinationSelected: widget.onDestinationSelected,
        child: Builder(
          builder: (context) {
            final message = widget.successMessage;
            if (message != null && !_noticeShown) {
              _noticeShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  showSuperadminNotice(context, message, icon: Icons.check_circle_outline_rounded);
                }
              });
            }
            return _UnitDirectoryContent(
              viewModel: _viewModel,
              activityController: _activityController,
              backendCommands: widget.backendCommands,
              requestIdFactory: widget.requestIdFactory ?? _newUnitRequestId,
              searchController: _searchController,
              display: _display,
              tableView: _tableView,
              onDisplayChanged: _changeDisplay,
              onTableViewChanged: _changeTableView,
              onCreate: widget.onCreate ?? () {},
              onEdit: widget.onEdit ?? (_) {},
              onFooterHeightChanged: _handlePaginationFooterHeightChanged,
              onClearFilters: () {
                _searchController.clear();
                _viewModel.clearFilters();
              },
            );
          },
        ),
      ),
    );
  }
}

final class _UnitDirectoryContent extends StatefulWidget {
  const _UnitDirectoryContent({
    required this.viewModel,
    required this.activityController,
    required this.backendCommands,
    required this.requestIdFactory,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
    required this.onClearFilters,
  });

  final UnitDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final UnitBackendCommandsGateway? backendCommands;
  final String Function() requestIdFactory;
  final TextEditingController searchController;
  final UnitDirectoryDisplay display;
  final UnitDirectoryTableView tableView;
  final ValueChanged<UnitDirectoryDisplay> onDisplayChanged;
  final ValueChanged<UnitDirectoryTableView> onTableViewChanged;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final ValueChanged<double> onFooterHeightChanged;
  final VoidCallback onClearFilters;

  @override
  State<_UnitDirectoryContent> createState() => _UnitDirectoryContentState();
}

final class _UnitDirectoryContentState extends State<_UnitDirectoryContent> {
  final GlobalKey _footerKey = GlobalKey();
  double _footerHeight = 0;
  bool _measurementScheduled = false;

  void _scheduleFooterMeasurement(bool showFooter) {
    if (_measurementScheduled) {
      return;
    }
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) {
        return;
      }
      var nextHeight = 0.0;
      if (showFooter) {
        final renderObject = _footerKey.currentContext?.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) {
          return;
        }
        nextHeight = renderObject.size.height;
      }
      if ((nextHeight - _footerHeight).abs() < .5) {
        return;
      }
      setState(() => _footerHeight = nextHeight);
      widget.onFooterHeightChanged(nextHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, child) {
            final showPagination = widget.viewModel.state == UnitDirectoryLoadState.success;
            _scheduleFooterMeasurement(showPagination);
            final footerInset = showPagination ? _footerHeight + CoeloSpacing.space4 : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                ListView(
                  key: const Key('unit-directory-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    horizontalPadding,
                    horizontalPadding,
                    horizontalPadding + footerInset,
                  ),
                  children: [
                    UnitDirectoryToolbar(
                      viewModel: widget.viewModel,
                      activityController: widget.activityController,
                      backendCommands: widget.backendCommands,
                      requestIdFactory: widget.requestIdFactory,
                      searchController: widget.searchController,
                      display: widget.display,
                      tableView: widget.tableView,
                      onDisplayChanged: widget.onDisplayChanged,
                      onTableViewChanged: widget.onTableViewChanged,
                      onClearFilters: widget.onClearFilters,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    SuperadminUnderlineTabs<_UnitStatusSegment>(
                      key: const Key('unit-status-tabs'),
                      tabs: const [
                        SuperadminUnderlineTab(value: _UnitStatusSegment.all, label: 'Todos'),
                        SuperadminUnderlineTab(value: _UnitStatusSegment.active, label: 'Ativos'),
                        SuperadminUnderlineTab(
                          value: _UnitStatusSegment.onboarding,
                          label: 'Em Implantação',
                        ),
                        SuperadminUnderlineTab(
                          value: _UnitStatusSegment.inactive,
                          label: 'Inativos',
                        ),
                      ],
                      selected: _segmentFor(widget.viewModel.query.statuses),
                      onSelected: (segment) => widget.viewModel.setStatuses(_statusesFor(segment)),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _UnitDirectoryResults(
                      viewModel: widget.viewModel,
                      display: widget.display,
                      tableView: widget.tableView,
                      onCreate: widget.onCreate,
                      onEdit: widget.onEdit,
                    ),
                  ],
                ),
                if (showPagination)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        _scheduleFooterMeasurement(true);
                        return true;
                      },
                      child: SizeChangedLayoutNotifier(
                        key: _footerKey,
                        child: _UnitDirectoryPaginationFooter(
                          viewModel: widget.viewModel,
                          display: widget.display,
                          horizontalPadding: horizontalPadding,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

_UnitStatusSegment _segmentFor(Set<UnitStatus> statuses) {
  if (statuses.length == 1 && statuses.contains(UnitStatus.active)) {
    return _UnitStatusSegment.active;
  }
  if (statuses.length == 1 && statuses.contains(UnitStatus.draft)) {
    return _UnitStatusSegment.onboarding;
  }
  if (statuses.length == 3 &&
      statuses.containsAll(const {
        UnitStatus.inactive,
        UnitStatus.suspended,
        UnitStatus.archived,
      })) {
    return _UnitStatusSegment.inactive;
  }
  return _UnitStatusSegment.all;
}

Set<UnitStatus> _statusesFor(_UnitStatusSegment segment) => switch (segment) {
  _UnitStatusSegment.all => const {},
  _UnitStatusSegment.active => const {UnitStatus.active},
  _UnitStatusSegment.onboarding => const {UnitStatus.draft},
  _UnitStatusSegment.inactive => const {
    UnitStatus.inactive,
    UnitStatus.suspended,
    UnitStatus.archived,
  },
};

final class _UnitDirectoryResults extends StatelessWidget {
  const _UnitDirectoryResults({
    required this.viewModel,
    required this.display,
    required this.tableView,
    required this.onCreate,
    required this.onEdit,
  });

  final UnitDirectoryViewModel viewModel;
  final UnitDirectoryDisplay display;
  final UnitDirectoryTableView tableView;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.isLoading) const LinearProgressIndicator(),
        if (viewModel.isLoading) const SizedBox(height: CoeloSpacing.space4),
        UnitDirectoryStates(
          viewModel: viewModel,
          successContent: display == UnitDirectoryDisplay.table
              ? UnitDirectoryTable(
                  items: viewModel.page.items,
                  createAction: UnitCreateBanner(onPressed: onCreate),
                  onEdit: (item) => onEdit(item.id),
                  sortColumn: viewModel.query.sortColumn,
                  sortAscending: viewModel.query.sortAscending,
                  onSort: viewModel.setSort,
                  view: tableView,
                )
              : UnitDirectoryCards(
                  items: viewModel.page.items,
                  onCreate: onCreate,
                  onEdit: (item) => onEdit(item.id),
                ),
        ),
      ],
    );
  }
}

final class _UnitDirectoryPaginationFooter extends StatelessWidget {
  const _UnitDirectoryPaginationFooter({
    required this.viewModel,
    required this.display,
    required this.horizontalPadding,
  });

  final UnitDirectoryViewModel viewModel;
  final UnitDirectoryDisplay display;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SuperadminListingPaginationFooter(
      semanticKey: const Key('unit-directory-pagination-footer'),
      horizontalPadding: horizontalPadding,
      child: UnitDirectoryPagination(
        viewModel: viewModel,
        pageSizeOptions: display == UnitDirectoryDisplay.cards
            ? const [11, 20, 50, 100]
            : const [8, 20, 50, 100],
      ),
    );
  }
}
