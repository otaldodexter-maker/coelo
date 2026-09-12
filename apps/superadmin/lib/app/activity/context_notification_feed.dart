import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'superadmin_activity.dart';

/// Uma notificação do sino vinda de `context_notification_events` +
/// `context_notification_recipients` (lote 36 e cadeias que inserem lá).
@immutable
final class ContextNotification {
  const ContextNotification({
    required this.eventId,
    required this.eventCode,
    required this.objectType,
    required this.createdAt,
    required this.payload,
    required this.readAt,
  });

  final String eventId;
  final String eventCode;
  final String objectType;
  final DateTime createdAt;
  final Map<String, Object?> payload;
  final DateTime? readAt;
}

/// Leitura e marcação das notificações do ator atual. O servidor decide o que
/// ele vê (policies `context_notification_recipients_own_read` e
/// `context_notification_events_recipient_read`) e o que ele marca
/// (`context_notification_recipients_own_update`, grant só em `read_at`).
abstract interface class ContextNotificationRepository {
  Future<List<ContextNotification>> listMine({int limit = 30});

  Future<void> markRead(Iterable<String> eventIds);
}

final class SupabaseContextNotificationRepository implements ContextNotificationRepository {
  const SupabaseContextNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ContextNotification>> listMine({int limit = 30}) async {
    final rows = await _client
        .from('context_notification_recipients')
        .select(
          'event_id, read_at, created_at, '
          'event:context_notification_events(event_code, object_type, payload_json, deliver_at)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows)
        if (row['event'] case final Map<String, Object?> event)
          ContextNotification(
            eventId: row['event_id'] as String,
            eventCode: event['event_code'] as String? ?? '',
            objectType: event['object_type'] as String? ?? '',
            createdAt:
                DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
            payload: switch (event['payload_json']) {
              final Map<String, Object?> payload => payload,
              _ => const {},
            },
            readAt: DateTime.tryParse(row['read_at'] as String? ?? ''),
          ),
    ];
  }

  @override
  Future<void> markRead(Iterable<String> eventIds) async {
    final ids = eventIds.toList(growable: false);
    if (ids.isEmpty) return;
    // `where` sempre presente (pg_safeupdate); a policy restringe ao proprio
    // destinatario, entao ids alheios simplesmente nao mudam.
    await _client
        .from('context_notification_recipients')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('event_id', ids)
        .isFilter('read_at', null);
  }
}

/// Liga o repositório ao sino do shell: carrega as notificações como
/// atividades do tipo anúncio e, quando o centro é aberto (o controlador marca
/// tudo como lido), grava `read_at` no servidor para as que ainda não tinham.
final class ContextNotificationFeed {
  ContextNotificationFeed({required this.repository, required this.controller});

  static const idPrefix = 'ctx-';

  final ContextNotificationRepository repository;
  final SuperadminActivityController controller;
  final _unreadOnServer = <String>{};

  Future<void> load() async {
    controller.onCenterOpened = _syncRead;
    final List<ContextNotification> items;
    try {
      items = await repository.listMine();
    } on Object {
      // Sem notificações remotas o sino continua funcionando com o resto.
      return;
    }
    _unreadOnServer
      ..clear()
      ..addAll(items.where((item) => item.readAt == null).map((item) => item.eventId));
    controller.addActivities([
      for (final item in items)
        SuperadminActivity.announcement(
          id: '$idPrefix${item.eventId}',
          subject: subjectFor(item),
          summary: summaryFor(item),
          createdAt: item.createdAt,
          isRead: item.readAt != null,
        ),
    ]);
    if (controller.isCenterOpen) {
      controller.setCenterOpen(true);
      await _syncRead();
    }
  }

  Future<void> _syncRead() async {
    if (_unreadOnServer.isEmpty) return;
    final ids = _unreadOnServer.toList(growable: false);
    _unreadOnServer.clear();
    try {
      await repository.markRead(ids);
    } on Object {
      _unreadOnServer.addAll(ids);
    }
  }

  /// Rótulos honestos por código de evento; códigos desconhecidos mostram o
  /// próprio código em vez de inventar texto.
  @visibleForTesting
  static String subjectFor(ContextNotification item) => switch (item.eventCode) {
    'child_safety.authorization' => 'Segurança infantil · autorização',
    'child_safety.restriction' => 'Segurança infantil · restrição',
    'medication.plan' => 'Medicação · plano',
    'attendance.absence' => 'Assiduidade · falta',
    _ => item.eventCode.replaceAll('_', ' ').replaceAll('.', ' · '),
  };

  @visibleForTesting
  static String summaryFor(ContextNotification item) {
    final title = item.payload['title'] ?? item.payload['summary'] ?? item.payload['message'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
    return item.objectType.replaceAll('_', ' ');
  }
}
