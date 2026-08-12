import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_routine_repository.dart';
import '../domain/routine_contract.dart';

final class RoutineDirectoryViewState {
  const RoutineDirectoryViewState({required this.status, this.page, this.message});

  const RoutineDirectoryViewState.loading()
    : status = RoutineDirectoryStatus.loading,
      page = null,
      message = null;

  final RoutineDirectoryStatus status;
  final RoutineDirectoryPage? page;
  final String? message;
}

final class RoutineDirectoryController extends ChangeNotifier {
  RoutineDirectoryController(this._repository, {RoutineEntryKind kind = RoutineEntryKind.model})
    : _query = RoutineDirectoryQuery(kind: kind);

  final RoutineDirectoryRepository _repository;
  RoutineDirectoryQuery _query;
  RoutineDirectoryViewState _state = const RoutineDirectoryViewState.loading();
  int _requestSerial = 0;

  RoutineDirectoryViewState get state => _state;
  RoutineDirectoryQuery get query => _query;

  Future<void> load({RoutineDirectoryQuery? query}) async {
    if (query != null) _query = query;
    final serial = ++_requestSerial;
    _state = const RoutineDirectoryViewState.loading();
    notifyListeners();
    try {
      final page = await _repository.fetchPage(_query);
      if (serial != _requestSerial) return;
      final status = page.items.isEmpty
          ? (_query.search.trim().isEmpty
                ? RoutineDirectoryStatus.empty
                : RoutineDirectoryStatus.noResults)
          : RoutineDirectoryStatus.data;
      _state = RoutineDirectoryViewState(status: status, page: page);
    } on RoutineNotFoundException {
      if (serial != _requestSerial) return;
      _state = const RoutineDirectoryViewState(status: RoutineDirectoryStatus.notFound);
    } on PostgrestException catch (error) {
      if (serial != _requestSerial) return;
      _state = RoutineDirectoryViewState(
        status: _statusForPostgrest(error),
        message: 'Nao foi possivel carregar a Rotina diaria.',
      );
    } on Exception {
      if (serial != _requestSerial) return;
      _state = const RoutineDirectoryViewState(
        status: RoutineDirectoryStatus.failure,
        message: 'Nao foi possivel carregar a Rotina diaria.',
      );
    }
    notifyListeners();
  }

  void cancelPendingRequests() {
    _requestSerial++;
  }

  @override
  void dispose() {
    cancelPendingRequests();
    super.dispose();
  }
}

RoutineDirectoryStatus _statusForPostgrest(PostgrestException error) => switch (error.code) {
  '42501' => RoutineDirectoryStatus.unauthorized,
  'P0002' => RoutineDirectoryStatus.notFound,
  '40001' || '23505' => RoutineDirectoryStatus.conflict,
  _ => RoutineDirectoryStatus.failure,
};
