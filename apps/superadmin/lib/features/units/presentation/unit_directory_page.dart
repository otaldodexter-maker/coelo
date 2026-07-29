import 'dart:ui';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/unit_directory.dart';
import 'unit_directory_view_model.dart';
import 'widgets/unit_directory_cards.dart';
import 'widgets/unit_directory_pagination.dart';
import 'widgets/unit_directory_states.dart';
import 'widgets/unit_directory_table.dart';
import 'widgets/unit_directory_toolbar.dart';

final class UnitDirectoryPage extends StatefulWidget {
  const UnitDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onEdit,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.successMessage,
    super.key,
  });

  final UnitDirectoryRepository repository;
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
    return SuperadminShell(
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
            searchController: _searchController,
            display: _display,
            onDisplayChanged: _changeDisplay,
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

final class _UnitDirectoryContent extends StatefulWidget {
  const _UnitDirectoryContent({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.onDisplayChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
    required this.onClearFilters,
  });

  final UnitDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final UnitDirectoryDisplay display;
  final ValueChanged<UnitDirectoryDisplay> onDisplayChanged;
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
                      searchController: widget.searchController,
                      display: widget.display,
                      onDisplayChanged: widget.onDisplayChanged,
                      onClearFilters: widget.onClearFilters,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _UnitDirectoryResults(
                      viewModel: widget.viewModel,
                      display: widget.display,
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

final class _UnitDirectoryResults extends StatelessWidget {
  const _UnitDirectoryResults({
    required this.viewModel,
    required this.display,
    required this.onCreate,
    required this.onEdit,
  });

  final UnitDirectoryViewModel viewModel;
  final UnitDirectoryDisplay display;
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
    final colors = Theme.of(context).colorScheme;
    return ClipRect(
      key: const Key('unit-directory-pagination-footer'),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: CoeloSpacing.space2, sigmaY: CoeloSpacing.space2),
        child: Container(
          key: const Key('unit-directory-pagination-footer-surface'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            CoeloSpacing.space3,
            horizontalPadding,
            CoeloSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .88),
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: UnitDirectoryPagination(
              viewModel: viewModel,
              pageSizeOptions: display == UnitDirectoryDisplay.cards
                  ? const [11, 20, 50, 100]
                  : const [8, 20, 50, 100],
            ),
          ),
        ),
      ),
    );
  }
}
