import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircularDraft', () {
    test('accepts ordered text, media and question blocks', () {
      final draft = CircularDraft(
        id: 'circular-1',
        title: 'Renovação de matrícula',
        blocks: const [
          CircularTextBlock(id: 'text-1', text: 'Queridos responsáveis,'),
          CircularMediaBlock(id: 'media-1', assetIds: ['asset-1']),
          CircularQuestionBlock(
            id: 'question-1',
            prompt: 'A matrícula será renovada?',
            kind: CircularQuestionKind.singleChoice,
            required: true,
            options: [
              CircularQuestionOption(id: 'yes', label: 'Sim'),
              CircularQuestionOption(id: 'no', label: 'Não'),
            ],
          ),
        ],
      );

      expect(draft.validate(), isEmpty);
      expect(draft.blocks.map((block) => block.id), ['text-1', 'media-1', 'question-1']);
    });

    test('enforces every shared circular limit', () {
      final draft = CircularDraft(
        id: 'circular-1',
        title: 'x' * (CircularLimits.titleCharacters + 1),
        blocks: [
          CircularTextBlock(id: 'text-1', text: 'x' * (CircularLimits.bodyCharacters + 1)),
          const CircularMediaBlock(id: 'media-1', assetIds: ['1', '2', '3', '4', '5']),
          ...List.generate(
            CircularLimits.questions + 1,
            (index) => CircularQuestionBlock(
              id: 'q-$index',
              prompt: 'x' * (CircularLimits.questionCharacters + 1),
              kind: CircularQuestionKind.multipleChoice,
              required: false,
              options: const [CircularQuestionOption(id: 'only', label: 'Única')],
            ),
          ),
        ],
      );

      expect(
        draft.validate().map((issue) => issue.code),
        containsAll(<CircularValidationCode>{
          CircularValidationCode.titleTooLong,
          CircularValidationCode.bodyTooLong,
          CircularValidationCode.tooManyFiles,
          CircularValidationCode.tooManyQuestions,
          CircularValidationCode.questionTooLong,
          CircularValidationCode.invalidOptionCount,
        }),
      );
    });

    test('requires a title and unique block and option identifiers', () {
      const draft = CircularDraft(
        id: 'circular-1',
        title: ' ',
        blocks: [
          CircularTextBlock(id: 'duplicate', text: 'Primeiro'),
          CircularTextBlock(id: 'duplicate', text: 'Segundo'),
          CircularQuestionBlock(
            id: 'question',
            prompt: 'Escolha',
            kind: CircularQuestionKind.singleChoice,
            required: false,
            options: [
              CircularQuestionOption(id: 'duplicate-option', label: 'A'),
              CircularQuestionOption(id: 'duplicate-option', label: 'B'),
            ],
          ),
        ],
      );

      expect(
        draft.validate().map((issue) => issue.code),
        containsAll(<CircularValidationCode>{
          CircularValidationCode.titleRequired,
          CircularValidationCode.duplicateBlockId,
          CircularValidationCode.duplicateOptionId,
        }),
      );
    });
  });

  test('Acontece and Circular character limits stay independent', () {
    expect(HappensContentLimits.bodyCharacters, 2200);
    expect(CircularLimits.bodyCharacters, 10000);
  });

  test('supports all approved response policies', () {
    expect(CircularResponsePolicy.values, {
      CircularResponsePolicy.perPerson,
      CircularResponsePolicy.perChildAnyGuardian,
      CircularResponsePolicy.perChildEachGuardian,
      CircularResponsePolicy.perStaffMember,
    });
  });
}
