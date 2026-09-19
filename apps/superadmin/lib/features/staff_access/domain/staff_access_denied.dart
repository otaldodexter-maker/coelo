import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Negação com motivo (lote 91): o servidor levanta `PT403` /
/// `STAFF_ACCESS_DENIED` com `details` JSON quando todo vínculo de equipe do
/// ator na instituição está bloqueado agora. O cliente só reflete.
final class StaffAccessDenial {
  const StaffAccessDenial({
    required this.membershipId,
    required this.institutionId,
    required this.reason,
    required this.popup,
  });

  final String? membershipId;
  final String? institutionId;
  final String? reason;

  /// Mesmo formato de `access_popup` de `list_my_principal_contexts`.
  final Map<String, dynamic>? popup;

  /// Reconhece o corpo de erro do PostgREST
  /// (`{"code":"PT403","message":"STAFF_ACCESS_DENIED","details":"{...}"}`).
  static StaffAccessDenial? fromPostgrestBody(String body) {
    if (!body.contains('STAFF_ACCESS_DENIED')) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final details = decoded['details'];
      final detail = details is String
          ? jsonDecode(details)
          : details is Map
          ? details
          : null;
      if (detail is! Map) return const StaffAccessDenial(membershipId: null, institutionId: null, reason: null, popup: null);
      return StaffAccessDenial(
        membershipId: detail['membership_id'] as String?,
        institutionId: detail['institution_id'] as String?,
        reason: detail['reason'] as String?,
        popup: detail['popup'] is Map ? Map<String, dynamic>.from(detail['popup'] as Map) : null,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Última negação vista em qualquer chamada ao servidor. Quem escuta
/// (Principal e Superadmin) mostra o popup e volta ao seletor de contexto;
/// depois zera com `staffAccessDenied.value = null`.
final ValueNotifier<StaffAccessDenial?> staffAccessDenied = ValueNotifier<StaffAccessDenial?>(null);
