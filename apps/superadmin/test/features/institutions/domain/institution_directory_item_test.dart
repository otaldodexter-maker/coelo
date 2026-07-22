import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the institution directory view JSON without exposing CNPJ', () {
    final item = InstitutionDirectoryItem.fromJson({
      'id': 'institution-1',
      'public_name': 'Colégio Aurora',
      'trade_name': 'Aurora',
      'legal_name': 'Aurora Educação LTDA',
      'primary_domain': 'aurora.coelo.me',
      'status': 'active',
      'institution_type_id': 'type-1',
      'type_name': 'Escola',
      'district': 'Pinheiros',
      'street': 'Rua das Flores',
      'postal_code': '01234-567',
      'number': '120',
      'complement': 'Sala 4',
      'city': 'São Paulo',
      'state': 'SP',
      'contact_email': 'contato@aurora.coelo.me',
      'contact_phone': '+55 11 3333-4444',
      'contact_mobile_phone': '+55 11 99999-8888',
      'plan_id': 'plan-1',
      'plan_name': 'Essencial',
      'units_count': 3,
      'groups_count': 12,
      'document_ref': '00.000.000/0001-00',
    });

    expect(item.id, 'institution-1');
    expect(item.publicName, 'Colégio Aurora');
    expect(item.tradeName, 'Aurora');
    expect(item.legalName, 'Aurora Educação LTDA');
    expect(item.primaryDomain, 'aurora.coelo.me');
    expect(item.status, InstitutionStatus.active);
    expect(item.status.label, 'Ativa');
    expect(item.typeId, 'type-1');
    expect(item.typeName, 'Escola');
    expect(item.district, 'Pinheiros');
    expect(item.street, 'Rua das Flores');
    expect(item.postalCode, '01234-567');
    expect(item.addressNumber, '120');
    expect(item.complement, 'Sala 4');
    expect(item.city, 'São Paulo');
    expect(item.state, 'SP');
    expect(item.contactEmail, 'contato@aurora.coelo.me');
    expect(item.contactPhone, '+55 11 3333-4444');
    expect(item.contactMobilePhone, '+55 11 99999-8888');
    expect(item.planId, 'plan-1');
    expect(item.planName, 'Essencial');
    expect(item.unitsCount, 3);
    expect(item.groupsCount, 12);
    expect(item.initials, 'CA');
  });

  test('rejects an institution status outside the database enum', () {
    expect(
      () => InstitutionDirectoryItem.fromJson({
        'id': 'institution-1',
        'public_name': 'Instituição',
        'status': 'trial',
        'units_count': 0,
        'groups_count': 0,
      }),
      throwsFormatException,
    );
  });

  test('models all real institution statuses and keeps trial out', () {
    expect(InstitutionStatus.values.map((status) => status.databaseValue), [
      'draft',
      'onboarding',
      'active',
      'inactive',
      'suspended',
      'archived',
    ]);
  });
}
