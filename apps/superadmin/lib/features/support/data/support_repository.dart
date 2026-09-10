import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/support_ticket.dart';

abstract interface class SupportRepository {
  Future<SupportTicketPage> list(SupportFilters filters, {int page = 1, int pageSize = 25});
  Future<SupportTicket> get(String ticketId);
  Future<SupportTicket> create(SupportReportDraft draft);
  Future<SupportTicket> reply(String ticketId, String message, int expectedRevision);
  Future<SupportTicket> setStatus(
    String ticketId,
    SupportTicketStatus status,
    int expectedRevision,
  );
}

final class SupabaseSupportRepository implements SupportRepository {
  const SupabaseSupportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SupportTicketPage> list(SupportFilters filters, {int page = 1, int pageSize = 25}) async {
    final raw = await _rpc('superadmin_support_list', {
      'p_search': filters.search.trim(),
      'p_statuses': filters.statuses.isEmpty ? null : filters.statuses.map(_status).toList(),
      'p_menus': filters.menus.isEmpty ? null : filters.menus.toList(),
      'p_screens': filters.screens.isEmpty ? null : filters.screens.toList(),
      'p_assignee_ids': filters.assigneeIds.isEmpty ? null : filters.assigneeIds.toList(),
      'p_unread_only': filters.unreadOnly,
      'p_page': page,
      'p_page_size': pageSize,
    });
    final json = _map(raw);
    return SupportTicketPage(
      tickets: _list(json['items']).map(_summary).toList(growable: false),
      totalItems: _int(json, 'total_items'),
      page: _int(json, 'page'),
      pageSize: _int(json, 'page_size'),
    );
  }

  @override
  Future<SupportTicket> get(String ticketId) async =>
      _ticket(_map(await _rpc('superadmin_support_get', {'p_session_id': ticketId})));

  @override
  Future<SupportTicket> create(SupportReportDraft draft) async => _ticket(
    _map(
      await _rpc('superadmin_support_create', {
        'p_request_id': _uuidV4(),
        'p_institution_id': null,
        'p_unit_id': null,
        'p_subject': draft.subject.trim(),
        'p_menu': draft.menu.trim(),
        'p_screen': draft.screen.trim(),
        'p_reported_issue': draft.description.trim(),
        'p_requester_label': draft.requester.trim(),
        'p_priority': 'normal',
      }),
    ),
  );

  @override
  Future<SupportTicket> reply(String ticketId, String message, int expectedRevision) async =>
      _ticket(
        _map(
          await _rpc('superadmin_support_reply', {
            'p_request_id': _uuidV4(),
            'p_session_id': ticketId,
            'p_message': message.trim(),
            'p_expected_revision': expectedRevision,
          }),
        ),
      );

  @override
  Future<SupportTicket> setStatus(
    String ticketId,
    SupportTicketStatus status,
    int expectedRevision,
  ) async => _ticket(
    _map(
      await _rpc('superadmin_support_set_status', {
        'p_request_id': _uuidV4(),
        'p_session_id': ticketId,
        'p_status': _status(status),
        'p_expected_revision': expectedRevision,
      }),
    ),
  );

  Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      throw SupportRepositoryException(error.message);
    } on Exception {
      throw const SupportRepositoryException('Não foi possível concluir a operação.');
    }
  }

  SupportTicket _summary(Object? raw) {
    final json = _map(raw);
    final now = _date(json, 'updated_at');
    return SupportTicket(
      id: _string(json, 'id'),
      subject: _string(json, 'subject'),
      menu: _string(json, 'menu'),
      screen: _string(json, 'screen'),
      description: _string(json, 'description'),
      requester: _string(json, 'requester'),
      createdAt: _date(json, 'created_at'),
      updatedAt: now,
      status: _ticketStatus(_string(json, 'status')),
      revision: _int(json, 'revision'),
      ownerId: json['assignee_membership_id']?.toString(),
      messages: json['unread'] == true
          ? [
              SupportMessage(
                id: 'unread-summary',
                author: SupportMessageAuthor.requester,
                text: 'Mensagem não lida',
                sentAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
            ]
          : const [],
    );
  }

  SupportTicket _ticket(Map<String, Object?> json) => SupportTicket(
    id: _string(json, 'id'),
    subject: _string(json, 'subject'),
    menu: _string(json, 'menu'),
    screen: _string(json, 'screen'),
    description: _string(json, 'description'),
    requester: _string(json, 'requester'),
    createdAt: _date(json, 'created_at'),
    updatedAt: _date(json, 'updated_at'),
    status: _ticketStatus(_string(json, 'status')),
    revision: _int(json, 'revision'),
    messages: _list(json['messages']).map(_message).toList(growable: false),
    activities: _list(json['activities']).map(_activity).toList(growable: false),
  );

  SupportMessage _message(Object? raw) {
    final json = _map(raw);
    return SupportMessage(
      id: _string(json, 'id'),
      author: _string(json, 'author') == 'requester'
          ? SupportMessageAuthor.requester
          : SupportMessageAuthor.support,
      text: _string(json, 'text'),
      sentAt: _date(json, 'created_at'),
      isReadBySupport: json['read'] == true,
    );
  }

  SupportActivity _activity(Object? raw) {
    final json = _map(raw);
    return SupportActivity(
      kind: switch (_string(json, 'action')) {
        'support.reply' => SupportActivityKind.replySent,
        'support.status' => SupportActivityKind.statusChanged,
        _ => SupportActivityKind.created,
      },
      label: _string(json, 'action'),
      occurredAt: _date(json, 'occurred_at'),
    );
  }
}

final class SupportTicketPage {
  const SupportTicketPage({
    required this.tickets,
    required this.totalItems,
    required this.page,
    required this.pageSize,
  });

  final List<SupportTicket> tickets;
  final int totalItems;
  final int page;
  final int pageSize;
}

final class SupportRepositoryException implements Exception {
  const SupportRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw const SupportRepositoryException('Resposta de suporte inválida.');
}

List<Object?> _list(Object? value) => value is List ? List<Object?>.from(value) : const [];

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw const SupportRepositoryException('Resposta de suporte inválida.');
}

int _int(Map<String, Object?> json, String key) => int.tryParse(json[key]?.toString() ?? '') ?? 0;

DateTime _date(Map<String, Object?> json, String key) =>
    DateTime.tryParse(_string(json, key)) ?? DateTime.fromMillisecondsSinceEpoch(0);

String _status(SupportTicketStatus status) => switch (status) {
  SupportTicketStatus.newRequest => 'new',
  SupportTicketStatus.inProgress => 'in_progress',
  SupportTicketStatus.waitingRequester => 'waiting_requester',
  SupportTicketStatus.completed => 'completed',
};

SupportTicketStatus _ticketStatus(String status) => switch (status) {
  'in_progress' => SupportTicketStatus.inProgress,
  'waiting_requester' => SupportTicketStatus.waitingRequester,
  'completed' => SupportTicketStatus.completed,
  _ => SupportTicketStatus.newRequest,
};

String _uuidV4() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
