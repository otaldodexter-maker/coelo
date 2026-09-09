import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  final definition = FormDefinition(
    id: 'form-1',
    institutionId: 'institution-1',
    kind: FormKind.quickPoll,
    identityMode: FormIdentityMode.anonymous,
    responseUnit: FormResponseUnit.childFamilyContext,
    title: 'Como foi a semana?',
    description: 'Pulso semanal',
    status: FormStatus.published,
    managementVersion: 7,
    sections: [
      FormSection(
        id: 'section-1',
        title: 'Enquete',
        description: 'Escolha e detalhe',
        position: 0,
        items: [
          FormItem(
            id: 'choice',
            kind: FormItemKind.multipleChoice,
            label: 'Selecione',
            helpText: 'Pode marcar mais de uma opção',
            position: 0,
            config: const FormItemConfig(maxImages: null),
            options: const [
              FormOption(id: 'option-1', label: 'Ótima', position: 0),
              FormOption(id: 'option-2', label: 'Difícil', position: 1),
            ],
          ),
          FormItem(
            id: 'detail',
            kind: FormItemKind.shortText,
            label: 'Conte mais',
            position: 1,
            conditions: const [
              FormCondition.choice(sourceItemId: 'choice', optionIds: {'option-2'}),
            ],
          ),
        ],
      ),
    ],
  );

  Map<String, Object?> withConfig(String kind, Map<String, Object?> config) {
    final json = FormDefinitionDto.fromDomain(definition).toJson();
    final section = (json['sections'] as List).first as Map<String, Object?>;
    final item = (section['items'] as List).first as Map<String, Object?>;
    item['kind'] = kind;
    item['options'] = <Object?>[];
    item['config'] = config;
    return json;
  }

  Map<String, Object?> encodedConfig(FormDefinitionDto dto) {
    final section = (dto.toJson()['sections'] as List).first as Map<String, Object?>;
    final item = (section['items'] as List).first as Map<String, Object?>;
    return item['config'] as Map<String, Object?>;
  }

  for (final config in <Map<String, Object?>>[
    {},
    {'min_value': '2026-09-01'},
    {'max_value': '2026-09-30'},
    {'min_value': '2026-09-01', 'max_value': '2026-09-30'},
    {'min_value': '2024-02-29', 'max_value': '2024-02-29'},
    {'min_value': '2000-02-29', 'max_value': '9999-12-31'},
    {'min_value': '0001-01-01'},
    {'min_value': '2011-12-30', 'max_value': '2011-12-30'},
  ]) {
    test('canonical civil date config round-trips $config', () {
      final dto = FormDefinitionDto.fromJson(withConfig('date', config));
      final typed = dto.toDomain().sections.first.items.first.config;
      expect(typed.minValue, isNull);
      expect(typed.maxValue, isNull);
      expect(
        typed.minDate,
        config['min_value'] == null ? null : DateTime.parse('${config['min_value']}T00:00:00Z'),
      );
      expect(
        typed.maxDate,
        config['max_value'] == null ? null : DateTime.parse('${config['max_value']}T00:00:00Z'),
      );
      if (typed.minDate != null) expect(typed.minDate!.isUtc, isTrue);
      if (typed.maxDate != null) expect(typed.maxDate!.isUtc, isTrue);
      expect(encodedConfig(dto), config);
    });
  }

  for (final utc in [true, false]) {
    test('canonical civil date encoding preserves calendar fields utc=$utc', () {
      final date = utc ? DateTime.utc(2026, 9, 1, 1, 30) : DateTime(2026, 9, 1, 23, 30);
      final dto = FormDefinitionDto.fromDomain(
        FormDefinition(
          id: definition.id,
          institutionId: definition.institutionId,
          kind: definition.kind,
          identityMode: definition.identityMode,
          responseUnit: definition.responseUnit,
          title: definition.title,
          sections: [
            FormSection(
              id: 'section',
              title: 'Section',
              position: 0,
              items: [
                FormItem(
                  id: 'date',
                  kind: FormItemKind.date,
                  label: 'Date',
                  position: 0,
                  config: FormItemConfig(minDate: date, maxDate: date),
                ),
              ],
            ),
          ],
        ),
      );
      expect(encodedConfig(dto), {'min_value': '2026-09-01', 'max_value': '2026-09-01'});
    });
  }

  for (final key in ['min_value', 'max_value']) {
    for (final value in <Object?>[
      '2026-02-29',
      '1900-02-29',
      '2026-02-30',
      '2026-04-31',
      '2026-00-01',
      '2026-13-01',
      '2026-01-00',
      '0000-01-01',
      '10000-01-01',
      '2026-9-01',
      '2026-09-01\n',
      ' 2026-09-01',
      '2026-09-01T00:00:00Z',
      '',
      20260901,
      true,
      null,
      <Object?>[],
      <String, Object?>{},
    ]) {
      test('canonical civil date rejects $key=$value', () {
        expect(
          () => FormDefinitionDto.fromJson(withConfig('date', {key: value})),
          throwsA(isA<WireFormatException>()),
        );
      });
    }
  }

  test('canonical civil date rejects reversed range', () {
    expect(
      () => FormDefinitionDto.fromJson(
        withConfig('date', {'min_value': '2026-09-30', 'max_value': '2026-09-01'}),
      ),
      throwsA(isA<WireFormatException>()),
    );
  });

  for (final value in <num>[1, 120, 120.0, 10000]) {
    test('canonical short text length round-trips $value', () {
      final config = encodedConfig(
        FormDefinitionDto.fromJson(withConfig('short_text', {'max_length': value})),
      );
      expect(config, {'max_length': value.toInt()});
      expect(config['max_length'], isA<int>());
    });
  }
  test('canonical short text absent length stays absent', () {
    expect(encodedConfig(FormDefinitionDto.fromJson(withConfig('short_text', {}))), isEmpty);
  });
  test('canonical short text length is not accepted for another kind', () {
    expect(
      () => FormDefinitionDto.fromJson(withConfig('integer', {'max_length': 120})),
      throwsA(isA<WireFormatException>()),
    );
  });
  for (final value in <Object?>[
    0,
    -1,
    10001,
    1.5,
    '120',
    null,
    true,
    <Object?>[],
    <String, Object?>{},
    double.nan,
    double.infinity,
    double.negativeInfinity,
  ]) {
    test('canonical short text rejects malformed length $value', () {
      expect(
        () => FormDefinitionDto.fromJson(withConfig('short_text', {'max_length': value})),
        throwsA(isA<WireFormatException>()),
      );
    });
  }
  for (final kind in ['integer', 'decimal', 'money']) {
    test('canonical numeric config remains numeric $kind', () {
      final config = <String, Object?>{'min_value': 1, 'max_value': 100};
      if (kind == 'decimal') config['decimal_places'] = 2;
      if (kind == 'money') config['currency'] = 'BRL';
      expect(encodedConfig(FormDefinitionDto.fromJson(withConfig(kind, config))), config);
    });
  }

  test('round-trips the complete definition contract', () {
    final json = FormDefinitionDto.fromDomain(definition).toJson();
    final decoded = FormDefinitionDto.fromJson(json).toDomain();

    expect(decoded.id, definition.id);
    expect(decoded.kind, FormKind.quickPoll);
    expect(decoded.identityMode, FormIdentityMode.anonymous);
    expect(decoded.sections.single.items.last.conditions.single.optionIds, {'option-2'});
    expect(decoded.description, 'Pulso semanal');
    expect(decoded.sections.single.description, 'Escolha e detalhe');
    expect(decoded.sections.single.items.first.helpText, 'Pode marcar mais de uma opção');
    expect(json['kind'], 'quick_poll');
    expect(json['response_unit'], 'child_family_context');
    final encodedSection = (json['sections']! as List<Object?>).first as Map<String, Object?>;
    final encodedItem = (encodedSection['items']! as List<Object?>).first as Map<String, Object?>;
    expect(encodedItem['config'], isEmpty);
  });

  for (final config in [
    <String, Object?>{},
    <String, Object?>{'min_selections': 2},
    <String, Object?>{'max_selections': 50},
    <String, Object?>{'min_selections': 2, 'max_selections': 4},
  ]) {
    test('preserves explicit selection limits and absent defaults $config', () {
      final json = FormDefinitionDto.fromDomain(definition).toJson();
      final section = (json['sections'] as List).first as Map<String, Object?>;
      final item = (section['items'] as List).first as Map<String, Object?>;
      item['config'] = config;
      final decoded = FormDefinitionDto.fromJson(json).toDomain();
      final encoded = FormDefinitionDto.fromDomain(decoded).toJson();
      final encodedSection = (encoded['sections'] as List).first as Map<String, Object?>;
      final encodedItem = (encodedSection['items'] as List).first as Map<String, Object?>;
      expect(encodedItem['config'], config);
    });
  }

  for (final key in ['min_selections', 'max_selections']) {
    for (final value in <Object?>['2', 2.5, true, null]) {
      test('rejects malformed selection limit $key=$value', () {
        final json = FormDefinitionDto.fromDomain(definition).toJson();
        final section = (json['sections'] as List).first as Map<String, Object?>;
        final item = (section['items'] as List).first as Map<String, Object?>;
        item['config'] = {key: value};
        expect(
          () => FormDefinitionDto.fromJson(json).toDomain(),
          throwsA(isA<WireFormatException>()),
        );
      });
    }
  }

  for (final config in [
    <String, Object?>{},
    <String, Object?>{'max_images': 5},
    <String, Object?>{'min_images': 2},
    <String, Object?>{'min_images': 2, 'max_images': 5},
  ]) {
    test('round-trips gallery image limits without inventing defaults $config', () {
      final json = FormDefinitionDto.fromDomain(definition).toJson();
      final section = (json['sections'] as List).first as Map<String, Object?>;
      final item = (section['items'] as List).first as Map<String, Object?>;
      item['kind'] = 'gallery';
      item['options'] = <Object?>[];
      item['config'] = config;
      final decoded = FormDefinitionDto.fromJson(json).toDomain();
      expect(FormDefinitionDto.fromDomain(decoded).toJson(), json);
    });
  }

  test('normalizes integral gallery image numbers without changing their values', () {
    final json = FormDefinitionDto.fromDomain(definition).toJson();
    final section = (json['sections'] as List).first as Map<String, Object?>;
    final item = (section['items'] as List).first as Map<String, Object?>;
    item['kind'] = 'gallery';
    item['options'] = <Object?>[];
    item['config'] = {'min_images': 2.0, 'max_images': 5.0};
    final decoded = FormDefinitionDto.fromJson(json).toDomain();
    final config = decoded.sections.first.items.first.config;
    expect(config.minImages, 2);
    expect(config.maxImages, 5);
    final encoded = FormDefinitionDto.fromDomain(decoded).toJson();
    final encodedSection = (encoded['sections'] as List).first as Map<String, Object?>;
    final encodedItem = (encodedSection['items'] as List).first as Map<String, Object?>;
    final encodedConfig = encodedItem['config'] as Map<String, Object?>;
    expect(encodedConfig, {'min_images': 2, 'max_images': 5});
    expect(encodedConfig['min_images'], isA<int>());
    expect(encodedConfig['max_images'], isA<int>());
  });

  for (final key in ['min_images', 'max_images']) {
    for (final value in <Object?>[
      '2',
      2.5,
      true,
      null,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      0,
      -1,
      6,
    ]) {
      test('rejects malformed image limit $key=$value as a wire error', () {
        final json = FormDefinitionDto.fromDomain(definition).toJson();
        final section = (json['sections'] as List).first as Map<String, Object?>;
        final item = (section['items'] as List).first as Map<String, Object?>;
        item['kind'] = 'gallery';
        item['options'] = <Object?>[];
        item['config'] = {key: value};
        expect(() => FormDefinitionDto.fromJson(json), throwsA(isA<WireFormatException>()));
      });
    }
  }

  test('rejects unknown keys at the top-level and nested boundaries', () {
    final json = FormDefinitionDto.fromDomain(definition).toJson();
    expect(
      () => FormDefinitionDto.fromJson({...json, 'admin': true}),
      throwsA(isA<WireFormatException>()),
    );

    final sections = List<Map<String, Object?>>.from(json['sections']! as List<Object?>);
    sections[0] = {...sections[0], 'unexpected': 'value'};
    expect(
      () => FormDefinitionDto.fromJson({...json, 'sections': sections}),
      throwsA(isA<WireFormatException>()),
    );
  });

  test('rejects an unknown enum value', () {
    final json = FormDefinitionDto.fromDomain(definition).toJson();
    expect(
      () => FormDefinitionDto.fromJson({...json, 'kind': 'survey'}),
      throwsA(isA<WireFormatException>()),
    );
  });
}
