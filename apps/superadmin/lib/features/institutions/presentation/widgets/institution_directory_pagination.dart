import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/widgets.dart';

import '../../domain/institution_directory_query.dart';
import '../view_models/institution_directory_view_model.dart';

final class InstitutionDirectoryPagination extends StatelessWidget {
  const InstitutionDirectoryPagination({required this.viewModel, super.key});

  final InstitutionDirectoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final page = viewModel.page;
    final totalPages = (page.totalCount / InstitutionDirectoryQuery.pageSize).ceil();
    return CoeloAdminPagination(
      currentPage: page.page + 1,
      totalPages: totalPages,
      onPrevious: page.hasPrevious ? () => viewModel.goToPage(page.page - 1) : null,
      onNext: page.hasNext ? () => viewModel.goToPage(page.page + 1) : null,
    );
  }
}
