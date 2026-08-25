sealed class FormAnswerValue {
  const FormAnswerValue();
}

final class FormShortTextValue extends FormAnswerValue {
  const FormShortTextValue(this.value);
  final String value;
}

final class FormIntegerValue extends FormAnswerValue {
  const FormIntegerValue(this.value);
  final int value;
}

final class FormDecimalValue extends FormAnswerValue {
  const FormDecimalValue(this.value);
  final double value;
}

final class FormMoneyValue extends FormAnswerValue {
  const FormMoneyValue(this.minorUnits);
  final int minorUnits;
}

final class FormDateValue extends FormAnswerValue {
  const FormDateValue(this.value);
  final DateTime value;
}

final class FormYesNoValue extends FormAnswerValue {
  const FormYesNoValue(this.value);
  final bool value;
}

final class FormChoiceValue extends FormAnswerValue {
  const FormChoiceValue(this.optionIds);
  final Set<String> optionIds;
}

final class FormScaleValue extends FormAnswerValue {
  const FormScaleValue(this.value);
  final int value;
}

final class FormAssetValue extends FormAnswerValue {
  const FormAssetValue(this.assetIds);
  final List<String> assetIds;
}

enum FormAnswerKind {
  shortText,
  integer,
  decimal,
  money,
  date,
  yesNo,
  singleChoice,
  multipleChoice,
  scale,
  photo,
  gallery,
}

final class FormAnswer {
  const FormAnswer._({required this.itemId, required this.kind, required this.value});

  FormAnswer.shortText({required String itemId, required String value})
    : this._(itemId: itemId, kind: FormAnswerKind.shortText, value: FormShortTextValue(value));

  FormAnswer.integer({required String itemId, required int value})
    : this._(itemId: itemId, kind: FormAnswerKind.integer, value: FormIntegerValue(value));

  FormAnswer.decimal({required String itemId, required double value})
    : this._(itemId: itemId, kind: FormAnswerKind.decimal, value: FormDecimalValue(value));

  FormAnswer.money({required String itemId, required int minorUnits})
    : this._(itemId: itemId, kind: FormAnswerKind.money, value: FormMoneyValue(minorUnits));

  FormAnswer.date({required String itemId, required DateTime value})
    : this._(itemId: itemId, kind: FormAnswerKind.date, value: FormDateValue(value));

  FormAnswer.yesNo({required String itemId, required bool value})
    : this._(itemId: itemId, kind: FormAnswerKind.yesNo, value: FormYesNoValue(value));

  FormAnswer.singleChoice({required String itemId, required String optionId})
    : this._(itemId: itemId, kind: FormAnswerKind.singleChoice, value: FormChoiceValue({optionId}));

  FormAnswer.multipleChoice({required String itemId, required Set<String> optionIds})
    : this._(
        itemId: itemId,
        kind: FormAnswerKind.multipleChoice,
        value: FormChoiceValue(optionIds),
      );

  FormAnswer.scale({required String itemId, required int value})
    : this._(itemId: itemId, kind: FormAnswerKind.scale, value: FormScaleValue(value));

  FormAnswer.photo({required String itemId, required List<String> assetIds})
    : this._(itemId: itemId, kind: FormAnswerKind.photo, value: FormAssetValue(assetIds));

  FormAnswer.gallery({required String itemId, required List<String> assetIds})
    : this._(itemId: itemId, kind: FormAnswerKind.gallery, value: FormAssetValue(assetIds));

  final String itemId;
  final FormAnswerKind kind;
  final FormAnswerValue value;
}

enum FormResponseDraftStatus { draft, submitted }

final class FormResponseDraft {
  FormResponseDraft({
    required this.id,
    required this.occurrenceId,
    required this.status,
    required Map<String, FormAnswer> answers,
    required this.managementVersion,
  }) : answers = Map.unmodifiable(answers);

  final String id;
  final String occurrenceId;
  final FormResponseDraftStatus status;
  final Map<String, FormAnswer> answers;
  final int managementVersion;
}

final class FormResponseRevision {
  FormResponseRevision({
    required this.number,
    required this.createdAt,
    required Map<String, FormAnswer> answers,
  }) : answers = Map.unmodifiable(answers);

  final int number;
  final DateTime createdAt;
  final Map<String, FormAnswer> answers;
}

final class FormAsset {
  const FormAsset({
    required this.id,
    required this.itemId,
    required this.mimeType,
    required this.byteLength,
  });

  final String id;
  final String itemId;
  final String mimeType;
  final int byteLength;
}
