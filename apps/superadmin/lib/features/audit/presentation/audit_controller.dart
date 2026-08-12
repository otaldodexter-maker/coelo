import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/audit.dart';

enum AuditLoadState { loading, content, empty, noResults, failure, unauthorized, notFound }

final class AuditDirectorySnapshot {
  AuditDirectorySnapshot({
    required this.state,
    required List<AuditEvent> events,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.hasPrevious,
    required this.hasNext,
    required this.canExport,
  }) : events = List.unmodifiable(events);

  const AuditDirectorySnapshot.loading({required this.pageSize})
    : state = AuditLoadState.loading,
      events = const [],
      pageNumber = 1,
      totalCount = 0,
      hasPrevious = false,
      hasNext = false,
      canExport = false;

  final AuditLoadState state;
  final List<AuditEvent> events;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final bool hasPrevious;
  final bool hasNext;
  final bool canExport;

  int get totalPages => totalCount == 0 ? 1 : (totalCount + pageSize - 1) ~/ pageSize;
}

enum AuditDetailLoadState { idle, loading, content, failure, unauthorized, notFound }

final class AuditDetailSnapshot {
  const AuditDetailSnapshot(this.state, {this.value});

  final AuditDetailLoadState state;
  final AuditEventDetail? value;
}

final class AuditDirectoryController extends ChangeNotifier {
  AuditDirectoryController({
    required AuditRepository repository,
    AuditQuery? query,
    String Function()? createIdempotencyKey,
  }) : _createIdempotencyKey = createIdempotencyKey ?? _uuidV4,
       _repository = repository,
       _query = (query ?? AuditQuery()).withoutCursor(),
       _snapshot = AuditDirectorySnapshot.loading(pageSize: query?.pageSize ?? 25);

  final AuditRepository _repository;
  final String Function() _createIdempotencyKey;
  AuditQuery _query;
  AuditDirectorySnapshot _snapshot;
  AuditDetailSnapshot _detail = const AuditDetailSnapshot(AuditDetailLoadState.idle);
  List<AuditCursor?> _pageCursors = const [null];
  var _pageIndex = 0;
  var _isExporting = false;
  Object? _exportError;
  String? _exportIdempotencyKey;
  AuditExportFormat? _exportFormat;
  Timer? _searchDebounce;
  Completer<void>? _searchCompleter;
  var _pageGeneration = 0;
  var _detailGeneration = 0;
  var _disposed = false;

  AuditQuery get query => _query;
  AuditDirectorySnapshot get snapshot => _snapshot;
  AuditDetailSnapshot get detail => _detail;
  bool get isExporting => _isExporting;
  bool get canExport =>
      _snapshot.state == AuditLoadState.content && _snapshot.canExport && !_isExporting;
  Object? get exportError => _exportError;

  Future<void> load() => _loadPage();

  Future<void> retry() => _loadPage();

