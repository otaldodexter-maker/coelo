import 'institution_directory_item.dart';

final class InstitutionDirectoryPage {
  const InstitutionDirectoryPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<InstitutionDirectoryItem> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasPrevious => page > 0;
  bool get hasNext => (page * pageSize) + items.length < totalCount;
}
