import 'package:coelo_domain/coelo_domain.dart';

import 'form_definition_dto.dart';
import 'form_runtime_dtos.dart';
import 'form_wire_contracts.dart';

final class FormEditorProjection {
  const FormEditorProjection({required this.definition, this.application, this.mediaContext});

  final FormDefinition definition;
  final FormApplication? application;
  final FormEditorMediaContext? mediaContext;
}

/// Opaque, server-authorized bindings for the displayed working definition.
/// Absence means the editor cannot author question images in this context.
final class FormEditorMediaContext {
  FormEditorMediaContext({
    required this.formVersionId,
    required List<FormQuestionImageBinding> questionImages,
  }) : questionImages = List.unmodifiable(questionImages);
  final String formVersionId;
  final List<FormQuestionImageBinding> questionImages;
}

final class FormQuestionImageBinding {
  const FormQuestionImageBinding({
    required this.itemId,
    required this.assetId,
    required this.status,
    required this.mimeType,
    required this.position,
  });
  final String itemId;
  final String assetId;
  final String status;
  final String? mimeType;
  final int position;
  bool get isReady => status == 'ready';
}

final class FormEditorProjectionDto {
  const FormEditorProjectionDto(this.value);

  factory FormEditorProjectionDto.fromDomain(FormEditorProjection value) =>
      FormEditorProjectionDto(value);

  factory FormEditorProjectionDto.fromJson(Map<String, Object?> json) {
    const context = 'form_editor_projection';
    requireOnlyKeys(json, {
      'definition',
      'application',
      if (json.containsKey('media_context')) 'media_context',
    }, context: context);
    final definition = requireMap(json, 'definition', context: context);
    final application = json['application'];
    if (application != null && application is! Map<String, Object?>) {
      throw const WireFormatException(
        'form_editor_projection.application must be an object or null.',
      );
    }
    final parsedDefinition = FormDefinitionDto.fromJson(definition).toDomain();
    final media = _mediaContext(json['media_context']);
    final itemIds = parsedDefinition.sections
        .expand((section) => section.items)
        .map((item) => item.id)
        .toSet();
    if (media != null && media.questionImages.any((binding) => !itemIds.contains(binding.itemId))) {
      throw const WireFormatException(
        'Question image does not belong to the displayed definition.',
      );
    }
    return FormEditorProjectionDto(
      FormEditorProjection(
        definition: parsedDefinition,
        application: application == null
            ? null
            : FormApplicationDto.fromJson(application as Map<String, Object?>).toDomain(),
        mediaContext: media,
      ),
    );
  }

  final FormEditorProjection value;

  FormEditorProjection toDomain() => value;

  Map<String, Object?> toJson() => {
    'definition': FormDefinitionDto.fromDomain(value.definition).toJson(),
    'application': value.application == null
        ? null
        : FormApplicationDto.fromDomain(value.application!).toJson(),
    if (value.mediaContext case final media?)
      'media_context': {
        'form_version_id': media.formVersionId,
        'question_images': [
          for (final binding in media.questionImages)
            {
              'item_id': binding.itemId,
              'asset_id': binding.assetId,
              'status': binding.status,
              'mime_type': binding.mimeType,
              'position': binding.position,
            },
        ],
      },
  };
}

FormEditorMediaContext? _mediaContext(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map<String, Object?> || raw['question_images'] is! List) {
    throw const WireFormatException('Invalid form media context.');
  }
  requireOnlyKeys(raw, const {'form_version_id', 'question_images'}, context: 'form_media_context');
  String id(Object? value) {
    if (value is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$').hasMatch(value)) {
      throw const WireFormatException('Invalid form media identifier.');
    }
    return value;
  }

  final bindings = <FormQuestionImageBinding>[];
  final assets = <String>{};
  for (final value in raw['question_images']! as List) {
    if (value is! Map<String, Object?>) {
      throw const WireFormatException('Invalid question image binding.');
    }
    requireOnlyKeys(value, const {
      'item_id',
      'asset_id',
      'status',
      'mime_type',
      'position',
    }, context: 'question_image_binding');
    if (value['status'] is! String ||
        (value['status']! as String).isEmpty ||
        value['position'] is! int ||
        (value['position']! as int) < 0 ||
        (value['mime_type'] != null && value['mime_type'] is! String)) {
      throw const WireFormatException('Invalid question image metadata.');
    }
    final assetId = id(value['asset_id']);
    if (!assets.add(assetId)) throw const WireFormatException('Duplicate question image binding.');
    bindings.add(
      FormQuestionImageBinding(
        itemId: id(value['item_id']),
        assetId: assetId,
        status: value['status']! as String,
        mimeType: value['mime_type'] as String?,
        position: value['position']! as int,
      ),
    );
  }
  return FormEditorMediaContext(
    formVersionId: id(raw['form_version_id']),
    questionImages: bindings,
  );
}
