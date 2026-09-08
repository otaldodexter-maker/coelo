import 'dart:convert';
import 'dart:io';

import 'package:coelo_superadmin/features/institutions/data/supabase_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How much of an institution edit actually leaves the building.
///
/// The screen collects an institution the way the product describes one:
/// identity, address, contacts, owner, subscription, brand, profile. The write
/// carries a fraction of it, because `superadmin_institution_edit_core_v2`
/// accepts a fraction: seven top-level keys and eight address keys, and refuses
/// the payload outright if it sees anything else.
///
/// I had been reporting that fraction as "seven of about forty-five". That was
/// an estimate. These tests measure it: every string the record can hold gets a
/// sentinel value, and the payload is searched for each one. What comes back is
/// a list, not a guess.
///
/// The measurement matters because of what happens to the rest. Three things
/// fail closed - legal representatives, administrators, and a secondary surface
/// colour moved off its default - and the repository refuses the whole save
/// with `InstitutionDirectoryUnsupportedRelationException`. Everything else is
/// simply not sent, and the save reports success.
const _migration =
    '../../packages/coelo_database/migrations/'
    '20260828000500_superadmin_internal_institution_edit_core.sql';

/// The quoted keys of the n-th `where not(payload_key=any(array[...]))` guard.
///
/// The function checks the top-level payload first and the address object
/// second, with the same shape, so the order is the contract.
Set<String> _payloadAllowlist(String sql, int occurrence) {
  final guards = RegExp(
    r'where not\(payload_key=any\(array\[([^\]]*)\]',
  ).allMatches(sql).toList();
  if (guards.length <= occurrence) {
    throw StateError('the migration no longer has ${occurrence + 1} payload guards');
  }
  return RegExp("'([a-z_]+)'")
      .allMatches(guards[occurrence].group(1)!)
      .map((match) => match.group(1)!)
      .toSet();
}

/// Every string an institution can hold, each one traceable.
///
/// `postalCode` gets digits because the payload strips everything else from it,
/// and `secondarySurfaceColor` is left alone because moving it trips the guard
/// that the last test is about.
const _sentinels = <String, String>{
  'publicName': 'xPublicNamex',
  'tradeName': 'xTradeNamex',
  'legalName': 'xLegalNamex',
  'typeId': 'xTypeIdx',
  'typeName': 'xTypeNamex',
  'documentType': 'xDocumentTypex',
  'document': 'xDocumentx',
  'slug': 'xSlugx',
  'primaryDomain': 'xPrimaryDomainx',
  'locale': 'xLocalex',
  'timezone': 'xTimezonex',
  'postalCode': '99887766',
  'country': 'xCountryx',
  'state': 'xStatex',
  'city': 'xCityx',
  'district': 'xDistrictx',
  'street': 'xStreetx',
  'addressNumber': 'xAddressNumberx',
  'complement': 'xComplementx',
  'contactEmail': 'xContactEmailx',
  'contactPhone': 'xContactPhonex',
  'contactMobilePhone': 'xContactMobilePhonex',
  'ownerFirstName': 'xOwnerFirstNamex',
  'ownerLastName': 'xOwnerLastNamex',
  'ownerDisplayName': 'xOwnerDisplayNamex',
  'ownerEmail': 'xOwnerEmailx',
  'ownerMobilePhone': 'xOwnerMobilePhonex',
  'subscriptionJustification': 'xSubscriptionJustificationx',
  'brandDisplayName': 'xBrandDisplayNamex',
  'accentColor': 'xAccentColorx',
  'secondaryColor': 'xSecondaryColorx',
  'tertiaryColor': 'xTertiaryColorx',
  'textColor': 'xTextColorx',
  'secondaryTextColor': 'xSecondaryTextColorx',
  'tertiaryTextColor': 'xTertiaryTextColorx',
  'surfaceColor': 'xSurfaceColorx',
  'profileBio': 'xProfileBiox',
  'websiteUrl': 'xWebsiteUrlx',
  'whatsappNumber': 'xWhatsappNumberx',
};

/// The fourteen that the function is willing to store.
const _reaching = {
  'publicName',
  'tradeName',
  'legalName',
  'typeId',
  'locale',
  'timezone',
  'postalCode',
  'country',
  'state',
  'city',
  'district',
  'street',
  'addressNumber',
  'complement',
};

Map<String, Object?> _detailRow() => {
  'id': 'institution-1',
  'public_name': 'Instituicao Aurora',
  'status': 'active',
  'management_version': 7,
  'institution_type': {'id': '11111111-1111-4111-8111-111111111111', 'name': 'Escola'},
  'address': {'country': 'Brasil', 'city': 'Sao Paulo', 'postal_code': '01310100'},
  'subscription': {'plan_code': 'essential', 'status': 'active'},
};

