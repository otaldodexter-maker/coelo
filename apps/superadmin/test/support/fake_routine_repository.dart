import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';

typedef RoutinePageLoader = Future<RoutineDirectoryPage> Function(RoutineDirectoryQuery query);

final class FakeRoutineRepository implements RoutineRepository {
  FakeRoutineRepository({
    this.pageLoader,
    List<RoutineModel> models = const [],
    List<RoutineApplication> applications = const [],
    List<RoutineLaunch> launches = const [],
    this.canManage = false,
  }) : _models = [...models],
       _applications = [...applications],
       _launches = [...launches];

  final RoutinePageLoader? pageLoader;
  final bool canManage;
  final List<RoutineModel> _models;
  final List<RoutineApplication> _applications;
  final List<RoutineLaunch> _launches;

  final List<RoutineDirectoryQuery> pageQueries = [];
  List<RoutineAnswerCorrection> lastCorrections = [];
  String? lastCorrectionReason;

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async {
    pageQueries.add(query);
    final loader = pageLoader;
    if (loader != null) return loader(query);

    final items = switch (query.kind) {
      RoutineEntryKind.model => _models.map(
        (value) => RoutineDirectoryItem(
          id: value.id,
          kind: RoutineEntryKind.model,
          name: value.name,
          status: value.status.name,
          version: value.version,
        ),
      ),
      RoutineEntryKind.application => _applications.map(
        (value) => RoutineDirectoryItem(
          id: value.id,
          kind: RoutineEntryKind.application,
          name: value.id,
          status: value.status.name,
          version: value.effectiveVersion,
        ),
      ),
      RoutineEntryKind.launch => _launches.map(
        (value) => RoutineDirectoryItem(
          id: value.id,
          kind: RoutineEntryKind.launch,
          name: value.id,
          status: value.status.name,
          version: value.expectedVersion,
        ),
      ),
    };
    final search = query.search.trim().toLowerCase();
    final filtered = items
        .where((item) => search.isEmpty || item.name.toLowerCase().contains(search))
        .where((item) => query.status == null || item.status == query.status)
        .toList(growable: false);
    final start = ((query.page - 1) * query.pageSize).clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return RoutineDirectoryPage(
      items: filtered.sublist(start, end),
      page: query.page,
      pageSize: query.pageSize,
      totalCount: filtered.length,
      canManage: canManage,
    );
  }

  @override
  Future<RoutineModel> fetchModel(String id) async =>
      _models.where((value) => value.id == id).firstOrNull ??
      (throw const RoutineTestNotFoundException());

  @override
  Future<RoutineApplication> fetchApplication(String id) async =>
      _applications.where((value) => value.id == id).firstOrNull ??
      (throw const RoutineTestNotFoundException());

  @override
  Future<RoutineLaunch> fetchLaunch(String id) async =>
      _launches.where((value) => value.id == id).firstOrNull ??
      (throw const RoutineTestNotFoundException());

  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async {
    _replaceById(_models, model, (value) => value.id);
    return model.id;
  }

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async {
    _replaceById(_applications, application, (value) => value.id);
    return application.id;
  }

  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async {
    _replaceById(_launches, launch, (value) => value.id);
    return launch.id;
  }

  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async => applicationId;

  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async {}

  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async {
    lastCorrectionReason = reason;
    lastCorrections = [...corrections];
  }
}

final class RoutineTestNotFoundException implements Exception {
  const RoutineTestNotFoundException();
}

void _replaceById<T>(List<T> values, T replacement, String Function(T value) idOf) {
  final index = values.indexWhere((value) => idOf(value) == idOf(replacement));
  if (index == -1) {
    values.add(replacement);
  } else {
    values[index] = replacement;
  }
}
