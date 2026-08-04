import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';
import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../../support/domain/support_ticket.dart';
import '../../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../../domain/institution_directory_item.dart';
import '../../domain/institution_directory_repository.dart';
import '../institution_directory_table_view.dart';
import '../view_models/institution_directory_view_model.dart';
import '../widgets/institution_directory_cards.dart';
import '../widgets/institution_directory_pagination.dart';
import '../widgets/institution_directory_states.dart';
import '../widgets/institution_directory_table.dart';
import '../widgets/institution_directory_toolbar.dart';

class InstitutionDirectoryPage extends StatefulWidget {
  const InstitutionDirectoryPage({
    required this.repository,
    required this.logout,
    this.onHomeOpen,
    this.onUnitsOpen,
    this.onPeopleOpen,
    this.onCatalogOpen,
    this.onSupportOpen,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.onCreate,
    this.onEdit,
    this.successMessage,
    super.key,
  });

  final InstitutionDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onHomeOpen;
  final VoidCallback? onUnitsOpen;
  final VoidCallback? onPeopleOpen;
  final VoidCallback? onCatalogOpen;
  final VoidCallback? onSupportOpen;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final String? successMessage;

  @override
  State<InstitutionDirectoryPage> createState() => _InstitutionDirectoryPageState();
}

class _InstitutionDirectoryPageState extends State<InstitutionDirectoryPage> {
  late final InstitutionDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  InstitutionDirectoryDisplay _display = InstitutionDirectoryDisplay.cards;
  InstitutionDirectoryTableView _tableView = InstitutionDirectoryTableView.grouped;
  bool _noticeShown = false;
  double _paginationFooterHeight = 0;

  void _changeDisplay(InstitutionDirectoryDisplay display) {
    if (display == _display) {
      return;
    }
    setState(() => _display = display);
    _viewModel.setPageSize(
      display == InstitutionDirectoryDisplay.cards ? 11 : 8,
      resetSort: display == InstitutionDirectoryDisplay.cards,
    );
  }

  void _changeTableView(InstitutionDirectoryTableView view) {
    final wasCards = _display == InstitutionDirectoryDisplay.cards;
    setState(() {
      _display = InstitutionDirectoryDisplay.table;
      _tableView = view;
    });
    if (wasCards) {
      _viewModel.setPageSize(8);
    }
  }

  void _handlePaginationFooterHeightChanged(double height) {
    if ((_paginationFooterHeight - height).abs() < 0.5) {
      return;
    }
    setState(() => _paginationFooterHeight = height);
  }

  @override
  void initState() {
    super.initState();
    _viewModel = InstitutionDirectoryViewModel(repository: widget.repository);
    _activityController = SuperadminActivityController();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant InstitutionDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.successMessage != widget.successMessage) {
      _noticeShown = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      activityController: _activityController,
      showChatLauncher: widget.onConversationsOpen != null,
      chatLauncherBottomInset: _paginationFooterHeight,
      onBugReportSubmitted: widget.onBugReportSubmitted,
      onOpenConversations: widget.onConversationsOpen,
      onDestinationSelected: (destination) {
        if (destination == 'home') {
          widget.onHomeOpen?.call();
        } else if (destination == 'units') {
          widget.onUnitsOpen?.call();
        } else if (destination == 'people') {
          widget.onPeopleOpen?.call();
        } else if (destination == 'catalog') {
          widget.onCatalogOpen?.call();
        } else if (destination == 'support') {
          widget.onSupportOpen?.call();
        }
      },
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
          return _InstitutionDirectoryContent(
            viewModel: _viewModel,
            activityController: _activityController,
            searchController: _searchController,
            display: _display,
            tableView: _tableView,
            avoidChatLauncher: widget.onConversationsOpen != null,
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
    );
  }
}

class _InstitutionDirectoryContent extends StatefulWidget {
  const _InstitutionDirectoryContent({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.avoidChatLauncher,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
    required this.onClearFilters,
  });

  final InstitutionDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final InstitutionDirectoryDisplay display;
  final InstitutionDirectoryTableView tableView;
  final bool avoidChatLauncher;
  final ValueChanged<InstitutionDirectoryDisplay> onDisplayChanged;
  final ValueChanged<InstitutionDirectoryTableView> onTableViewChanged;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final ValueChanged<double> onFooterHeightChanged;
  final VoidCallback onClearFilters;

