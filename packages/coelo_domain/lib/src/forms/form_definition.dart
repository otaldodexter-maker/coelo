enum FormKind { form, quickPoll }

enum FormStatus { draft, published, archived }

/// A read-only directory situation derived from the form lifecycle and its
/// occurrences. It deliberately does not persist alongside [FormStatus].
enum FormOperationalStatus { draft, scheduled, active, closed, archived }

enum FormIdentityMode { identified, anonymous }

enum FormResponseUnit { person, childFamilyContext }

enum FormItemKind {
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
  information,
}

enum FormConditionKind { yesNo, choice }

final class FormDefinition {
  FormDefinition({
    required this.id,
    required this.institutionId,
    required this.kind,
    required this.identityMode,
    required this.responseUnit,
    required this.title,
    this.description,
    required List<FormSection> sections,
    this.status = FormStatus.draft,
    this.managementVersion = 0,
  }) : sections = List.unmodifiable(sections);

  final String id;
  final String institutionId;
  final FormKind kind;
  final FormIdentityMode identityMode;
  final FormResponseUnit responseUnit;
  final String title;
  final String? description;
  final FormStatus status;
  final int managementVersion;
  final List<FormSection> sections;
}

final class FormVersion {
  FormVersion({
    required this.id,
    required this.formId,
    required this.number,
    required List<FormSection> sections,
    required this.isPublished,
  }) : sections = List.unmodifiable(sections);

  final String id;
  final String formId;
  final int number;
  final List<FormSection> sections;
  final bool isPublished;
}

final class FormSection {
  FormSection({
    required this.id,
    required this.title,
    this.description,
    required this.position,
    required List<FormItem> items,
  }) : items = List.unmodifiable(items);

  final String id;
  final String title;
  final String? description;
  final int position;
  final List<FormItem> items;
}

final class FormItem {
  FormItem({
    required this.id,
    required this.kind,
    required this.label,
    this.helpText,
    required this.position,
    this.isRequired = false,
    this.config = const FormItemConfig(),
    List<FormOption> options = const [],
    List<FormCondition> conditions = const [],
  }) : options = List.unmodifiable(options),
       conditions = List.unmodifiable(conditions);

  final String id;
  final FormItemKind kind;
  final String label;
  final String? helpText;
  final int position;
  final bool isRequired;
  final FormItemConfig config;
  final List<FormOption> options;
  final List<FormCondition> conditions;
}

final class FormItemConfig {
  const FormItemConfig({
    this.minValue,
    this.maxValue,
    this.decimalPlaces,
    this.currency,
    this.scaleMin,
    this.scaleMax,
    this.scaleMinLabel,
    this.scaleMaxLabel,
    this.allowCamera,
    this.allowExisting,
    this.maxImages,
  });

  final num? minValue;
  final num? maxValue;
  final int? decimalPlaces;
  final String? currency;
  final int? scaleMin;
  final int? scaleMax;
  final String? scaleMinLabel;
  final String? scaleMaxLabel;
  final bool? allowCamera;
  final bool? allowExisting;
  final int? maxImages;
}

final class FormOption {
  const FormOption({required this.id, required this.label, required this.position});

  final String id;
  final String label;
  final int position;
}

final class FormCondition {
  const FormCondition.yesNo({required this.sourceItemId, required bool expected})
    : kind = FormConditionKind.yesNo,
      expectedYesNo = expected,
      optionIds = const {};

  const FormCondition.choice({required this.sourceItemId, required this.optionIds})
    : kind = FormConditionKind.choice,
      expectedYesNo = null;

  final String sourceItemId;
  final FormConditionKind kind;
  final bool? expectedYesNo;
  final Set<String> optionIds;
}

enum FormValidationCode {
  emptyTitle,
  sectionLimitExceeded,
  itemLimitExceeded,
  optionLimitExceeded,
  duplicateId,
  invalidPosition,
  invalidConditionSource,
  invalidConditionSourceKind,
  conditionCycle,
  conditionDepthExceeded,
  quickPollIntentRequired,
  quickPollIntentTooLong,
  quickPollRequiresOneQuestion,
}

final class FormValidationIssue {
  const FormValidationIssue(this.code, {this.entityId});

  final FormValidationCode code;
  final String? entityId;
}

final class FormDefinitionLimits {
  const FormDefinitionLimits._();

  static const maxSections = 20;
  static const maxItems = 200;
  static const maxOptionsPerItem = 50;
  static const maxConditionDepth = 4;
  static const maxImagesPerQuestion = 5;
  static const quickPollIntentMaxLength = 280;
}

final class FormDefinitionValidator {
  const FormDefinitionValidator();

