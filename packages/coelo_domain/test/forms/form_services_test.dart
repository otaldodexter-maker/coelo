import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  test('visibility keeps multiple-choice branches active independently', () {
    final conditions = [
      FormCondition.choice(sourceItemId: 'source', optionIds: const {'a'}),
      FormCondition.choice(sourceItemId: 'source', optionIds: const {'b'}),
    ];
    final answers = <String, FormAnswer>{
      'source': FormAnswer.multipleChoice(itemId: 'source', optionIds: const {'a', 'b'}),
    };

    expect(
      const FormVisibilityEvaluator().isVisible(conditions: conditions, answers: answers),
      isTrue,
    );
  });

  test('normalizer trims typed values and removes hidden answers', () {
    final normalized = const FormAnswerNormalizer().normalize(
      answers: {
        'name': FormAnswer.shortText(itemId: 'name', value: '  Ana  '),
        'count': FormAnswer.integer(itemId: 'count', value: 3),
        'hidden': FormAnswer.yesNo(itemId: 'hidden', value: true),
      },
      visibleItemIds: const {'name', 'count'},
    );

    expect((normalized['name']!.value as FormShortTextValue).value, 'Ana');
    expect((normalized['count']!.value as FormIntegerValue).value, 3);
    expect(normalized, isNot(contains('hidden')));
  });

  for (final kind in [FormItemKind.photo, FormItemKind.gallery]) {
    test('normalizer omits empty assets and preserves other values $kind', () {
      FormAnswer media(String id, List<String> ids) => kind == FormItemKind.photo
          ? FormAnswer.photo(itemId: id, assetIds: ids)
          : FormAnswer.gallery(itemId: id, assetIds: ids);
      final populated = media('populated', ['asset-a', 'asset-b']);
      final choice = FormAnswer.multipleChoice(itemId: 'choice', optionIds: {});
      final negative = FormAnswer.yesNo(itemId: 'negative', value: false);
      final zero = FormAnswer.integer(itemId: 'zero', value: 0);
      final normalized = const FormAnswerNormalizer().normalize(
        answers: {
          'empty': media('empty', []),
          'populated': populated,
          'choice': choice,
          'negative': negative,
          'zero': zero,
        },
        visibleItemIds: {'empty', 'populated', 'choice', 'negative', 'zero'},
      );
      expect(normalized.keys, ['populated', 'choice', 'negative', 'zero']);
      expect(normalized['populated'], same(populated));
      expect((normalized['populated']!.value as FormAssetValue).assetIds, ['asset-a', 'asset-b']);
      expect(normalized['choice'], same(choice));
      expect(normalized['negative'], same(negative));
      expect(normalized['zero'], same(zero));
    });
  }

  test('weekly schedule is deterministic and carries its IANA timezone', () {
    final schedule = FormSchedule(
      startsAtLocal: DateTime(2026, 10, 30, 9),
      timeZone: 'America/Sao_Paulo',
      recurrence: const FormRecurrence.weekly(
        interval: 1,
        weekdays: {DateTime.monday, DateTime.friday},
      ),
      end: const FormScheduleEnd.afterOccurrences(4),
    );

    final occurrences = const FormScheduleCalculator().next(schedule, limit: 10);

    expect(occurrences.map((value) => value.localDateTime), [
      DateTime(2026, 10, 30, 9),
      DateTime(2026, 11, 2, 9),
      DateTime(2026, 11, 6, 9),
      DateTime(2026, 11, 9, 9),
    ]);
    expect(occurrences.every((value) => value.timeZone == 'America/Sao_Paulo'), isTrue);
  });

  test('monthly last-day recurrence clamps across month boundaries', () {
    final schedule = FormSchedule(
      startsAtLocal: DateTime(2026, 1, 31, 8, 30),
      timeZone: 'America/Sao_Paulo',
      recurrence: const FormRecurrence.monthly(interval: 1, useLastDay: true),
      end: const FormScheduleEnd.afterOccurrences(3),
    );

    expect(
      const FormScheduleCalculator().next(schedule, limit: 10).map((value) => value.localDateTime),
      [DateTime(2026, 1, 31, 8, 30), DateTime(2026, 2, 28, 8, 30), DateTime(2026, 3, 31, 8, 30)],
    );
  });
}
