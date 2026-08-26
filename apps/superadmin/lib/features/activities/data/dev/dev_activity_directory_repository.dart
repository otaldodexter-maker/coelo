import '../../../../app/dev_menu/development_activity_fixture_repository.dart';
import '../../domain/activity_directory.dart';
import 'dev_activity_session_store.dart';

final class DevActivityDirectoryRepository implements ActivityDirectoryRepository {
  DevActivityDirectoryRepository({required this.store})
    : _base = DevelopmentActivityFixtureRepository(
        seed: store.mode == DevActivitySessionMode.content ? null : const [],
      ),
      _catalog = DevelopmentActivityFixtureRepository();

  final DevActivitySessionStore store;
  final DevelopmentActivityFixtureRepository _base;
  final DevelopmentActivityFixtureRepository _catalog;

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    store.guardDirectory();
    final base = await _base.fetchPage(ActivityDirectoryQuery(pageSize: 100));
    final details = <ActivityDetail>[];
    for (final item in base.items) {
      final detail = store.detail(item.id) ?? await _base.fetchById(item.id);
      if (detail != null) {
        store.remember(detail);
        details.add(detail);
      }
    }
    final overlaidIds = store.details.map((detail) => detail.item.id).toSet();
    details.removeWhere((detail) => overlaidIds.contains(detail.item.id));
    details.addAll(store.details);
    details.removeWhere(
      (detail) =>
          (query.unitIds.isNotEmpty &&
              !detail.units.any((unit) => query.unitIds.contains(unit.id))) ||
          (query.groupIds.isNotEmpty &&
              !detail.groups.any((group) => query.groupIds.contains(group.id))),
    );
    return DevelopmentActivityFixtureRepository(seed: details).fetchPage(query);
  }

  @override
  Future<ActivityDetail?> fetchById(String activityId) async {
    store.guardDirectory();
    final detail = store.detail(activityId) ?? await _base.fetchById(activityId);
    if (detail != null) store.remember(detail);
    return detail;
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() {
    store.guardDirectory();
    return _base.fetchFilterOptions();
  }

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) {
    store.guardDirectory();
    return _catalog.fetchFormOptions(institutionId: institutionId);
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) {
    store.guardDirectory();
    return _catalog.fetchTemplateOptions(institutionId: institutionId);
  }

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) {
    store.guardDirectory();
    return _catalog.searchProfessionals(institutionId: institutionId, query: query, limit: limit);
  }
}