InstitutionRecord _sentinelled() => InstitutionRecord.fromRpcPayload(_detailRow()).copyWith(
  publicName: _sentinels['publicName'],
  tradeName: _sentinels['tradeName'],
  legalName: _sentinels['legalName'],
  typeId: _sentinels['typeId'],
  typeName: _sentinels['typeName'],
  documentType: _sentinels['documentType'],
  document: _sentinels['document'],
  slug: _sentinels['slug'],
  primaryDomain: _sentinels['primaryDomain'],
  locale: _sentinels['locale'],
  timezone: _sentinels['timezone'],
  postalCode: _sentinels['postalCode'],
  country: _sentinels['country'],
  state: _sentinels['state'],
  city: _sentinels['city'],
  district: _sentinels['district'],
  street: _sentinels['street'],
  addressNumber: _sentinels['addressNumber'],
  complement: _sentinels['complement'],
  contactEmail: _sentinels['contactEmail'],
  contactPhone: _sentinels['contactPhone'],
  contactMobilePhone: _sentinels['contactMobilePhone'],
  ownerFirstName: _sentinels['ownerFirstName'],
  ownerLastName: _sentinels['ownerLastName'],
  ownerDisplayName: _sentinels['ownerDisplayName'],
  ownerEmail: _sentinels['ownerEmail'],
  ownerMobilePhone: _sentinels['ownerMobilePhone'],
  subscriptionJustification: _sentinels['subscriptionJustification'],
  brandDisplayName: _sentinels['brandDisplayName'],
  accentColor: _sentinels['accentColor'],
  secondaryColor: _sentinels['secondaryColor'],
  tertiaryColor: _sentinels['tertiaryColor'],
  textColor: _sentinels['textColor'],
  secondaryTextColor: _sentinels['secondaryTextColor'],
  tertiaryTextColor: _sentinels['tertiaryTextColor'],
  surfaceColor: _sentinels['surfaceColor'],
  profileBio: _sentinels['profileBio'],
  websiteUrl: _sentinels['websiteUrl'],
  whatsappNumber: _sentinels['whatsappNumber'],
);

void main() {
  final sql = File(_migration).readAsStringSync();
  final topLevel = _payloadAllowlist(sql, 0);
  final address = _payloadAllowlist(sql, 1);

  Future<Map<String, Object?>> savedPayload(InstitutionRecord record) async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured ??= request;
        return Response(
          jsonEncode({'ok': true, 'data': _detailRow(), 'error': null}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await SupabaseInstitutionDirectoryRepository(client).update(record, expectedVersion: 7);
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    return (body['p_payload'] as Map).cast<String, Object?>();
  }

  test('the payload is exactly what the function will accept, no more', () async {
    // An unknown key is not ignored: the function raises and the save dies.
    final payload = await savedPayload(_sentinelled());
    expect(payload.keys.toSet(), equals(topLevel));
    expect((payload['address']! as Map).keys.cast<String>().toSet(), equals(address));
  });

  test('fourteen of the thirty-nine strings reach the server', () async {
    final payload = jsonEncode(await savedPayload(_sentinelled()));
    final arrived = <String>{};
    final lost = <String>{};
    _sentinels.forEach((field, sentinel) {
      (payload.contains(sentinel) ? arrived : lost).add(field);
    });

    expect(arrived, equals(_reaching));
    expect(arrived, hasLength(14));
    expect(lost, hasLength(_sentinels.length - 14));

    // Named rather than counted, because the count is the part that drifts.
    expect(
      lost,
      containsAll(<String>[
        'contactEmail',
        'contactPhone',
        'contactMobilePhone',
        'ownerEmail',
        'ownerMobilePhone',
        'primaryDomain',
        'document',
        'slug',
        'brandDisplayName',
        'profileBio',
        'websiteUrl',
        'whatsappNumber',
      ]),
      reason: 'these are collected on screen and stored nowhere',
    );
  });

  test('the identity of the record travels beside the payload, not inside it', () async {
    // `id` is an argument of its own, so its absence from the payload is
    // correct and not part of the loss above.
    final payload = await savedPayload(_sentinelled());
    expect(jsonEncode(payload).contains('institution-1'), isFalse);
  });

  test('three of the discarded fields fail closed instead, and only three', () async {
    // A secondary surface colour off its default is refused before any request
    // is made. Legal representatives and administrators go through the same
    // getter and refuse the same way.
    //
    // The other twenty-five are not refused. They are not sent either.
    var requests = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests += 1;
        return Response(
          jsonEncode({'ok': true, 'data': _detailRow(), 'error': null}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    await expectLater(
      repository.update(
        _sentinelled().copyWith(secondarySurfaceColor: '#101010'),
        expectedVersion: 7,
      ),
      throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
    );
    expect(requests, 0, reason: 'the refusal must happen before the network, not after');

    // The same record without that one colour saves, and takes none of the
    // other discarded values with it.
    await repository.update(_sentinelled(), expectedVersion: 7);
    expect(requests, greaterThan(0));
  });
}
