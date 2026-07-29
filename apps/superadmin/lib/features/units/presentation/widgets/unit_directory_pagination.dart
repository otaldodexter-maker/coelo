import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/widgets.dart';

import '../unit_directory_view_model.dart';

final class UnitDirectoryPagination extends StatelessWidget {
  const UnitDirectoryPagination({
    required this.viewModel,
    required this.pageSizeOptions,
    super.key,
  });

  final UnitDirectoryViewModel viewModel;
  final List<int> pageSizeOptions;

  @override
  Widget build(BuildContext context) {
    final page = viewModel.page;
    final totalPages = (page.totalCount / viewModel.query.pageSize).ceil();
    return CoeloAdminPagination(
      currentPage: page.page + 1,
      totalPages: totalPages,
      pageSize: viewModel.query.pageSize,
      pageSizeOptions: pageSizeOptions,
      onPageSelected: (value) => viewModel.goToPage(value - 1),
      onPageSizeChanged: viewModel.setPageSize,
      onPrevious: page.hasPrevious ? () => viewModel.goToPage(page.page - 1) : null,
      onNext: page.hasNext ? () => viewModel.goToPage(page.page + 1) : null,
    );
  }
}
