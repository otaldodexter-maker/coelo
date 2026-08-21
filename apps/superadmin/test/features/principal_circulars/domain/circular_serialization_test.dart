import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_serialization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips ordered Circular blocks', () {
    const draft = CircularDraft(
      id: '00000000-0000-0000-0000-000000000001',
      title: 'Circular',
      responsePolicy: CircularResponsePolicy.perChildAnyGuardian,
      expectedVersion: 4,
      blocks: [
        CircularTextBlock(id: '00000000-0000-0000-0000-000000000010', text: 'Texto'),
        CircularQuestionBlock(
          id: '00000000-0000-0000-0000-000000000020',
          prompt: 'Escolha',
          kind: CircularQuestionKind.multipleChoice,
          required: true,
          options: [
            CircularQuestionOption(id: '00000000-0000-0000-0000-000000000021', label: 'A'),
            CircularQuestionOption(id: '00000000-0000-0000-0000-000000000022', label: 'B'),
          ],
        ),
      ],
    );

    final json = CircularDraftCodec.toJson(draft);
    final decoded = CircularDraftCodec.fromJson(json);

    expect(decoded.title, draft.title);
    expect(decoded.responsePolicy, CircularResponsePolicy.perChildAnyGuardian);
    expect(decoded.blocks, hasLength(2));
    expect((decoded.blocks.last as CircularQuestionBlock).options.last.label, 'B');
  });

  test('rejects an unknown block kind instead of guessing', () {
    expect(
      () => CircularDraftCodec.fromJson({
        'id': 'circular',
        'title': 'Circular',
        'version': 1,
        'response_policy': 'per_person',
        'blocks': [
          {'id': 'block', 'kind': 'form'},
        ],
      }),
      throwsFormatException,
    );
  });
}
