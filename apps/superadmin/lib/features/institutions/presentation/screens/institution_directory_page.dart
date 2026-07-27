import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_notice.dart';
import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../../support/domain/support_ticket.dart';
import '../../domain/institution_directory_query.dart';
import '../../domain/institution_directory_repository.dart';
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
  bool _noticeShown = false;

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
      onBugReportSubmitted: widget.onBugReportSubmitted,
      onDestinationSelected: (destination) {
        if (destination == 'home') {
          widget.onHomeOpen?.call();
        } else if (destination == 'catalog') {
          widget.onCatalogOpen?.call();
        } else if (destination == 'support') {
          widget.onSupportOpen?.call();
        } else if (destination == 'conversations') {
          widget.onConversationsOpen?.call();
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
            onDisplayChanged: (display) => setState(() => _display = display),
            onCreate: widget.onCreate ?? () {},
            onEdit: widget.onEdit ?? (_) {},
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

class _InstitutionDirectoryContent extends StatelessWidget {
  const _InstitutionDirectoryContent({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.onDisplayChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onClearFilters,
  });

  final InstitutionDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final InstitutionDirectoryDisplay display;
  final ValueChanged<InstitutionDirectoryDisplay> onDisplayChanged;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return ListView(
          key: const Key('institution-directory-content-scroll'),
          padding: EdgeInsets.all(horizontalPadding),
          children: [
            AnimatedBuilder(
              animation: viewModel,
              builder: (context, child) => InstitutionDirectoryToolbar(
                viewModel: viewModel,
                activityController: activityController,
                searchController: searchController,
                display: display,
                onDisplayChanged: onDisplayChanged,
                onClearFilters: onClearFilters,
              ),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            _InstitutionDirectoryResults(
              viewModel: viewModel,
              display: display,
              onCreate: onCreate,
              onEdit: onEdit,
            ),
          ],
        );
      },
    );
  }
}

class _InstitutionDirectoryResults extends StatelessWidget {
  const _InstitutionDirectoryResults({
    required this.viewModel,
    required this.display,
    required this.onCreate,
    required this.onEdit,
  });

  final InstitutionDirectoryViewModel viewModel;
  final InstitutionDirectoryDisplay display;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, child) {
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
                      createAction: InstitutionCreateBanner(onPressed: onCreate),
                      onEdit: (item) => onEdit(item.id),
                    )
                  : InstitutionDirectoryCards(
                      items: viewModel.page.items,
                      onCreate: onCreate,
                      onEdit: (item) => onEdit(item.id),
                    ),
            ),
            if (viewModel.state == InstitutionDirectoryLoadState.success &&
                (viewModel.page.totalCount / InstitutionDirectoryQuery.pageSize).ceil() > 1) ...[
              const SizedBox(height: CoeloSpacing.space4),
              Align(
                alignment: Alignment.centerRight,
                child: InstitutionDirectoryPagination(viewModel: viewModel),
              ),
            ],
          ],
        );
      },
    );
  }
}
