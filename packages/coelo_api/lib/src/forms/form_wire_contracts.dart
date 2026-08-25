import 'dart:convert';

final class WireFormatException implements FormatException {
  const WireFormatException(this.message, [this.source, this.offset]);

  @override
  final String message;
  @override
  final Object? source;
  @override
  final int? offset;

  @override
  String toString() => 'WireFormatException: $message';
}

final class FormCursor {
  const FormCursor({required this.sortKey, required this.id});

  final String sortKey;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is FormCursor && other.sortKey == sortKey && other.id == id;

  @override
  int get hashCode => Object.hash(sortKey, id);
}

final class FormCursorCodec {
  const FormCursorCodec();

  String encode(FormCursor cursor) {
    final bytes = utf8.encode(jsonEncode({'sort_key': cursor.sortKey, 'id': cursor.id}));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  FormCursor decode(String encoded) {
    try {
      final padding = '=' * ((4 - encoded.length % 4) % 4);
      final decoded = jsonDecode(utf8.decode(base64Url.decode('$encoded$padding')));
      if (decoded is! Map<String, Object?>) {
        throw const WireFormatException('Cursor must decode to an object.');
      }
      requireOnlyKeys(decoded, const {'sort_key', 'id'}, context: 'cursor');
      return FormCursor(
        sortKey: requireString(decoded, 'sort_key', context: 'cursor'),
        id: requireString(decoded, 'id', context: 'cursor'),
      );
    } on WireFormatException {
      rethrow;
    } catch (error) {
      throw WireFormatException('Invalid opaque cursor.', error);
    }
  }
}

final class FormCursorPage<T> {
  FormCursorPage({required List<T> items, required this.nextCursor})
    : items = List.unmodifiable(items);

  final List<T> items;
  final String? nextCursor;
}

final class FormCommand<T> {
  const FormCommand({
    required this.requestId,
    required this.expectedVersion,
    required this.payload,
  });

  static FormCommand<T> fromJson<T>(
    Map<String, Object?> json,
    T Function(Map<String, Object?> payload) decodePayload,
  ) {
    requireOnlyKeys(json, const {'request_id', 'expected_version', 'payload'}, context: 'command');
    return FormCommand<T>(
      requestId: requireString(json, 'request_id', context: 'command'),
      expectedVersion: requireInt(json, 'expected_version', context: 'command'),
      payload: decodePayload(requireMap(json, 'payload', context: 'command')),
    );
  }

  final String requestId;
  final int expectedVersion;
  final T payload;

  Map<String, Object?> toJson(Map<String, Object?> Function(T payload) encodePayload) => {
    'request_id': requestId,
    'expected_version': expectedVersion,
    'payload': encodePayload(payload),
  };
}

void requireOnlyKeys(Map<String, Object?> json, Set<String> allowed, {required String context}) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList(growable: false);
  if (unknown.isNotEmpty) {
    throw WireFormatException('$context contains unknown keys: ${unknown.join(', ')}.');
  }
  final missing = allowed.where((key) => !json.containsKey(key)).toList(growable: false);
  if (missing.isNotEmpty) {
    throw WireFormatException('$context is missing keys: ${missing.join(', ')}.');
  }
}

String requireString(Map<String, Object?> json, String key, {required String context}) {
  final value = json[key];
  if (value is! String) throw WireFormatException('$context.$key must be a string.');
  return value;
}

int requireInt(Map<String, Object?> json, String key, {required String context}) {
  final value = json[key];
  if (value is! int) throw WireFormatException('$context.$key must be an integer.');
  return value;
}

bool requireBool(Map<String, Object?> json, String key, {required String context}) {
  final value = json[key];
  if (value is! bool) throw WireFormatException('$context.$key must be a boolean.');
  return value;
}

Map<String, Object?> requireMap(Map<String, Object?> json, String key, {required String context}) {
  final value = json[key];
  if (value is! Map<String, Object?>) {
    throw WireFormatException('$context.$key must be an object.');
  }
  return value;
}

List<Object?> requireList(Map<String, Object?> json, String key, {required String context}) {
  final value = json[key];
  if (value is! List<Object?>) throw WireFormatException('$context.$key must be a list.');
  return value;
}
