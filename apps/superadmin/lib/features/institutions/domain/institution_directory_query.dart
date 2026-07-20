import 'institution_directory_item.dart';

final class InstitutionDirectoryQuery {
  const InstitutionDirectoryQuery({
    this.search = '',
    this.status,
    this.planId,
    this.state,
    this.city,
    this.district,
    this.typeId,
    this.page = 0,
  }) : assert(page >= 0);

  static const pageSize = 20;

  final String search;
  final InstitutionStatus? status;
  final String? planId;
  final String? state;
  final String? city;
  final String? district;
  final String? typeId;
  final int page;

  int get offset => page * pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      status != null ||
      planId != null ||
      state != null ||
      city != null ||
      district != null ||
      typeId != null;

  @override
  bool operator ==(Object other) {
    return other is InstitutionDirectoryQuery &&
        other.search == search &&
        other.status == status &&
        other.planId == planId &&
        other.state == state &&
        other.city == city &&
        other.district == district &&
        other.typeId == typeId &&
        other.page == page;
  }

  @override
  int get hashCode => Object.hash(search, status, planId, state, city, district, typeId, page);
}
