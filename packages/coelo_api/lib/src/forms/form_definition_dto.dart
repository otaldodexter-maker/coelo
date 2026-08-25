import 'package:coelo_domain/coelo_domain.dart';

import 'form_wire_contracts.dart';

final class FormDefinitionDto {
  const FormDefinitionDto(this.value);

  factory FormDefinitionDto.fromDomain(FormDefinition value) => FormDefinitionDto(value);

  factory FormDefinitionDto.fromJson(Map<String, Object?> json) {
    const context = 'form_definition';
    requireOnlyKeys(json, const {
      'id',
      'institution_id',
      'kind',
      'identity_mode',
      'response_unit',
      'title',
      'description',
      'status',
      'management_version',
      'sections',
    }, context: context);
    return FormDefinitionDto(
      FormDefinition(
        id: requireString(json, 'id', context: context),
        institutionId: requireString(json, 'institution_id', context: context),
        kind: _decodeEnum(requireString(json, 'kind', context: context), _formKinds, 'kind'),
        identityMode: _decodeEnum(
          requireString(json, 'identity_mode', context: context),
          _identityModes,
          'identity_mode',
        ),
        responseUnit: _decodeEnum(
          requireString(json, 'response_unit', context: context),
          _responseUnits,
          'response_unit',
        ),
        title: requireString(json, 'title', context: context),
        description: _nullableString(json, 'description', context),
        status: _decodeEnum(requireString(json, 'status', context: context), _statuses, 'status'),
        managementVersion: requireInt(json, 'management_version', context: context),
        sections: requireList(json, 'sections', context: context)
            .map((value) => _decodeSection(_object(value, 'form_definition.sections')))
            .toList(growable: false),
      ),
    );
  }

  final FormDefinition value;

  FormDefinition toDomain() => value;

  Map<String, Object?> toJson() => {
    'id': value.id,
    'institution_id': value.institutionId,
    'kind': _encodeEnum(value.kind, _formKinds),
    'identity_mode': _encodeEnum(value.identityMode, _identityModes),
    'response_unit': _encodeEnum(value.responseUnit, _responseUnits),
    'title': value.title,
    'description': value.description,
    'status': _encodeEnum(value.status, _statuses),
    'management_version': value.managementVersion,
    'sections': value.sections.map(_encodeSection).toList(growable: false),
  };
}

FormSection _decodeSection(Map<String, Object?> json) {
  const context = 'form_section';
  requireOnlyKeys(json, const {
    'id',
    'title',
    'description',
    'position',
    'items',
  }, context: context);
  return FormSection(
    id: requireString(json, 'id', context: context),
    title: requireString(json, 'title', context: context),
    description: _nullableString(json, 'description', context),
    position: requireInt(json, 'position', context: context),
    items: requireList(
      json,
      'items',
      context: context,
    ).map((value) => _decodeItem(_object(value, 'form_section.items'))).toList(growable: false),
  );
}

Map<String, Object?> _encodeSection(FormSection section) => {
  'id': section.id,
  'title': section.title,
  'description': section.description,
  'position': section.position,
  'items': section.items.map(_encodeItem).toList(growable: false),
};

FormItem _decodeItem(Map<String, Object?> json) {
  const context = 'form_item';
  requireOnlyKeys(json, const {
    'id',
    'kind',
    'label',
    'help_text',
    'position',
    'is_required',
    'config',
    'options',
    'conditions',
  }, context: context);
  return FormItem(
    id: requireString(json, 'id', context: context),
    kind: _decodeEnum(requireString(json, 'kind', context: context), _itemKinds, 'item.kind'),
    label: requireString(json, 'label', context: context),
    helpText: _nullableString(json, 'help_text', context),
    position: requireInt(json, 'position', context: context),
    isRequired: requireBool(json, 'is_required', context: context),
    config: _decodeConfig(requireMap(json, 'config', context: context)),
    options: requireList(
      json,
      'options',
      context: context,
    ).map((value) => _decodeOption(_object(value, 'form_item.options'))).toList(growable: false),
    conditions: requireList(json, 'conditions', context: context)
        .map((value) => _decodeCondition(_object(value, 'form_item.conditions')))
        .toList(growable: false),
  );
}

Map<String, Object?> _encodeItem(FormItem item) => {
  'id': item.id,
  'kind': _encodeEnum(item.kind, _itemKinds),
  'label': item.label,
  'help_text': item.helpText,
  'position': item.position,
  'is_required': item.isRequired,
  'config': _encodeConfig(item.config),
  'options': item.options.map(_encodeOption).toList(growable: false),
  'conditions': item.conditions.map(_encodeCondition).toList(growable: false),
};

FormOption _decodeOption(Map<String, Object?> json) {
  const context = 'form_option';
  requireOnlyKeys(json, const {'id', 'label', 'position'}, context: context);
  return FormOption(
    id: requireString(json, 'id', context: context),
    label: requireString(json, 'label', context: context),
    position: requireInt(json, 'position', context: context),
  );
}

Map<String, Object?> _encodeOption(FormOption option) => {
  'id': option.id,
  'label': option.label,
  'position': option.position,
};

