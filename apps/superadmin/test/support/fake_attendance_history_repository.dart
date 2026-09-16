import 'package:coelo_superadmin/features/attendance/attendance.dart';

/// Leitor de histórico determinístico para testes de widget (spec 052).
///
/// `pages` é a sequência devolvida a cada `fetchHistory`: a primeira leitura
/// sem cursor devolve `pages[0]`, o cursor `next-N` devolve `pages[N]`.
final class FakeAttendanceHistoryRepository implements AttendanceHistoryRepository {
  const FakeAttendanceHistoryRepository({
    this.pages = const [AttendanceHistoryPageResult(items: [], hasMore: false)],
    this.options = const AttendanceContextOptions(
      institutions: [],
      units: [],
      groups: [],
      activities: [],
    ),
    this.error,
    this.queries,
  });

  final List<AttendanceHistoryPageResult> pages;
  final AttendanceContextOptions options;
  final Object? error;
  final List<AttendanceHistoryQuery>? queries;

  @override
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date}) async {
    if (error != null) throw error!;
    return options;
  }

  @override
  Future<AttendanceHistoryPageResult> fetchHistory(AttendanceHistoryQuery query) async {
    queries?.add(query);
    if (error != null) throw error!;
    final cursor = query.cursor;
    if (cursor == null) return pages.first;
    final index = int.parse(cursor.substring('next-'.length));
    return pages[index];
  }
}

AttendanceHistoryItem fakeHistoryItem(
  String id, {
  DateTime? date,
  String groupName = 'Turma Sol',
  String? activityName,
  AttendanceCallStatus status = AttendanceCallStatus.completed,
  String responsible = 'Ana Educadora',
  int expected = 12,
  int present = 10,
  int absent = 2,
  AttendanceRoutineRef routine = const AttendanceRoutineRef.none(),
  bool canOpen = true,
}) => AttendanceHistoryItem(
  id: id,
  date: date ?? DateTime(2026, 9, 15),
  institutionId: 'inst-1',
  institutionName: 'Escola Horizonte',
  unitId: 'unit-1',
  unitName: 'Unidade Centro',
  groupId: 'group-1',
  groupName: groupName,
  activityId: activityName == null ? null : 'activity-1',
  activityName: activityName,
  status: status,
  responsible: responsible,
  expected: expected,
  present: present,
  absent: absent,
  late: 1,
  earlyDepartures: 0,
  officialRecords: present + absent,
  canOpen: canOpen,
  routine: routine,
);