  @override
  State<_InstitutionDirectoryContent> createState() => _InstitutionDirectoryContentState();
}

class _InstitutionDirectoryContentState extends State<_InstitutionDirectoryContent> {
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
      if ((nextHeight - _footerHeight).abs() < 0.5) {
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
            final showPagination = widget.viewModel.state == InstitutionDirectoryLoadState.success;
            _scheduleFooterMeasurement(showPagination);
            final footerInset = showPagination ? _footerHeight + CoeloSpacing.space4 : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                ListView(
                  key: const Key('institution-directory-content-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    horizontalPadding,
                    horizontalPadding,
                    horizontalPadding + footerInset,
                  ),
                  children: [
                    InstitutionDirectoryToolbar(
                      viewModel: widget.viewModel,
                      activityController: widget.activityController,
                      searchController: widget.searchController,
                      display: widget.display,
                      tableView: widget.tableView,
                      onDisplayChanged: widget.onDisplayChanged,
                      onTableViewChanged: widget.onTableViewChanged,
                      onClearFilters: widget.onClearFilters,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _InstitutionStatusTabs(viewModel: widget.viewModel),
                    const SizedBox(height: CoeloSpacing.space4),
                    _InstitutionDirectoryResults(
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
                        child: _InstitutionDirectoryPaginationFooter(
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

class _InstitutionStatusTabs extends StatelessWidget {
  const _InstitutionStatusTabs({required this.viewModel});

  final InstitutionDirectoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selected = viewModel.query.statuses.length == 1 ? viewModel.query.statuses.single : null;
    return SuperadminUnderlineTabs<InstitutionStatus?>(
      key: const Key('institution-status-tabs'),
      selected: selected,
      tabs: const [
        SuperadminUnderlineTab(value: null, label: 'Todos'),
        SuperadminUnderlineTab(value: InstitutionStatus.active, label: 'Ativos'),
        SuperadminUnderlineTab(value: InstitutionStatus.onboarding, label: 'Em Implantação'),
        SuperadminUnderlineTab(value: InstitutionStatus.inactive, label: 'Inativos'),
      ],
      onSelected: (status) => viewModel.setStatuses(status == null ? const {} : {status}),
    );
  }
}

class _InstitutionDirectoryResults extends StatelessWidget {
  const _InstitutionDirectoryResults({
    required this.viewModel,
    required this.display,
    required this.tableView,
    required this.onCreate,
    required this.onEdit,
  });

  final InstitutionDirectoryViewModel viewModel;
  final InstitutionDirectoryDisplay display;
  final InstitutionDirectoryTableView tableView;
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
        InstitutionDirectoryStates(
          viewModel: viewModel,
          successContent: display == InstitutionDirectoryDisplay.table
              ? InstitutionDirectoryTable(
                  items: viewModel.page.items,
                  view: tableView,
                  createAction: InstitutionCreateBanner(onPressed: onCreate),
                  onEdit: (item) => onEdit(item.id),
                  sortColumn: viewModel.query.sortColumn,
                  sortAscending: viewModel.query.sortAscending,
                  onSort: viewModel.setSort,
                )
              : InstitutionDirectoryCards(
                  items: viewModel.page.items,
                  onCreate: onCreate,
                  onEdit: (item) => onEdit(item.id),
                ),
        ),
      ],
    );
  }
}

class _InstitutionDirectoryPaginationFooter extends StatelessWidget {
  const _InstitutionDirectoryPaginationFooter({
    required this.viewModel,
    required this.display,
    required this.horizontalPadding,
  });

  final InstitutionDirectoryViewModel viewModel;
  final InstitutionDirectoryDisplay display;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SuperadminListingPaginationFooter(
      semanticKey: const Key('institution-directory-pagination-footer'),
      horizontalPadding: horizontalPadding,
      child: KeyedSubtree(
        key: const Key('institution-directory-pagination-footer-surface'),
        child: InstitutionDirectoryPagination(
          viewModel: viewModel,
          pageSizeOptions: display == InstitutionDirectoryDisplay.cards
              ? const [11, 20, 50, 100]
              : const [8, 20, 50, 100],
        ),
      ),
    );
  }
}