  Future<void> updateSearch(String value) {
    _pageGeneration += 1;
    _resetExportAttempt();
    _searchDebounce?.cancel();
    _searchCompleter?.complete();
    final completer = Completer<void>();
    _searchCompleter = completer;
    _query = _query.withSearch(value);
    _resetDetail();
    _pageCursors = const [null];
    _pageIndex = 0;
    _notify();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _loadPage();
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> updateFilters(AuditQuery value) async {
    _cancelSearchDebounce();
    _resetExportAttempt();
    _query = value.withoutCursor();
    _pageCursors = const [null];
    _pageIndex = 0;
    await _loadPage();
  }

  Future<void> next() async {
    if (!_snapshot.hasNext) return;
    final cursor = _currentPage?.nextCursor;
    if (cursor == null) return;
    _pageCursors = [..._pageCursors.take(_pageIndex + 1), cursor];
    _pageIndex += 1;
    await _loadPage();
  }

  Future<void> previous() async {
    if (_pageIndex == 0) return;
    _pageIndex -= 1;
    await _loadPage();
  }

  Future<void> loadDetail(String eventId) async {
    final generation = ++_detailGeneration;
    _detail = const AuditDetailSnapshot(AuditDetailLoadState.loading);
    _notify();
    try {
      final value = await _repository.fetchDetail(eventId);
      if (generation != _detailGeneration) return;
      _detail = AuditDetailSnapshot(AuditDetailLoadState.content, value: value);
    } on AuditUnauthorizedException {
      if (generation != _detailGeneration) return;
      _detail = const AuditDetailSnapshot(AuditDetailLoadState.unauthorized);
    } on AuditNotFoundException {
      if (generation != _detailGeneration) return;
      _detail = const AuditDetailSnapshot(AuditDetailLoadState.notFound);
    } on Exception {
      if (generation != _detailGeneration) return;
      _detail = const AuditDetailSnapshot(AuditDetailLoadState.failure);
    }
    _notify();
  }

  void closeDetail() {
    _detailGeneration += 1;
    _detail = const AuditDetailSnapshot(AuditDetailLoadState.idle);
    _notify();
  }

  Future<AuditExportJob> startExport({required AuditExportFormat format}) async {
    _isExporting = true;
    _exportError = null;
    if (_exportFormat != format) _resetExportAttempt();
    _exportFormat = format;
    final idempotencyKey = _exportIdempotencyKey ??= _createIdempotencyKey();
    _notify();
    try {
      return await _repository
          .startExport(
            AuditExportRequest(
              idempotencyKey: idempotencyKey,
              format: format,
              query: _query.withoutCursor(),
            ),
          )
          .then((job) {
            if (job.status == AuditExportStatus.completed) _resetExportAttempt();
            return job;
          });
    } on Exception catch (error) {
      _exportError = error;
      rethrow;
    } finally {
      _isExporting = false;
      _notify();
    }
  }

  Future<AuditExportJob> fetchExportStatus(String jobId) => _repository.fetchExportStatus(jobId);

  AuditPage? _currentPage;

  Future<void> _loadPage() async {
    final generation = ++_pageGeneration;
    _resetDetail();
    _snapshot = AuditDirectorySnapshot.loading(pageSize: _query.pageSize);
    _notify();
    try {
      final page = await _repository.fetchPage(_query.withCursor(_pageCursors[_pageIndex]));
      if (generation != _pageGeneration) return;
      _currentPage = page;
      final state = page.events.isNotEmpty
          ? AuditLoadState.content
          : _query.hasActiveFilters
          ? AuditLoadState.noResults
          : AuditLoadState.empty;
      _snapshot = AuditDirectorySnapshot(
        state: state,
        events: page.events,
        pageNumber: _pageIndex + 1,
        pageSize: _query.pageSize,
        totalCount: page.totalCount,
        hasPrevious: _pageIndex > 0,
        hasNext: page.hasMore,
        canExport: page.canExport,
      );
    } on AuditUnauthorizedException {
      if (generation != _pageGeneration) return;
      _snapshot = _errorSnapshot(AuditLoadState.unauthorized);
    } on AuditNotFoundException {
      if (generation != _pageGeneration) return;
      _snapshot = _errorSnapshot(AuditLoadState.notFound);
    } on Exception {
      if (generation != _pageGeneration) return;
      _snapshot = _errorSnapshot(AuditLoadState.failure);
    }
    _notify();
  }

  AuditDirectorySnapshot _errorSnapshot(AuditLoadState state) => AuditDirectorySnapshot(
    state: state,
    events: const [],
    pageNumber: _pageIndex + 1,
    pageSize: _query.pageSize,
    totalCount: 0,
    hasPrevious: _pageIndex > 0,
    hasNext: false,
    canExport: false,
  );

  void _cancelSearchDebounce() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final completer = _searchCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _searchCompleter = null;
  }

  void _resetExportAttempt() {
    _exportIdempotencyKey = null;
    _exportFormat = null;
  }

  @override
  void dispose() {
    _cancelSearchDebounce();
    _pageGeneration += 1;
    _detailGeneration += 1;
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _resetDetail() {
    if (_detail.state == AuditDetailLoadState.idle) return;
    _detailGeneration += 1;
    _detail = const AuditDetailSnapshot(AuditDetailLoadState.idle);
  }
}

String _uuidV4() {
  final random = math.Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
