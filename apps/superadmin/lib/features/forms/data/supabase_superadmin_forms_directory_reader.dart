import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';

import 'forms_backend_gateway.dart';
import 'forms_directory_reader.dart';

final class SupabaseSuperadminFormsDirectoryReader implements FormsDirectoryReader {
  const SupabaseSuperadminFormsDirectoryReader(this._backend);

  final FormsBackendGateway _backend;
  static const _codec = FormCursorCodec();
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _timestamp = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-](\d{2}):(\d{2}))$',
  );

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    final parameters = _query(query);
    try {
      final envelope = _map(
        await _backend.rpc('superadmin_forms_directory_v2', {'p_query': parameters}),
      );
      // An error never becomes a projection, even if a backend accidentally supplies data.
      if (envelope['ok'] == false) {
        final error = _map(envelope['error']);
        throw _failure(error['code']);
      }
      requireOnlyKeys(envelope, const {'ok', 'data', 'error'}, context: 'directory');
      if (envelope['ok'] != true || envelope['error'] != null) throw const FormatException();
      return _page(_map(envelope['data']), query.limit);
    } on FormApiException {
      rethrow;
    } on FormsBackendFailure catch (error) {
      throw _failure(error.code);
    } catch (_) {
      throw _failure(null);
    }
  }

  Map<String, Object?> _query(FormDirectoryQuery query) {
    try {
      if (query.limit < 1 ||
          query.limit > 100 ||
          (query.institutionId != null && !_uuid.hasMatch(query.institutionId!)) ||
          (query.search?.length ?? 0) > 500) {
        throw const FormatException();
      }
      final parameters = FormDirectoryQueryDto.fromDomain(query).toJson()..remove('cursor');
      final start = parameters['starts_on_or_after'] as String?;
      final end = parameters['ends_on_or_before'] as String?;
      if (start != null && end != null && start.compareTo(end) > 0) throw const FormatException();
      FormCursor? cursor;
      if (query.cursor != null) {
        if (query.cursor!.length > 1024) throw const FormatException();
        cursor = _codec.decode(query.cursor!);
        if (!_uuid.hasMatch(cursor.id)) throw const FormatException();
        _dateTime(cursor.sortKey);
      }
      return {...parameters, 'cursor_updated_at': cursor?.sortKey, 'cursor_id': cursor?.id};
    } catch (_) {
      throw _failure('SAI_INVALID_ARGUMENT');
    }
  }

  FormCursorPage<FormDirectoryItem> _page(Map<String, Object?> data, int limit) {
    requireOnlyKeys(data, const {'items', 'has_more', 'next_cursor'}, context: 'directory_page');
    final rawItems = requireList(data, 'items', context: 'directory_page');
    if (rawItems.length > limit) throw const FormatException();
    final items = rawItems.map((raw) => _item(_map(raw))).toList(growable: false);
    if (items.map((item) => item.id).toSet().length != items.length) throw const FormatException();
    final more = requireBool(data, 'has_more', context: 'directory_page');
    String? next;
    if (more) {
      if (items.isEmpty) throw const FormatException();
      final cursor = _map(data['next_cursor']);
      requireOnlyKeys(cursor, const {'updated_at', 'id'}, context: 'directory_cursor');
      final stamp = requireString(cursor, 'updated_at', context: 'directory_cursor');
      final id = requireString(cursor, 'id', context: 'directory_cursor');
      if (id != items.last.id || _dateTime(stamp) != items.last.updatedAt) {
        throw const FormatException();
      }
      next = _codec.encode(FormCursor(sortKey: stamp, id: id));
    } else if (data['next_cursor'] != null) {
      throw const FormatException();
    }
    return FormCursorPage(items: items, nextCursor: next);
  }

  FormDirectoryItem _item(Map<String, Object?> item) {
    const context = 'directory_item';
    requireOnlyKeys(item, const {
      'id',
      'title',
      'kind',
      'status',
      'operational_status',
      'identity_mode',
      'updated_at',
      'management_version',
    }, context: context);
    final id = requireString(item, 'id', context: context);
    final version = requireInt(item, 'management_version', context: context);
    if (!_uuid.hasMatch(id) || version < 1) throw const FormatException();
    return FormDirectoryItem(
      id: id,
      title: requireString(item, 'title', context: context),
      kind: switch (item['kind']) {
        'form' => FormKind.form,
        'quick_poll' => FormKind.quickPoll,
        _ => throw const FormatException(),
      },
      status: _enum(FormStatus.values, item['status']),
      operationalStatus: _enum(FormOperationalStatus.values, item['operational_status']),
      identityMode: _enum(FormIdentityMode.values, item['identity_mode']),
      updatedAt: _dateTime(requireString(item, 'updated_at', context: context)),
      managementVersion: version,
    );
  }

  static T _enum<T extends Enum>(List<T> values, Object? name) =>
      values.firstWhere((value) => value.name == name, orElse: () => throw const FormatException());

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map<String, Object?>) throw const FormatException();
    return value;
  }

  static DateTime _dateTime(String value) {
    final match = _timestamp.firstMatch(value);
    if (match == null) throw const FormatException();
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime.utc(year, month, day);
    if (year < 1 ||
        date.year != year ||
        date.month != month ||
        date.day != day ||
        int.parse(match[4]!) > 23 ||
        int.parse(match[5]!) > 59 ||
        int.parse(match[6]!) > 59 ||
        (match[7] != null && (int.parse(match[7]!) > 15 || int.parse(match[8]!) > 59))) {
      throw const FormatException();
    }
    return DateTime.parse(value);
  }

  static FormApiException _failure(Object? code) {
    final kind = switch (code) {
      'SAI_AUTH_REQUIRED' ||
      'SAI_SESSION_INVALID' ||
      'SAI_INTERNAL_CONTEXT_DENIED' ||
      'SAI_MEMBERSHIP_SUSPENDED' ||
      'SAI_MEMBERSHIP_REVOKED' ||
      'SAI_PERMISSION_DENIED' ||
      'SAI_MFA_REQUIRED' ||
      '42501' ||
      'PGRST301' => FormApiFailureKind.unauthorized,
      'SAI_INVALID_ARGUMENT' || '22023' => FormApiFailureKind.validation,
      _ => FormApiFailureKind.unavailable,
    };
    return FormApiException(kind, switch (kind) {
      FormApiFailureKind.unauthorized => 'Você não possui permissão para esta ação.',
      FormApiFailureKind.validation => 'Revise os dados enviados e tente novamente.',
      _ => 'O diretório está indisponível. Tente novamente.',
    });
  }
}