FormCondition _decodeCondition(Map<String, Object?> json) {
  const context = 'form_condition';
  requireOnlyKeys(json, const {
    'source_item_id',
    'kind',
    'expected_yes_no',
    'option_ids',
  }, context: context);
  final source = requireString(json, 'source_item_id', context: context);
  final kind = _decodeEnum(
    requireString(json, 'kind', context: context),
    _conditionKinds,
    'condition.kind',
  );
  return switch (kind) {
    FormConditionKind.yesNo => FormCondition.yesNo(
      sourceItemId: source,
      expected: requireBool(json, 'expected_yes_no', context: context),
    ),
    FormConditionKind.choice => FormCondition.choice(
      sourceItemId: source,
      optionIds: requireList(json, 'option_ids', context: context).map((value) {
        if (value is! String) {
          throw const WireFormatException('form_condition.option_ids must contain strings.');
        }
        return value;
      }).toSet(),
    ),
  };
}

Map<String, Object?> _encodeCondition(FormCondition condition) => {
  'source_item_id': condition.sourceItemId,
  'kind': _encodeEnum(condition.kind, _conditionKinds),
  'expected_yes_no': condition.expectedYesNo,
  'option_ids': condition.optionIds.toList(growable: false),
};

FormItemConfig _decodeConfig(Map<String, Object?> json) {
  const context = 'form_item.config';
  const allowed = {
    'min_value',
    'max_value',
    'decimal_places',
    'currency',
    'scale_min',
    'scale_max',
    'scale_min_label',
    'scale_max_label',
    'allow_camera',
    'allow_existing',
    'max_images',
  };
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList(growable: false);
  if (unknown.isNotEmpty) {
    throw WireFormatException('$context contains unknown keys: ${unknown.join(', ')}.');
  }
  return FormItemConfig(
    minValue: json['min_value'] as num?,
    maxValue: json['max_value'] as num?,
    decimalPlaces: json['decimal_places'] as int?,
    currency: json['currency'] as String?,
    scaleMin: json['scale_min'] as int?,
    scaleMax: json['scale_max'] as int?,
    scaleMinLabel: json['scale_min_label'] as String?,
    scaleMaxLabel: json['scale_max_label'] as String?,
    allowCamera: json['allow_camera'] as bool?,
    allowExisting: json['allow_existing'] as bool?,
    maxImages: json['max_images'] as int?,
  );
}

Map<String, Object?> _encodeConfig(FormItemConfig config) => <String, Object?>{
  if (config.minValue != null) 'min_value': config.minValue,
  if (config.maxValue != null) 'max_value': config.maxValue,
  if (config.decimalPlaces != null) 'decimal_places': config.decimalPlaces,
  if (config.currency != null) 'currency': config.currency,
  if (config.scaleMin != null) 'scale_min': config.scaleMin,
  if (config.scaleMax != null) 'scale_max': config.scaleMax,
  if (config.scaleMinLabel != null) 'scale_min_label': config.scaleMinLabel,
  if (config.scaleMaxLabel != null) 'scale_max_label': config.scaleMaxLabel,
  if (config.allowCamera != null) 'allow_camera': config.allowCamera,
  if (config.allowExisting != null) 'allow_existing': config.allowExisting,
  if (config.maxImages != null) 'max_images': config.maxImages,
};

String? _nullableString(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw WireFormatException('$context.$key must be a string or null.');
  return value;
}

Map<String, Object?> _object(Object? value, String context) {
  if (value is! Map<String, Object?>) throw WireFormatException('$context must contain objects.');
  return value;
}

T _decodeEnum<T extends Enum>(String wire, Map<T, String> values, String context) {
  for (final entry in values.entries) {
    if (entry.value == wire) return entry.key;
  }
  throw WireFormatException('$context contains unknown value: $wire.');
}

String _encodeEnum<T extends Enum>(T value, Map<T, String> values) => values[value]!;

const _formKinds = {FormKind.form: 'form', FormKind.quickPoll: 'quick_poll'};
const _identityModes = {
  FormIdentityMode.identified: 'identified',
  FormIdentityMode.anonymous: 'anonymous',
};
const _responseUnits = {
  FormResponseUnit.person: 'person',
  FormResponseUnit.childFamilyContext: 'child_family_context',
};
const _statuses = {
  FormStatus.draft: 'draft',
  FormStatus.published: 'published',
  FormStatus.archived: 'archived',
};
const _conditionKinds = {FormConditionKind.yesNo: 'yes_no', FormConditionKind.choice: 'choice'};
const _itemKinds = {
  FormItemKind.shortText: 'short_text',
  FormItemKind.integer: 'integer',
  FormItemKind.decimal: 'decimal',
  FormItemKind.money: 'money',
  FormItemKind.date: 'date',
  FormItemKind.yesNo: 'yes_no',
  FormItemKind.singleChoice: 'single_choice',
  FormItemKind.multipleChoice: 'multiple_choice',
  FormItemKind.scale: 'scale',
  FormItemKind.photo: 'photo',
  FormItemKind.gallery: 'gallery',
  FormItemKind.information: 'information',
};