  List<FormValidationIssue> validate(FormDefinition definition) {
    final issues = <FormValidationIssue>[];
    if (definition.title.trim().isEmpty) {
      issues.add(const FormValidationIssue(FormValidationCode.emptyTitle));
    }
    if (definition.sections.length > FormDefinitionLimits.maxSections) {
      issues.add(const FormValidationIssue(FormValidationCode.sectionLimitExceeded));
    }

    final ids = <String>{};
    final items = <String, FormItem>{};
    var itemCount = 0;
    for (var sectionIndex = 0; sectionIndex < definition.sections.length; sectionIndex++) {
      final section = definition.sections[sectionIndex];
      if (!ids.add(section.id)) {
        issues.add(FormValidationIssue(FormValidationCode.duplicateId, entityId: section.id));
      }
      if (section.position != sectionIndex) {
        issues.add(FormValidationIssue(FormValidationCode.invalidPosition, entityId: section.id));
      }
      itemCount += section.items.length;
      for (var itemIndex = 0; itemIndex < section.items.length; itemIndex++) {
        final item = section.items[itemIndex];
        if (!ids.add(item.id) || items.containsKey(item.id)) {
          issues.add(FormValidationIssue(FormValidationCode.duplicateId, entityId: item.id));
        }
        items[item.id] = item;
        if (item.position != itemIndex) {
          issues.add(FormValidationIssue(FormValidationCode.invalidPosition, entityId: item.id));
        }
        if (item.options.length > FormDefinitionLimits.maxOptionsPerItem) {
          issues.add(
            FormValidationIssue(FormValidationCode.optionLimitExceeded, entityId: item.id),
          );
        }
        for (final option in item.options) {
          if (!ids.add(option.id)) {
            issues.add(FormValidationIssue(FormValidationCode.duplicateId, entityId: option.id));
          }
        }
      }
    }
    if (itemCount > FormDefinitionLimits.maxItems) {
      issues.add(const FormValidationIssue(FormValidationCode.itemLimitExceeded));
    }

    if (definition.kind == FormKind.quickPoll) {
      final intentLength = definition.description?.trim().runes.length ?? 0;
      if (intentLength == 0) {
        issues.add(const FormValidationIssue(FormValidationCode.quickPollIntentRequired));
      } else if (intentLength > FormDefinitionLimits.quickPollIntentMaxLength) {
        issues.add(const FormValidationIssue(FormValidationCode.quickPollIntentTooLong));
      }
      final quickPollItems = definition.sections.expand((section) => section.items).toList();
      if (quickPollItems.length != 1 || quickPollItems.single.kind == FormItemKind.information) {
        issues.add(const FormValidationIssue(FormValidationCode.quickPollRequiresOneQuestion));
      }
    }

    for (final item in items.values) {
      for (final condition in item.conditions) {
        final source = items[condition.sourceItemId];
        if (source == null) {
          issues.add(
            FormValidationIssue(FormValidationCode.invalidConditionSource, entityId: item.id),
          );
          continue;
        }
        if (source.kind != FormItemKind.yesNo &&
            source.kind != FormItemKind.singleChoice &&
            source.kind != FormItemKind.multipleChoice) {
          issues.add(
            FormValidationIssue(FormValidationCode.invalidConditionSourceKind, entityId: item.id),
          );
        }
      }
    }

    final graph = <String, Set<String>>{
      for (final item in items.values)
        item.id: item.conditions.map((condition) => condition.sourceItemId).toSet(),
    };
    for (final item in items.values) {
      final result = _inspectDependencies(item.id, graph, <String>{}, 0);
      if (result.cycle) {
        issues.add(FormValidationIssue(FormValidationCode.conditionCycle, entityId: item.id));
      }
      if (result.depth > FormDefinitionLimits.maxConditionDepth) {
        issues.add(
          FormValidationIssue(FormValidationCode.conditionDepthExceeded, entityId: item.id),
        );
      }
    }
    return List.unmodifiable(issues);
  }

  ({bool cycle, int depth}) _inspectDependencies(
    String itemId,
    Map<String, Set<String>> graph,
    Set<String> path,
    int depth,
  ) {
    if (!path.add(itemId)) return (cycle: true, depth: depth);
    var maximum = depth;
    var cycle = false;
    for (final dependency in graph[itemId] ?? const <String>{}) {
      if (!graph.containsKey(dependency)) continue;
      final result = _inspectDependencies(dependency, graph, {...path}, depth + 1);
      cycle = cycle || result.cycle;
      if (result.depth > maximum) maximum = result.depth;
    }
    return (cycle: cycle, depth: maximum);
  }
}
