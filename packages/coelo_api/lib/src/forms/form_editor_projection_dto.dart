import 'package:coelo_domain/coelo_domain.dart';

import 'form_definition_dto.dart';
import 'form_runtime_dtos.dart';
import 'form_wire_contracts.dart';

final class FormEditorProjection {
  const FormEditorProjection({required this.definition, this.application});

  final FormDefinition definition;
  final FormApplication? application;
}

final class FormEditorProjectionDto {
  const FormEditorProjectionDto(this.value);

  factory FormEditorProjectionDto.fromDomain(FormEditorProjection value) =>
      FormEditorProjectionDto(value);

  factory FormEditorProjectionDto.fromJson(Map<String, Object?> json) {
    const context = 'form_editor_projection';
    requireOnlyKeys(json, const {'definition', 'application'}, context: context);
    final definition = requireMap(json, 'definition', context: context);
    final application = json['application'];
    if (application != null && application is! Map<String, Object?>) {
      throw const WireFormatException(
        'form_editor_projection.application must be an object or null.',
      );
    }
    return FormEditorProjectionDto(
      FormEditorProjection(
        definition: FormDefinitionDto.fromJson(definition).toDomain(),
        application: application == null
            ? null
            : FormApplicationDto.fromJson(application as Map<String, Object?>).toDomain(),
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
  };
}
