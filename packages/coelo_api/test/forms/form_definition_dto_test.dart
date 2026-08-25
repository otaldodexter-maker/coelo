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
