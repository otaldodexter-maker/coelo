import 'package:flutter/foundation.dart';

import '../domain/agenda_read_repository.dart';

enum AgendaProjectionStatus { idle, loading, ready, empty, unauthorized, notFound, failure }

/// The composition owner must change [setBoundary]'s opaque key whenever the
/// authenticated session, authorized scope or capability revision changes.
/// The key is only a local invalidation signal, never backend authorization.
final class AgendaReadController extends ChangeNotifier {
  AgendaReadController(this.repository, {required String? boundaryKey})
    : _boundaryKey = boundaryKey,
      _pageStatus = boundaryKey == null
          ? AgendaProjectionStatus.unauthorized
          : AgendaProjectionStatus.idle,
      _detailStatus = boundaryKey == null
          ? AgendaProjectionStatus.unauthorized
          : AgendaProjectionStatus.idle;
  final AgendaReadRepository repository;
  String? _boundaryKey;
  int _boundaryEpoch = 0, _pageEpoch = 0, _detailEpoch = 0;
  bool _disposed = false, _denied = false;
  AgendaReadPage? _page;
  AgendaReadContexts? _contexts;
  AgendaReadDetail? _detail;
  AgendaProjectionStatus _pageStatus, _detailStatus;
  _Query? _query;
  String? _detailId;
  AgendaReadPage? get page => _page;
  AgendaReadContexts? get contexts => _contexts;
  AgendaReadDetail? get detail => _detail;
  AgendaProjectionStatus get pageStatus => _pageStatus;
  AgendaProjectionStatus get detailStatus => _detailStatus;
  bool get _canRead => !_disposed && _boundaryKey != null && !_denied;

  Future<void> loadPage({
    required DateTime from,
    required DateTime to,
    String? institutionId,
    String search = '',
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_canRead) return;
    final boundary = _boundaryEpoch;
    final request = ++_pageEpoch;
    _detailEpoch++;
    _detail = null;
    _detailId = null;
    _detailStatus = AgendaProjectionStatus.idle;
    _query = _Query(from, to, institutionId, search, limit, offset);
    _page = null;
    _contexts = null;
    _pageStatus = AgendaProjectionStatus.loading;
    notifyListeners();
    if (!_current(boundary) || request != _pageEpoch) return;
    try {
      // Both results form one visible snapshot. eagerError ensures a denial is
      // not delayed by a sibling request that never completes.
      final results = await Future.wait<Object>([
        _pagePart(
          () => repository.fetchEvents(
            from: from,
            to: to,
            institutionId: institutionId,
            search: search,
            limit: limit,
            offset: offset,
          ),
          boundary,
          request,
        ),
        _pagePart(repository.fetchContexts, boundary, request),
      ], eagerError: true);
      if (!_current(boundary) || request != _pageEpoch) return;
      _page = results[0] as AgendaReadPage;
      _contexts = results[1] as AgendaReadContexts;
      _pageStatus = _page!.items.isEmpty
          ? AgendaProjectionStatus.empty
          : AgendaProjectionStatus.ready;
      notifyListeners();
    } catch (error) {
      if (!_current(boundary) || request != _pageEpoch) return;
      if (_isDenied(error)) {
        _deny();
        return;
      }
      _pageStatus = AgendaProjectionStatus.failure;
      notifyListeners();
    }
  }

  Future<T> _pagePart<T>(Future<T> Function() read, int boundary, int request) async {
    if (!_current(boundary) || request != _pageEpoch) {
      throw const AgendaReadException(AgendaReadFailure.unavailable);
    }
    try {
      return await read();
    } catch (error) {
      // Future.wait may already have reported a transient sibling failure.
      // Observe each denial independently so it still invalidates the boundary.
      if (_current(boundary) && request == _pageEpoch && _isDenied(error)) {
        _deny();
      }
      rethrow;
    }
  }

  Future<void> openDetail(String id) async {
    if (!_canRead) return;
    final boundary = _boundaryEpoch;
    final request = ++_detailEpoch;
    _detailId = id;
    _detail = null;
    _detailStatus = AgendaProjectionStatus.loading;
    notifyListeners();
    if (!_current(boundary) || request != _detailEpoch) return;
    try {
      final result = await repository.fetchEvent(id);
      if (!_current(boundary) || request != _detailEpoch) return;
      if (result.item.id.toLowerCase() != id.toLowerCase()) {
        throw const AgendaReadException(AgendaReadFailure.unavailable);
      }
      _detail = result;
      _detailStatus = AgendaProjectionStatus.ready;
      notifyListeners();
    } catch (error) {
      if (!_current(boundary) || request != _detailEpoch) return;
      if (_isDenied(error)) {
        _deny();
        return;
      }
      _detailStatus = error is AgendaReadException && error.failure == AgendaReadFailure.notFound
          ? AgendaProjectionStatus.notFound
          : AgendaProjectionStatus.failure;
      notifyListeners();
    }
  }

  void closeDetail() {
    if (_disposed) return;
    _detailEpoch++;
    _detailId = null;
    _detail = null;
    _detailStatus = _canRead ? AgendaProjectionStatus.idle : AgendaProjectionStatus.unauthorized;
    notifyListeners();
  }

  void setBoundary(String? boundaryKey) {
    if (_disposed || boundaryKey == _boundaryKey) return;
    _boundaryKey = boundaryKey;
    _denied = false;
    _reset();
    _pageStatus = _detailStatus = boundaryKey == null
        ? AgendaProjectionStatus.unauthorized
        : AgendaProjectionStatus.idle;
    notifyListeners();
  }

  Future<void> retryPage() async {
    final query = _query;
    if (!_canRead || query == null) return;
    await loadPage(
      from: query.from,
      to: query.to,
      institutionId: query.institutionId,
      search: query.search,
      limit: query.limit,
      offset: query.offset,
    );
  }

  Future<void> retryDetail() async {
    final id = _detailId;
    if (_canRead && id != null) await openDetail(id);
  }

  bool _current(int boundary) => _canRead && boundary == _boundaryEpoch;
  bool _isDenied(Object error) =>
      error is AgendaReadException && error.failure == AgendaReadFailure.unauthorized;
  void _deny() {
    _denied = true;
    _reset();
    _pageStatus = _detailStatus = AgendaProjectionStatus.unauthorized;
    notifyListeners();
  }

  void _reset() {
    _boundaryEpoch++;
    _pageEpoch++;
    _detailEpoch++;
    _page = null;
    _contexts = null;
    _detail = null;
    _query = null;
    _detailId = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _reset();
    super.dispose();
  }
}

final class _Query {
  const _Query(this.from, this.to, this.institutionId, this.search, this.limit, this.offset);
  final DateTime from, to;
  final String? institutionId;
  final String search;
  final int limit, offset;
}
