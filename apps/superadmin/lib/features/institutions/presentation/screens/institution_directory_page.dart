import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';
import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
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
    this.onCatalogOpen,
    super.key,
  });

  final InstitutionDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCatalogOpen;

  @override
  State<InstitutionDirectoryPage> createState() => _InstitutionDirectoryPageState();
}

class _InstitutionDirectoryPageState extends State<InstitutionDirectoryPage> {
  late final InstitutionDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  InstitutionDirectoryDisplay _display = InstitutionDirectoryDisplay.cards;

  @override
  void initState() {
    super.initState();
    _viewModel = InstitutionDirectoryViewModel(repository: widget.repository);
    _activityController = SuperadminActivityController();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _showFutureFlowMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      activityController: _activityController,
      onDestinationSelected: (destination) {
        if (destination == 'catalog') {
          widget.onCatalogOpen?.call();
        }
      },
      child: _InstitutionDirectoryContent(
        viewModel: _viewModel,
        activityController: _activityController,
        searchController: _searchController,
        display: _display,
        onDisplayChanged: (display) => setState(() => _display = display),
        onCreate: () =>
            _showFutureFlowMessage('O cadastro de instituições será implementado em breve.'),
        onClearFilters: () {
          _searchController.clear();
          _viewModel.clearFilters();
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
    required this.onClearFilters,
  });

  final InstitutionDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final InstitutionDirectoryDisplay display;
  final ValueChanged<InstitutionDirectoryDisplay> onDisplayChanged;
  final VoidCallback onCreate;
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
  });

  final InstitutionDirectoryViewModel viewModel;
  final InstitutionDirectoryDisplay display;
  final VoidCallback onCreate;

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
                    )
                  : InstitutionDirectoryCards(items: viewModel.page.items, onCreate: onCreate),
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
