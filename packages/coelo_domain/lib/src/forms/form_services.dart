import 'form_answers.dart';
import 'form_definition.dart';

final class FormVisibilityEvaluator {
  const FormVisibilityEvaluator();

  bool isVisible({
    required List<FormCondition> conditions,
    required Map<String, FormAnswer> answers,
  }) {
    if (conditions.isEmpty) return true;
    return conditions.any((condition) {
      final answer = answers[condition.sourceItemId]?.value;
      return switch ((condition.kind, answer)) {
        (FormConditionKind.yesNo, FormYesNoValue value) => value.value == condition.expectedYesNo,
        (FormConditionKind.choice, FormChoiceValue value) => value.optionIds.any(
          condition.optionIds.contains,
        ),
        _ => false,
      };
    });
  }
}

final class FormAnswerNormalizer {
  const FormAnswerNormalizer();

  Map<String, FormAnswer> normalize({
    required Map<String, FormAnswer> answers,
    required Set<String> visibleItemIds,
  }) {
    return Map.unmodifiable({
      for (final entry in answers.entries)
        if (visibleItemIds.contains(entry.key)) entry.key: _normalizeAnswer(entry.value),
    });
  }

  FormAnswer _normalizeAnswer(FormAnswer answer) {
    final value = answer.value;
    if (value is FormShortTextValue) {
      return FormAnswer.shortText(itemId: answer.itemId, value: value.value.trim());
    }
    return answer;
  }
}
