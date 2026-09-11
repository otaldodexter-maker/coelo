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

  /// P16 (ADR 0034, Decisoes 9, 10 e 12): pergunta de Local. As opcoes sao
  /// resolvidas pelo servidor a partir do catalogo de Locais ativos da
  /// instituicao ao salvar o rascunho; o cliente nunca as autora.
  location,
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
    this.minDate,
    this.maxDate,
    this.maxLength,
    this.minSelections,
    this.maxSelections,
    this.decimalPlaces,
    this.currency,
    this.scaleMin,
    this.scaleMax,
    this.scaleMinLabel,
    this.scaleMaxLabel,
    this.allowCamera,
    this.allowExisting,
    this.minImages,
    this.maxImages,
  });

  final num? minValue;
  final num? maxValue;
  final DateTime? minDate;
  final DateTime? maxDate;
  final int? maxLength;
  final int? minSelections;
  final int? maxSelections;
  final int? decimalPlaces;
  final String? currency;
  final int? scaleMin;
  final int? scaleMax;
  final String? scaleMinLabel;
  final String? scaleMaxLabel;
  final bool? allowCamera;
  final bool? allowExisting;
  final int? minImages;
  final int? maxImages;
}

/// One representation for how many options a multiple choice accepts.
///
/// The server refuses a count outside the authored range with a
/// `check_violation`, mirroring `coalesce(min_selections, 1)` and
/// `coalesce(max_selections, 50)`. Those defaults are mirrored here so the
/// person is told before the command leaves, instead of collecting a draft
/// that can never be sent.
abstract final class FormSelectionLimits {
  static const _serverDefaultMinimum = 1;
  static const _serverDefaultMaximum = 50;

  static int minimum(FormItemConfig config) => config.minSelections ?? _serverDefaultMinimum;

  static int maximum(FormItemConfig config) => config.maxSelections ?? _serverDefaultMaximum;

  static String _options(int count) => count == 1 ? '1 opção' : '$count opções';

  /// The sentence that announces the rule BEFORE the person chooses.
  ///
  /// Null when the author declared nothing: announcing the server's ceiling of
  /// fifty on a question that never mentions a limit is noise, and it is not a
  /// rule of this form.
  static String? hint(FormItemConfig config) {
    final low = config.minSelections;
    final high = config.maxSelections;
    if (low == null && high == null) return null;
    if (low != null && high != null) {
      return 'Escolha ao menos ${_options(low)} e no máximo ${_options(high)}.';
    }
    if (low != null) return 'Escolha ao menos ${_options(low)}.';
    return 'Escolha no máximo ${_options(high!)}.';
  }

  /// Why this count cannot be sent, or null when it can.
  ///
  /// An empty answer returns null on purpose: not having answered is a matter
  /// of whether the question is required, and saying "escolha ao menos duas"
  /// on a question the person is allowed to skip would be wrong.
  static String? violation(FormItemConfig config, int count) {
    if (count == 0) return null;
    if (count < minimum(config)) return 'Escolha ao menos ${_options(minimum(config))}.';
    if (count > maximum(config)) return 'Escolha no máximo ${_options(maximum(config))}.';
    return null;
  }
}

/// One representation for the numeric and text limits of a form item.
///
/// Money travels in minor units everywhere: in the authored `minValue`/
/// `maxValue`, in the stored [FormMoneyValue] and in the comparison below.
/// The other numeric kinds travel as plain numbers. Authoring and answering
/// share this guard so a limit cannot be written in one unit and checked in
/// another.
abstract final class FormNumericLimits {
  static const _minorUnitsPerUnit = 100;

  /// The server refuses short text above this when the item declares no
  /// maximum. Mirrored here so the person is told before the command leaves.
  static const _serverDefaultTextLength = 1000;

  static bool isNumeric(FormItemKind kind) =>
      kind == FormItemKind.integer || kind == FormItemKind.decimal || kind == FormItemKind.money;

  /// Reads civil notation (`10,50`) into the item's own unit.
  /// Money yields minor units, so `10,50` becomes `1050`.
  static num? parse(FormItemKind kind, String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    if (kind == FormItemKind.integer) return int.tryParse(normalized);
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) return null;
    if (kind != FormItemKind.money) return parsed;
    final minorUnits = parsed * _minorUnitsPerUnit;
    return minorUnits.isFinite ? minorUnits.round() : null;
  }

  /// Writes the item's own unit back into civil notation, the same notation
  /// the author types: a comma separates the decimals.
  static String format(FormItemKind kind, num value) {
    if (kind != FormItemKind.money) return '$value'.replaceFirst('.', ',');
    final negative = value < 0;
    final minorUnits = value.abs().round();
    final units = minorUnits ~/ _minorUnitsPerUnit;
    final cents = (minorUnits % _minorUnitsPerUnit).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$units,$cents';
  }

  /// Non-null when [value], already in the item's own unit, falls outside the
  /// authored range.
  static String? violation(FormItemKind kind, FormItemConfig config, num value) {
    if (config.minValue case final minimum? when value < minimum) {
      return 'O valor mínimo é ${format(kind, minimum)}.';
    }
    if (config.maxValue case final maximum? when value > maximum) {
      return 'O valor máximo é ${format(kind, maximum)}.';
    }
    return null;
  }

  /// Non-null when [value] is longer than the effective maximum length.
  ///
  /// Counts code points, the way Postgres `char_length` does. Counting UTF-16
  /// units would refuse a text the server accepts, one unit early per emoji.
  static String? textViolation(FormItemConfig config, String value) {
    final maximum = config.maxLength ?? _serverDefaultTextLength;
    if (value.runes.length > maximum) return 'O máximo é $maximum caracteres.';
    return null;
  }
}

final class FormOption {
  const FormOption({
    required this.id,
    required this.label,
    required this.position,
    this.locationId,
    this.locationStatus,
    this.locationAvailable,
  });

  final String id;
  final String label;
  final int position;

  /// Snapshot do Local congelado na opcao (somente itens `location`).
  final String? locationId;
  final String? locationStatus;

  /// Leitura viva do catalogo: false quando o Local foi revogado depois do
  /// snapshot. Null fora de itens `location`.
  final bool? locationAvailable;

  /// Uma opcao de Local revogada nao pode ser escolhida (Decisao 12).
  bool get isSelectable => locationAvailable != false;
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
