import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:flutter_test/flutter_test.dart';

/// What each read does with a field nobody agreed to, measured side by side.
///
/// Estruturas has two generations of decoder living together. The v2 contracts -
/// locations, the CHILD read, the person detail, the unit detail - take a closed
/// key set: a payload carrying anything else is refused whole. The older ones
/// read key by key, so an unknown field is ignored without a word.
///
/// Neither is wrong on its own, and I am not proposing to change them tonight.
/// What is wrong is not knowing which is which, because the two fail in opposite
/// directions and the difference decides what a server change costs.
///
/// Strict: the server adds a field and every read breaks at once, loudly, before
/// anybody ships a screen for it. Expensive and safe.
///
/// Permissive: the server adds a field and nothing happens. No error, no screen,
/// no trace - the capability exists on one side and simply never arrives. It is
/// the read-direction twin of the twenty-five institution fields measured in
/// revision 34, which are collected and dropped on the way out.
///
/// This test states the map as it is. Either kind changing sides is a decision,
/// and a decision should not happen by editing a factory.
Map<String, Object?> _institutionDetail() => {
  'id': 'institution-1',
  'public_name': 'Instituicao Aurora',
  'status': 'active',
  'management_version': 7,
  'institution_type': {'id': '11111111-1111-4111-8111-111111111111', 'name': 'Escola'},
  'address': {'country': 'Brasil', 'city': 'Sao Paulo', 'postal_code': '01310100'},
  'subscription': {'plan_code': 'essential', 'status': 'active'},
};

Map<String, Object?> _institutionRow() => {
  'id': 'institution-1',
  'public_name': 'Instituicao Aurora',
  'status': 'active',
  'units_count': 1,
  'groups_count': 2,
};

Map<String, dynamic> _personRow() => {
  'id': '44444444-4444-4444-8444-444444444444',
  'display_name': 'Ana Lima',
  'legal_name': 'Ana Lima',
  'person_type': 'adult',
  'status': 'active',
  'updated_at': '2026-01-02T00:00:00Z',
};

Map<String, Object?> _unitDetail() => {
  'id': '11111111-1111-4111-8111-111111111111',
  'name': 'Unidade',
  'slug': 'unidade',
  'status': 'active',
  'institution': {
    'id': '22222222-2222-4222-8222-222222222222',
    'name': 'Instituicao',
    'type': {'id': '22222222-2222-4222-8222-222222222222', 'name': 'Escola'},
  },
  'unit_type': {'id': '22222222-2222-4222-8222-222222222222', 'name': 'Escola'},
  'address': null,
  'contact': null,
  'effective_plan': null,
};

/// Decodes the payload with one key added that no contract mentions.
bool _refusesUnknownKey(
  void Function(Map<String, dynamic> payload) decode,
  Map<String, Object?> valid,
) {
  final intruded = Map<String, dynamic>.from(valid)..['sacola_de_gato'] = 'nao combinado';
  try {
    decode(intruded);
    return false;
  } on Object {
    return true;
  }
}

void main() {
  group('the valid payloads decode, or the rest measures nothing', () {
    test('institution detail', () {
      expect(
        InstitutionRecord.fromRpcPayload(_institutionDetail()).publicName,
        'Instituicao Aurora',
      );
    });
    test('institution directory row', () {
      expect(InstitutionDirectoryItem.fromJson(_institutionRow()).publicName, 'Instituicao Aurora');
    });
    test('person directory row', () {
      expect(PersonDirectoryItem.fromJson(_personRow()).displayName, 'Ana Lima');
    });
    test('unit detail', () {
      expect(UnitDetail.fromJson(_unitDetail()).name, 'Unidade');
    });
  });

  group('a field nobody agreed to', () {
    test('is refused by the unit detail, which takes a closed set', () {
      expect(
        _refusesUnknownKey((payload) => UnitDetail.fromJson(payload), _unitDetail()),
        isTrue,
        reason: 'the v2 reads refuse the whole payload rather than read it in part',
      );
    });

    test('is ignored by the institution detail, without a word', () {
      expect(
        _refusesUnknownKey(
          (payload) => InstitutionRecord.fromRpcPayload(payload),
          _institutionDetail(),
        ),
        isFalse,
        reason:
            'a field the server starts returning here arrives nowhere and '
            'breaks nothing; that is the cost of this generation of decoder',
      );
    });

    test('is ignored by the institution directory row', () {
      expect(
        _refusesUnknownKey(
          (payload) => InstitutionDirectoryItem.fromJson(payload),
          _institutionRow(),
        ),
        isFalse,
      );
    });

    test('is ignored by the person directory row', () {
      expect(
        _refusesUnknownKey((payload) => PersonDirectoryItem.fromJson(payload), _personRow()),
        isFalse,
      );
    });
  });

  test('the map, stated in one place', () {
    // Kept as a single assertion so the shape of the split is readable, and so
    // that moving one decoder across the line shows up as one failing line with
    // its name in it.
    final refuses = {
      'unit detail': _refusesUnknownKey((payload) => UnitDetail.fromJson(payload), _unitDetail()),
      'institution detail': _refusesUnknownKey(
        (payload) => InstitutionRecord.fromRpcPayload(payload),
        _institutionDetail(),
      ),
      'institution directory row': _refusesUnknownKey(
        (payload) => InstitutionDirectoryItem.fromJson(payload),
        _institutionRow(),
      ),
      'person directory row': _refusesUnknownKey(
        (payload) => PersonDirectoryItem.fromJson(payload),
        _personRow(),
      ),
    };
    expect(refuses, {
      'unit detail': true,
      'institution detail': false,
      'institution directory row': false,
      'person directory row': false,
    });
  });
}
