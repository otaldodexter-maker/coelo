import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../activity/superadmin_activity.dart';

enum PrototypeAuditRisk { low, medium, high }

@immutable
final class PrototypeAuditEvent {
  PrototypeAuditEvent({
    required this.id,
    required this.occurredAt,
    required this.actor,
    required this.module,
    required this.action,
    required this.objectType,
    required this.objectId,
    required this.scope,
    required this.reason,
    required this.origin,
    required this.mfa,
    required this.risk,
    required Map<String, String> before,
    required Map<String, String> after,
    this.context,
    this.relatedReference,
  }) : before = Map.unmodifiable(before),
       after = Map.unmodifiable(after);

  final String id;
  final DateTime occurredAt;
  final String actor;
  final String module;
  final String action;
  final String objectType;
  final String objectId;
  final String scope;
  final String reason;
  final String origin;
  final bool mfa;
  final PrototypeAuditRisk risk;
  final Map<String, String> before;
  final Map<String, String> after;
  final String? context;
  final String? relatedReference;

  String get searchableText => [
    id,
    actor,
    module,
    action,
    objectType,
    objectId,
    scope,
    reason,
    origin,
    ?context,
    ?relatedReference,
    ...before.keys,
    ...before.values,
    ...after.keys,
    ...after.values,
  ].join(' ').toLowerCase();
}

final class SuperadminPrototypeStore extends ChangeNotifier {
  SuperadminPrototypeStore({required this.activityController, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SuperadminActivityController activityController;
  final DateTime Function() _now;
  final List<PrototypeAuditEvent> _auditEvents = [];
  var _nextActivityId = 1;
  var _nextAuditId = 1;

  UnmodifiableListView<PrototypeAuditEvent> get auditEvents => UnmodifiableListView(_auditEvents);

  String recordActivity({
    required SuperadminActivityKind kind,
    required String subject,
    required String summary,
    SuperadminActivityStatus status = SuperadminActivityStatus.succeeded,
    String? fileName,
    int? progress,
  }) {
    final id = 'prototype-activity-${_nextActivityId++}';
    activityController.addActivity(
      SuperadminActivity(
        id: id,
        kind: kind,
        status: status,
        subject: subject,
        summary: summary,
        createdAt: _now(),
        fileName: fileName,
        progress: progress,
      ),
    );
    return id;
  }

  PrototypeAuditEvent recordAuditEvent({
    required String module,
    required String action,
    required String objectType,
    required String objectId,
    String actor = 'Operadora Coelo',
    String scope = 'Superadmin',
    String reason = 'Ação operacional simulada',
    String origin = 'Preview local',
    bool mfa = true,
    PrototypeAuditRisk risk = PrototypeAuditRisk.medium,
    Map<String, String> before = const {},
    Map<String, String> after = const {},
    String? context,
    String? relatedReference,
  }) {
    final event = PrototypeAuditEvent(
      id: 'audit-${_nextAuditId++}',
      occurredAt: _now(),
      actor: _sanitize(actor),
      module: _sanitize(module),
      action: _sanitize(action),
      objectType: _sanitize(objectType),
      objectId: _sanitize(objectId),
      scope: _sanitize(scope),
      reason: _sanitize(reason),
      origin: _sanitize(origin),
      mfa: mfa,
      risk: risk,
      before: _minimized(before),
      after: _minimized(after),
      context: context == null ? null : _sanitize(context),
      relatedReference: relatedReference == null ? null : _sanitize(relatedReference),
    );
    _auditEvents
      ..add(event)
      ..sort((left, right) {
        final byTime = right.occurredAt.compareTo(left.occurredAt);
        return byTime != 0 ? byTime : right.id.compareTo(left.id);
      });
    notifyListeners();
    return event;
  }
}

const _safeChangeKeys = {
  'status',
  'name',
  'code',
  'strategy',
  'result',
  'progress',
  'expiresAt',
  'priority',
  'audience',
  'behavior',
  'module',
};

Map<String, String> _minimized(Map<String, String> source) => Map.unmodifiable({
  for (final entry in source.entries)
    if (_safeChangeKeys.contains(entry.key) && !_isSensitive(entry.value))
      entry.key: _sanitize(entry.value),
});

String _sanitize(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_isSensitive(compact)) return '[minimizado]';
  return compact.length <= 120 ? compact : '${compact.substring(0, 117)}...';
}

bool _isSensitive(String value) {
  final lower = value.toLowerCase();
  return RegExp(
        r'https?://|\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b',
        caseSensitive: false,
      ).hasMatch(value) ||
      RegExp(r'\b\d{10,}\b').hasMatch(value) ||
      lower.contains('token=') ||
      lower.contains('bearer ');
}
