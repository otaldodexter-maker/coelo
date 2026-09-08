import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/supabase_forms_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the submitted graph and explicit identity without current editor lookup', () async {
    final backend = _Backend(_projection());
    final result = await SupabaseFormsApi(backend).getResponseDetail('response-1');
    expect(backend.calls, ['superadmin_forms_response_detail_v2']);
    expect(result.summary.identityMode, FormIdentityMode.anonymous);
    expect(result.summary.respondentLabel, isNull);
    expect(result.summary.submittedAt, isNull);
    final version = result.originalVersion!;
    expect(
      (version.id, version.formId, version.number, version.isPublished),
      ('version-original', 'form-1', 2, true),
    );
    expect(version.sections.single.items.first.label, 'Pergunta original');
    expect(version.sections.single.items.first.options.single.label, 'Opção original');
    expect((result.answers['question-1']!.value as FormChoiceValue).optionIds, {'option-1'});
  });

  test('rejects malformed or unrelated original graph and typed answers', () async {
    var caseIndex = 0;
    for (final mutate in <void Function(Map<String, Object?>)>[
      (value) => value['form_id'] = 'other-form',
      (value) => value['form_version_number'] = 0,
      (value) => value['form_version_number'] = 1.5,
      (value) => value.remove('form_version_number'),
      (value) => value['form_version_state'] = 'unknown',
      (value) => value['definition'] = {'untrusted': true},
      (value) => (value['definition']! as Map)['identity_mode'] = 'identified',
      (value) => value['answers'] = [
        FormAnswerDto.fromDomain(
          FormAnswer.shortText(itemId: 'unknown-item', value: 'secret'),
        ).toJson(),
      ],
      (value) => value['answers'] = [
        FormAnswerDto.fromDomain(FormAnswer.integer(itemId: 'question-1', value: 42)).toJson(),
      ],
      (value) => value['answers'] = [
        FormAnswerDto.fromDomain(
          FormAnswer.singleChoice(itemId: 'question-1', optionId: 'foreign-option'),
        ).toJson(),
      ],
      (value) {
        final section = ((value['definition']! as Map)['sections']! as List).single as Map;
        section['items'] = [...section['items']! as List, (section['items']! as List).first];
      },
    ]) {
      final payload = _projection();
      mutate(payload);
      await expectLater(
        SupabaseFormsApi(_Backend(payload)).getResponseDetail('response-1'),
        throwsA(
          isA<FormApiException>().having(
            (error) => error.kind,
            'kind',
            FormApiFailureKind.unavailable,
          ),
        ),
        reason: 'malformed graph case ${caseIndex++}',
      );
    }
  });

  test('does not invent original graph for an older response projection', () async {
    final payload = _projection()..remove('definition');
    final result = await SupabaseFormsApi(_Backend(payload)).getResponseDetail('response-1');
    expect(result.originalVersion, isNull);
    expect(result.answers, isNotEmpty);
  });
}

Map<String, Object?> _projection() => {
  'id': 'response-1',
  'form_id': 'form-1',
  'occurrence_id': 'occurrence-1',
  'form_version_id': 'version-original',
  'form_version_number': 2,
  'form_version_state': 'superseded',
  'identity_mode': 'anonymous',
  'respondent_label': 'Injected private person',
  'submitted_at': '2026-09-08T15:00:00Z',
  'answers': [
    FormAnswerDto.fromDomain(
      FormAnswer.singleChoice(itemId: 'question-1', optionId: 'option-1'),
    ).toJson(),
  ],
  'definition': FormDefinitionDto.fromDomain(
    FormDefinition(
      id: 'form-1',
      institutionId: 'institution-1',
      kind: FormKind.form,
      identityMode: FormIdentityMode.anonymous,
      responseUnit: FormResponseUnit.person,
      title: 'Current title is not claimed as historical',
      sections: [
        FormSection(
          id: 'section-1',
          title: 'Seção original',
          position: 0,
          items: [
            FormItem(
              id: 'question-1',
              kind: FormItemKind.singleChoice,
              label: 'Pergunta original',
              position: 0,
              options: const [FormOption(id: 'option-1', label: 'Opção original', position: 0)],
            ),
          ],
        ),
      ],
    ),
  ).toJson(),
};

final class _Backend implements FormsBackendGateway {
  _Backend(this.payload);
  final Map<String, Object?> payload;
  final calls = <String>[];
  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    calls.add(functionName);
    return {'ok': true, 'data': payload, 'error': null};
  }

  @override
  Future<Object?> media(Map<String, Object?> envelope) => throw StateError('Unexpected media call');
}
