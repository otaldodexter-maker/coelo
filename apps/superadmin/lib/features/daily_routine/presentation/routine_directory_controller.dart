import 'package:flutter/foundation.dart';

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
    } on RoutineRepositoryException catch (error) {
      if (serial != _requestSerial) return;
      _state = RoutineDirectoryViewState(
        status: _statusForRepositoryFailure(error.kind),
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

RoutineDirectoryStatus _statusForRepositoryFailure(RoutineRepositoryFailureKind kind) =>
    switch (kind) {
      RoutineRepositoryFailureKind.unauthorized => RoutineDirectoryStatus.unauthorized,
      RoutineRepositoryFailureKind.notFound => RoutineDirectoryStatus.notFound,
      RoutineRepositoryFailureKind.conflict => RoutineDirectoryStatus.conflict,
      RoutineRepositoryFailureKind.unavailable => RoutineDirectoryStatus.failure,
    };
