import 'institution_directory_item.dart';
import 'institution_directory_query.dart';

final class InstitutionDirectoryPage {
  const InstitutionDirectoryPage({
    required this.items,
    required this.totalCount,
    required this.page,
  });

  final List<InstitutionDirectoryItem> items;
  final int totalCount;
  final int page;

  bool get hasPrevious => page > 0;
  bool get hasNext => (page * InstitutionDirectoryQuery.pageSize) + items.length < totalCount;
}
