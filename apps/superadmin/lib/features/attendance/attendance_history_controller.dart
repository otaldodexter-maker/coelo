import 'package:flutter/foundation.dart';

import 'attendance.dart';

enum AttendanceHistoryStatus { loading, data, empty, noResults, error, unauthorized, unavailable }

/// Estado do Histórico de chamadas (ADR 0041 B2, spec 052).
///
/// A paginação é por cursor: cada página carregada fica guardada em [pages]
/// e `pageIndex` aponta a página visível, então "Anterior" volta sem refazer
/// a leitura e "Próxima" só pede ao servidor quando ainda não foi carregada.
@immutable
class AttendanceHistoryState {
  const AttendanceHistoryState({
    required this.status,
    required this.query,
    this.pages = const [],
    this.pageIndex = 0,
    this.options,
    this.errorMessage,
  });

  final AttendanceHistoryStatus status;
  final AttendanceHistoryQuery query;
  final List<AttendanceHistoryPageResult> pages;
  final int pageIndex;
  final AttendanceContextOptions? options;
  final String? errorMessage;

  AttendanceHistoryPageResult? get page => pageIndex < pages.length ? pages[pageIndex] : null;
  List<AttendanceHistoryItem> get items => page?.items ?? const [];
  bool get hasPrevious => pageIndex > 0;
  bool get hasNext => page?.hasMore ?? false;

  /// Páginas conhecidas + uma quando o servidor sinaliza que há mais.
  int get totalPages => pages.isEmpty ? 1 : pages.length + (pages.last.hasMore ? 1 : 0);

  bool get hasFilters =>
      query.hasContextFilter || query.status != null;

  AttendanceHistoryState copyWith({
    AttendanceHistoryStatus? status,
    AttendanceHistoryQuery? query,
    List<AttendanceHistoryPageResult>? pages,
    int? pageIndex,
    AttendanceContextOptions? options,
    String? errorMessage,
  }) => AttendanceHistoryState(
    status: status ?? this.status,
    query: query ?? this.query,
    pages: pages ?? this.pages,
    pageIndex: pageIndex ?? this.pageIndex,
    options: options ?? this.options,
    errorMessage: errorMessage,
  );
}

class AttendanceHistoryController extends ChangeNotifier {
  AttendanceHistoryController({
    required AttendanceHistoryRepository repository,
    required DateTime today,
    AttendanceHistoryQuery? initialQuery,
  }) : _repository = repository,
       _today = today,
       _state = AttendanceHistoryState(
         status: AttendanceHistoryStatus.loading,
         query:
             initialQuery ??
             AttendanceHistoryQuery(
               periodStart: today.subtract(const Duration(days: 30)),
               periodEnd: today,
             ),
       );

  final AttendanceHistoryRepository _repository;
  final DateTime _today;
  AttendanceHistoryState _state;
  var _requestId = 0;
  var _disposed = false;

  AttendanceHistoryState get state => _state;
  DateTime get today => _today;

  Future<void> load() async {
    final requestId = ++_requestId;
    _emit(_state.copyWith(status: AttendanceHistoryStatus.loading, pages: const [], pageIndex: 0));
    final query = _state.query.copyWith(cursor: null);
    try {
      final options = _state.options ?? await _repository.fetchContextOptions(date: _today);
      final page = await _repository.fetchHistory(query);
      if (requestId != _requestId || _disposed) return;
      _emit(
        AttendanceHistoryState(
          status: page.items.isEmpty
              ? (_state.hasFilters
                    ? AttendanceHistoryStatus.noResults
                    : AttendanceHistoryStatus.empty)
              : AttendanceHistoryStatus.data,
          query: query,
          pages: [page],
          pageIndex: 0,
          options: options,
        ),
      );
    } on AttendanceUnauthorizedException {
      if (requestId != _requestId || _disposed) return;
      _emit(_state.copyWith(status: AttendanceHistoryStatus.unauthorized, query: query));
    } on AttendanceUnavailableException {
      if (requestId != _requestId || _disposed) return;
      _emit(_state.copyWith(status: AttendanceHistoryStatus.unavailable, query: query));
    } catch (error) {
      if (requestId != _requestId || _disposed) return;
      _emit(
        _state.copyWith(
          status: AttendanceHistoryStatus.error,
          query: query,
          errorMessage: 'Não foi possível carregar o histórico de chamadas.',
        ),
      );
    }
  }

  Future<void> nextPage() async {
    final current = _state.page;
    if (current == null || !current.hasMore) return;
    if (_state.pageIndex + 1 < _state.pages.length) {
      _emit(_state.copyWith(pageIndex: _state.pageIndex + 1));
      return;
    }
    final requestId = ++_requestId;
    final query = _state.query.copyWith(cursor: current.nextCursor);
    try {
      final page = await _repository.fetchHistory(query);
      if (requestId != _requestId || _disposed) return;
      _emit(
        _state.copyWith(
          status: AttendanceHistoryStatus.data,
          pages: [..._state.pages, page],
          pageIndex: _state.pages.length,
        ),
      );
    } on AttendanceUnauthorizedException {
      if (requestId != _requestId || _disposed) return;
      _emit(_state.copyWith(status: AttendanceHistoryStatus.unauthorized));
    } catch (_) {
      if (requestId != _requestId || _disposed) return;
      _emit(
        _state.copyWith(
          status: AttendanceHistoryStatus.error,
          errorMessage: 'Não foi possível carregar a próxima página.',
        ),
      );
    }
  }

  void previousPage() {
    if (!_state.hasPrevious) return;
    _emit(_state.copyWith(pageIndex: _state.pageIndex - 1));
  }

  void goToPage(int page) {
    final index = page - 1;
    if (index == _state.pageIndex) return;
    if (index < 0) return;
    if (index < _state.pages.length) {
      _emit(_state.copyWith(pageIndex: index));
      return;
    }
    if (index == _state.pages.length) nextPage();
  }

  Future<void> changePeriod(DateTime start, DateTime end) =>
      _applyQuery(_state.query.copyWith(periodStart: start, periodEnd: end));

  /// Instituição escolhida limpa unidade/turma/atividade que não pertencem a ela.
  Future<void> changeInstitution(String? institutionId) => _applyQuery(
    _state.query.copyWith(
      institutionId: institutionId,
      unitId: null,
      groupId: null,
      activityId: null,
    ),
  );

  Future<void> changeUnit(String? unitId) =>
      _applyQuery(_state.query.copyWith(unitId: unitId, groupId: null, activityId: null));

  Future<void> changeGroup(String? groupId) =>
      _applyQuery(_state.query.copyWith(groupId: groupId, activityId: null));

  Future<void> changeActivity(String? activityId) =>
      _applyQuery(_state.query.copyWith(activityId: activityId));

  Future<void> changeStatus(AttendanceHistoryStatusFilter? status) =>
      _applyQuery(_state.query.copyWith(status: status));

  Future<void> clearFilters() => _applyQuery(
    AttendanceHistoryQuery(
      periodStart: _today.subtract(const Duration(days: 30)),
      periodEnd: _today,
      pageSize: _state.query.pageSize,
    ),
  );

  Future<void> _applyQuery(AttendanceHistoryQuery query) {
    _state = _state.copyWith(query: query);
    return load();
  }

  void _emit(AttendanceHistoryState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
