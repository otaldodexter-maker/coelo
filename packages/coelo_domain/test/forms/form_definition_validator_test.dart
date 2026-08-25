import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  test('accepts an ordered definition at the approved limits', () {
    final definition = FormDefinition(
      id: 'form-1',
      institutionId: 'institution-1',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Ficha de saúde',
      sections: [
        FormSection(
          id: 'section-1',
          title: 'Identificação',
          position: 0,
          items: [
            FormItem(
              id: 'item-1',
              kind: FormItemKind.shortText,
              label: 'Nome preferido',
              position: 0,
              isRequired: true,
            ),
          ],
        ),
      ],
    );

    expect(const FormDefinitionValidator().validate(definition), isEmpty);
  });

  test('rejects structural limits, invalid sources, cycles, and depth above four', () {
    FormItem conditional(String id, String source) => FormItem(
      id: id,
      kind: FormItemKind.shortText,
      label: id,
      position: int.parse(id.substring(1)),
      conditions: [FormCondition.yesNo(sourceItemId: source, expected: true)],
    );

    final items = [
      FormItem(id: 'q0', kind: FormItemKind.yesNo, label: 'Início', position: 0),
      conditional('q1', 'q0'),
      conditional('q2', 'q1'),
      conditional('q3', 'q2'),
      conditional('q4', 'q3'),
      conditional('q5', 'q4'),
      conditional('q6', 'q6'),
      FormItem(
        id: 'q7',
        kind: FormItemKind.shortText,
        label: 'Fonte inválida',
        position: 7,
        conditions: [FormCondition.yesNo(sourceItemId: 'q1', expected: true)],
      ),
    ];
    final definition = FormDefinition(
      id: 'form-1',
      institutionId: 'institution-1',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Inválido',
      sections: [FormSection(id: 's1', title: 'Seção', position: 0, items: items)],
    );

    final codes = const FormDefinitionValidator()
        .validate(definition)
        .map((issue) => issue.code)
        .toSet();
    expect(codes, contains(FormValidationCode.conditionCycle));
    expect(codes, contains(FormValidationCode.conditionDepthExceeded));
    expect(codes, contains(FormValidationCode.invalidConditionSourceKind));
  });

  test('allows conditions only from yes/no and choice items', () {
    final definition = FormDefinition(
      id: 'form-1',
      institutionId: 'institution-1',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Condições',
      sections: [
        FormSection(
          id: 's1',
          title: 'Seção',
          position: 0,
          items: [
            FormItem(id: 'source', kind: FormItemKind.shortText, label: 'Texto', position: 0),
            FormItem(
              id: 'target',
              kind: FormItemKind.information,
              label: 'Info',
              position: 1,
              conditions: [FormCondition.yesNo(sourceItemId: 'source', expected: true)],
            ),
          ],
        ),
      ],
    );

    expect(
      const FormDefinitionValidator().validate(definition).map((issue) => issue.code),
      contains(FormValidationCode.invalidConditionSourceKind),
    );
  });

  test('quick poll requires a short intent and exactly one answerable question', () {
    final definition = FormDefinition(
      id: 'quick-poll-1',
      institutionId: 'institution-1',
      kind: FormKind.quickPoll,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Pulso da semana',
      description: 'x' * 281,
      sections: [
        FormSection(
          id: 'section-1',
          title: 'Pergunta principal',
          position: 0,
          items: [
            FormItem(id: 'item-1', kind: FormItemKind.yesNo, label: 'Tudo bem?', position: 0),
            FormItem(id: 'item-2', kind: FormItemKind.information, label: 'Obrigado', position: 1),
          ],
        ),
      ],
    );

    final codes = const FormDefinitionValidator()
        .validate(definition)
        .map((issue) => issue.code)
        .toSet();

    expect(codes, contains(FormValidationCode.quickPollIntentTooLong));
    expect(codes, contains(FormValidationCode.quickPollRequiresOneQuestion));
  });
}
