import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  const itemId = '10000000-0000-4000-8000-000000000001';
  const assetId = '10000000-0000-4000-8000-000000000002';
  const versionId = '10000000-0000-4000-8000-000000000003';
  Map<String, Object?> mediaProjection({String bindingItem = itemId}) => {
    'definition': FormDefinitionDto.fromDomain(
      FormDefinition(
        id: 'form-1',
        institutionId: 'institution-1',
        title: 'Pesquisa',
        kind: FormKind.form,
        identityMode: FormIdentityMode.identified,
        responseUnit: FormResponseUnit.person,
        sections: [
          FormSection(
            id: 'section-1',
            title: 'Perguntas',
            position: 0,
            items: [
              FormItem(id: itemId, kind: FormItemKind.shortText, label: 'Pergunta', position: 0),
            ],
          ),
        ],
      ),
    ).toJson(),
    'application': null,
    'media_context': {
      'form_version_id': versionId,
      'question_images': [
        {
          'item_id': bindingItem,
          'asset_id': assetId,
          'status': 'pending',
          'mime_type': 'image/png',
          'position': 0,
        },
      ],
    },
  };
  test('editor media context preserves pending state without treating it as a ready image', () {
    final decoded = FormEditorProjectionDto.fromJson(mediaProjection());
    expect(decoded.toDomain().mediaContext!.formVersionId, versionId);
    expect(decoded.toDomain().mediaContext!.questionImages.single.isReady, isFalse);
    expect(decoded.toJson(), mediaProjection());
  });
  test('editor rejects image bindings outside the displayed definition', () {
    expect(
      () => FormEditorProjectionDto.fromJson(mediaProjection(bindingItem: assetId)),
      throwsA(isA<WireFormatException>()),
    );
  });
  test('editor media context never accepts a private storage key', () {
    final json = mediaProjection();
    (json['media_context']! as Map<String, Object?>)['object_key'] = 'private';
    expect(() => FormEditorProjectionDto.fromJson(json), throwsA(isA<WireFormatException>()));
  });

  test('editor projection DTO restores definition and normalized application', () {
    final definition = _definition();
    final application = _application();
    final json = FormEditorProjectionDto.fromDomain(
      FormEditorProjection(definition: definition, application: application),
    ).toJson();
    final decoded = FormEditorProjectionDto.fromJson(json).toDomain();

    expect(decoded.definition.title, 'Pesquisa');
    expect(decoded.application?.audienceRules.single.targetId, 'group-1');
    expect(decoded.application?.schedules.single.reminders.single.kind, FormReminderKind.onOpen);
  });

  test('editor projection DTO accepts no application and rejects unknown keys', () {
    final json = FormEditorProjectionDto.fromDomain(
      FormEditorProjection(definition: _definition()),
    ).toJson();

    expect(FormEditorProjectionDto.fromJson(json).toDomain().application, isNull);
    expect(
      () => FormEditorProjectionDto.fromJson({...json, 'person_id': 'forged'}),
      throwsA(isA<WireFormatException>()),
    );
  });
}

FormDefinition _definition() => FormDefinition(
  id: 'form-1',
  institutionId: 'institution-1',
  kind: FormKind.form,
  identityMode: FormIdentityMode.identified,
  responseUnit: FormResponseUnit.person,
  title: 'Pesquisa',
  sections: const [],
);

FormApplication _application() => FormApplication(
  id: 'application-1',
  formId: 'form-1',
  institutionId: 'institution-1',
  name: 'Famílias',
  audienceRules: const [
    FormAudienceRule(
      id: 'rule-1',
      kind: FormAudienceRuleKind.group,
      mode: FormAudienceRuleMode.include,
      targetId: 'group-1',
    ),
  ],
  schedules: [
    FormApplicationSchedule(
      id: 'schedule-1',
      schedule: FormSchedule(
        startsAtLocal: DateTime(2026, 10, 30, 9),
        timeZone: 'America/Sao_Paulo',
        recurrence: const FormRecurrence.once(),
        end: const FormScheduleEnd.never(),
      ),
      reminders: const [FormReminder(kind: FormReminderKind.onOpen)],
      managementVersion: 2,
    ),
  ],
  managementVersion: 3,
);
