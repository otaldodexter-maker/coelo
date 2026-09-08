import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:test/test.dart';

const id = '10000000-0000-4000-8000-000000000001';
const institutionId = '20000000-0000-4000-8000-000000000001';
const otherId = '30000000-0000-4000-8000-000000000001';
const unitId = '40000000-0000-4000-8000-000000000001';
Map<String, Object?> payload() => {
  'id': id,
  'scope_kind': 'institution',
  'institution_id': institutionId,
  'unit_id': null,
  'name': 'Sala',
  'description': null,
  'kind': 'internal',
  'floor': null,
  'address': null,
  'visibility': 'team',
  'status': 'active',
  'management_version': 1,
  'created_at': '2026-09-07T10:00:00+00:00',
  'updated_at': '2026-09-07T11:00:00+00:00',
};
Map<String, Object?> envelope(Object? data) => {'ok': true, 'data': data, 'error': null};
LocationCatalogEntry decode(Map<String, Object?> data) =>
    decodeLocationDetailV2(envelope(data), requestedId: id);

void main() {
  test('rejects unpaired UTF16 surrogate that cannot originate from PostgreSQL UTF8', () {
    expect(() => decode(payload()..['name'] = '\ud800'), throwsFormatException);
  });
  test('unit directory succeeds without changing catalog scope', () {
    final result = decodeLocationDirectoryV2(
      envelope({
        'items': [
          payload()..addAll({'scope_kind': 'unit', 'unit_id': unitId}),
        ],
        'total_count': 1,
      }),
      requestedScope: const LocationScope.unit(institutionId: institutionId, unitId: unitId),
    );
    expect((result.items.single.scope as UnitLocationScope).unitId, unitId);
  });
  test(
    'directory cannot exceed maximum page size',
    () => expect(
      () => decodeLocationDirectoryV2(
        envelope({'items': List.generate(101, (_) => payload()), 'total_count': 101}),
        requestedScope: const LocationScope.institution(institutionId: institutionId),
      ),
      throwsFormatException,
    ),
  );
  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_MFA_REQUIRED',
  ]) {
    test(
      'maps safe denial $code',
      () => expect(
        () => decodeLocationDetailV2({
          'ok': false,
          'data': null,
          'error': {
            'code': code,
            'message': 'untrusted',
            'correlation_id': otherId,
            'http_status': 403,
          },
        }, requestedId: id),
        throwsA(isA<LocationReadDeniedException>()),
      ),
    );
  }
  test(
    'unknown backend error remains generic',
    () => expect(
      () => decodeLocationDetailV2({
        'ok': false,
        'data': null,
        'error': {
          'code': 'UNKNOWN',
          'message': 'sensitive',
          'correlation_id': otherId,
          'http_status': 500,
        },
      }, requestedId: id),
      throwsA(isA<FormatException>().having((e) => e.source, 'no source payload', isNull)),
    ),
  );
  test('reads exact catalog projection without deriving authorization', () {
    final entry = decode(payload());
    expect(entry.id, id);
    expect(entry.scope, isA<InstitutionLocationScope>());
    expect(entry.scope.institutionId, institutionId);
    expect(entry.kind, LocationKind.internal);
    expect(entry.visibility, LocationVisibility.team);
    expect(entry.status, LocationCatalogStatus.active);
    expect(entry.managementVersion, 1);
    expect(entry.createdAt.isUtc, isTrue);
  });
  test('unit scope is explicit', () {
    final entry = decode(payload()..addAll({'scope_kind': 'unit', 'unit_id': unitId}));
    expect((entry.scope as UnitLocationScope).unitId, unitId);
  });
  for (final status in ['draft', 'active', 'inactive', 'suspended', 'archived']) {
    test(
      'accepts record status $status',
      () => expect(decode(payload()..['status'] = status).status.name, status),
    );
  }
  for (final visibility in ['team', 'guardians', 'students', 'all']) {
    test(
      'accepts explicit visibility $visibility',
      () => expect(decode(payload()..['visibility'] = visibility).visibility.name, visibility),
    );
  }
  test('external address preserves absent versus null and is immutable', () {
    final address = <String, Object?>{'country': 'Brasil', 'city': null};
    final entry = decode(payload()..addAll({'kind': 'external', 'address': address}));
    address['city'] = 'Changed';
    expect(entry.address, {'country': 'Brasil', 'city': null});
    expect(entry.address!.containsKey('street'), isFalse);
    expect(() => entry.address!['city'] = 'Mutation', throwsUnsupportedError);
  });
  test('Unicode codepoints use PostgreSQL limits and preserve NBSP', () {
    final name = '😀' * 120;
    expect(decode(payload()..['name'] = name).name, name);
    expect(decode(payload()..['name'] = '\u00a0Sala\u00a0').name, '\u00a0Sala\u00a0');
    expect(decode(payload()..['description'] = '😀' * 500).description, '😀' * 500);
    expect(decode(payload()..['floor'] = '😀' * 120).floor, '😀' * 120);
  });
  test('valid timezone offsets preserve instant and fractional seconds', () {
    final entry = decode(payload()..['updated_at'] = '2024-02-29T23:59:59.123456-03:00');
    expect(entry.updatedAt, DateTime.utc(2024, 3, 1, 2, 59, 59, 123, 456));
  });
  final badFields = <String, Map<String, Object?>>{
    'id': {'id': 'invalid'},
    'owner id': {'institution_id': 'invalid'},
    'owner scope': {'scope_kind': 'group'},
    'institution XOR': {'unit_id': unitId},
    'unit XOR': {'scope_kind': 'unit'},
    'kind': {'kind': 'other'},
    'visibility': {'visibility': 'public'},
    'status': {'status': 'deleted'},
    'name empty': {'name': ''},
    'name untrimmed': {'name': ' Sala'},
    'name control': {'name': 'Sa\tla'},
    'name overflow': {'name': '😀' * 121},
    'description empty': {'description': ''},
    'description overflow': {'description': 'x' * 501},
    'floor overflow': {'floor': 'x' * 121},
    'version zero': {'management_version': 0},
    'version fractional': {'management_version': 1.5},
    'version string': {'management_version': '1'},
    'version unsafe': {'management_version': 9007199254740992},
    'external no address': {'kind': 'external'},
    'address no country': {'address': <String, Object?>{}},
    'address country null': {
      'address': {'country': null},
    },
    'address country foreign': {
      'address': {'country': 'Other'},
    },
    'address unknown': {
      'address': {'country': 'Brasil', 'latitude': 1},
    },
    'address blank': {
      'address': {'country': 'Brasil', 'city': ''},
    },
    'address UTF8 overflow': {
      'address': {'country': 'Brasil', 'city': '😀' * 61},
    },
    'address postal': {
      'address': {'country': 'Brasil', 'postal_code': '01001-000'},
    },
    'timestamp no zone': {'updated_at': '2026-09-07T10:00:00'},
    'timestamp calendar': {'updated_at': '2026-02-30T10:00:00Z'},
    'timestamp hour': {'updated_at': '2026-09-07T24:00:00Z'},
    'timestamp second': {'updated_at': '2026-09-07T10:00:60Z'},
    'timestamp offset': {'updated_at': '2026-09-07T10:00:00+24:00'},
    'extra author': {'created_by_person_id': otherId},
  };
  for (final bad in badFields.entries) {
    test(
      'rejects ${bad.key}',
      () => expect(() => decode(payload()..addAll(bad.value)), throwsFormatException),
    );
  }
  for (final key in payload().keys) {
    test(
      'requires key $key even when nullable',
      () => expect(() => decode(payload()..remove(key)), throwsFormatException),
    );
  }
  test(
    'rejects requested ID mismatch',
    () => expect(
      () => decodeLocationDetailV2(envelope(payload()), requestedId: otherId),
      throwsFormatException,
    ),
  );
  test(
    'address UTF8 exact boundary is accepted',
    () => expect(
      decode(payload()..['address'] = {'country': 'Brasil', 'city': '😀' * 60}).address!['city'],
      '😀' * 60,
    ),
  );
  test('directory checks owner and returns immutable list', () {
    final rows = [payload()];
    final result = decodeLocationDirectoryV2(
      envelope({'items': rows, 'total_count': 1}),
      requestedScope: const LocationScope.institution(institutionId: institutionId),
    );
    rows.clear();
    expect(result.items, hasLength(1));
    expect(result.totalCount, 1);
    expect(() => result.items.clear(), throwsUnsupportedError);
  });
  test(
    'directory rejects owner mismatch',
    () => expect(
      () => decodeLocationDirectoryV2(
        envelope({
          'items': [payload()],
          'total_count': 1,
        }),
        requestedScope: const LocationScope.institution(institutionId: otherId),
      ),
      throwsFormatException,
    ),
  );
  test(
    'directory rejects mixed unit catalog',
    () => expect(
      () => decodeLocationDirectoryV2(
        envelope({
          'items': [payload()],
          'total_count': 1,
        }),
        requestedScope: const LocationScope.unit(institutionId: institutionId, unitId: unitId),
      ),
      throwsFormatException,
    ),
  );
  test(
    'directory rejects duplicate IDs',
    () => expect(
      () => decodeLocationDirectoryV2(
        envelope({
          'items': [payload(), payload()],
          'total_count': 2,
        }),
        requestedScope: const LocationScope.institution(institutionId: institutionId),
      ),
      throwsFormatException,
    ),
  );
  test(
    'directory rejects impossible count',
    () => expect(
      () => decodeLocationDirectoryV2(
        envelope({
          'items': [payload()],
          'total_count': 0,
        }),
        requestedScope: const LocationScope.institution(institutionId: institutionId),
      ),
      throwsFormatException,
    ),
  );
  test('denial is typed and never exposes backend message', () {
    final denied = {
      'ok': false,
      'data': null,
      'error': {
        'code': 'SAI_PERMISSION_DENIED',
        'message': 'sensitive untrusted text',
        'correlation_id': otherId,
        'http_status': 403,
      },
    };
    expect(
      () => decodeLocationDetailV2(denied, requestedId: id),
      throwsA(
        isA<LocationReadDeniedException>().having(
          (e) => e.toString(),
          'safe text',
          isNot(contains('sensitive')),
        ),
      ),
    );
  });
  for (final value in [
    null,
    <String, Object?>{},
    {'ok': true, 'data': payload()},
    {'ok': false, 'data': payload(), 'error': null},
  ]) {
    test(
      'rejects malformed envelope ${value.runtimeType} ${value.hashCode}',
      () => expect(() => decodeLocationDetailV2(value, requestedId: id), throwsFormatException),
    );
  }
}
