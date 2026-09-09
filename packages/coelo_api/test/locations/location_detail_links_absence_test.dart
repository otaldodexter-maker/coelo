import 'dart:io';

import 'package:coelo_api/locations.dart';
import 'package:test/test.dart';

/// `locations.detail-links` is absent on both sides, and cannot arrive on one.
///
/// The inventory asks a location detail to name what uses it - a group, an
/// activity, an event, a form. Nothing carries that today: the server payload
/// has no such field and `LocationCatalogEntry` has no place to put one.
///
/// What makes the absence safe rather than merely true is that the decoder
/// takes a closed set of keys. A server that started answering with `consumers`
/// would not be half-read: the whole payload would be refused. So the two sides
/// cannot drift apart quietly - the first attempt to add links server-side
/// fails loudly, in front of whoever is adding it.
///
/// The shape the field should eventually take is already written down, in
/// `location_reservations.dart`. This test only holds the door until then.
const _entry = '../coelo_domain/lib/src/locations/location_catalog_entry.dart';

Map<String, Object?> _payload() => {
  'id': '10000000-0000-4000-8000-000000000001',
  'scope_kind': 'institution',
  'institution_id': '20000000-0000-4000-8000-000000000001',
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

Object? _envelope(Object? data) => {'ok': true, 'data': data, 'error': null};

void main() {
  test('the payload as it stands decodes, so the rest is about the addition', () {
    final entry = decodeLocationDetailV2(
      _envelope(_payload()),
      requestedId: '10000000-0000-4000-8000-000000000001',
    );
    expect(entry.name, 'Sala');
  });

  for (final field in ['links', 'consumers', 'usages', 'reservations', 'groups']) {
    test('a payload carrying $field is refused whole, not read in part', () {
      expect(
        () => decodeLocationDetailV2(
          _envelope(_payload()..[field] = <Object?>[]),
          requestedId: '10000000-0000-4000-8000-000000000001',
        ),
        throwsFormatException,
        reason: 'the key set is closed; adding $field on the server has to be a '
            'change here as well, and it has to be noticed',
      );
    });
  }

  test('the domain entry has no field for it either', () {
    final source = File(_entry).readAsStringSync();
    final start = source.indexOf('final class LocationCatalogEntry {');
    expect(start, isNot(-1), reason: 'the entry moved; point this test at it');
    final body = source.substring(start, source.indexOf('\n}', start));
    for (final field in ['link', 'consumer', 'usage', 'reservation']) {
      expect(
        body.toLowerCase().contains(field),
        isFalse,
        reason: 'LocationCatalogEntry now mentions $field; locations.detail-links '
            'is no longer absent and the inventory has to say so',
      );
    }
  });
}
