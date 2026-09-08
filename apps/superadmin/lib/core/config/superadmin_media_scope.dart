import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:flutter/foundation.dart';

import '../../features/forms/data/form_export_download_resolver.dart';
import '../guards/superadmin_session.dart';

/// Stable composition holder; its private capabilities belong to one authorized
/// revision. Preparation drains the previous lifetime before Auth commits the
/// next context. Neither preparation nor a pending refresh can publish early.
final class SuperadminMediaScope extends ChangeNotifier {
  SuperadminMediaScope({
    required SuperadminSession session,
    required FormExportDownloadGateway downloadGateway,
  }) : _session = session,
       _downloadGateway = downloadGateway,
       _observedRevision = session.authorizationInvalidationRevision {
    session.addListener(_sessionChanged);
    _queuePublication();
  }

  final SuperadminSession _session;
  final FormExportDownloadGateway _downloadGateway;
  MediaSession? _current;
  FormExportDownloadResolver? _downloadResolver;
  int? _currentRevision;
  int _observedRevision;
  int _generation = 0;
  int _preparations = 0;
  bool _awaitingCommit = false;
  bool _disposed = false;
  // False is sticky: a failed purge cannot be bypassed by a later transition.
  Future<bool> _drained = Future<bool>.value(true);

  MediaSession? get current =>
      !_disposed &&
          _session.isAuthenticated &&
          _currentRevision == _session.authorizationInvalidationRevision &&
          _current?.isInvalidated == false
      ? _current
      : null;

  FormExportDownloadResolver? get downloadResolver => current == null ? null : _downloadResolver;
  int get generation => _generation;

  Future<bool> prepareAuthorization() async {
    if (_disposed) return false;
    _awaitingCommit = true;
    _preparations++;
    _retire();
    final generation = _generation;
    final revision = _session.authorizationInvalidationRevision;
    try {
      final succeeded = await _drained;
      return succeeded &&
          !_disposed &&
          generation == _generation &&
          revision == _session.authorizationInvalidationRevision;
    } finally {
      _preparations--;
      _queuePublication();
    }
  }

  /// Call only after authorizeIfCurrent succeeds, including identical context
  /// authorizations which deliberately do not notify SuperadminSession.
  void authorizationCommitted() {
    if (_disposed || !_session.isAuthenticated) return;
    _awaitingCommit = false;
    _queuePublication();
  }

  void _sessionChanged() {
    if (_disposed || _observedRevision == _session.authorizationInvalidationRevision) return;
    _observedRevision = _session.authorizationInvalidationRevision;
    if (!_session.isAuthenticated) _awaitingCommit = false;
    _retire();
    _queuePublication();
  }

  void _retire() {
    _generation++;
    final previous = _current;
    _current = null;
    _currentRevision = null;
    _downloadResolver = null;
    // Start every purge immediately, while retaining all earlier completion
    // boundaries. Retiring a null lifetime must not lose an in-flight purge.
    if (previous != null) {
      _drained = Future.wait<bool>([
        _drained,
        _purge(previous),
      ]).then((results) => results.every((succeeded) => succeeded));
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> _purge(MediaSession previous) async {
    try {
      await previous.invalidate();
      return true;
    } catch (_) {
      // Purge callbacks may contain private URLs or bearer capabilities.
      return false;
    }
  }

  void _queuePublication() {
    if (_disposed || _awaitingCommit || _preparations != 0 || !_session.isAuthenticated) return;
    unawaited(_publishAfterPurge(_generation, _session.authorizationInvalidationRevision));
  }

  Future<void> _publishAfterPurge(int generation, int revision) async {
    final succeeded = await _drained;
    if (!succeeded ||
        _disposed ||
        _awaitingCommit ||
        _preparations != 0 ||
        generation != _generation ||
        revision != _session.authorizationInvalidationRevision ||
        !_session.isAuthenticated ||
        _current != null) {
      return;
    }
    final lifetime = MediaSession();
    _current = lifetime;
    _currentRevision = revision;
    _downloadResolver = FormExportDownloadResolver(gateway: _downloadGateway, session: lifetime);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session.removeListener(_sessionChanged);
    _retire();
    super.dispose();
  }
}
