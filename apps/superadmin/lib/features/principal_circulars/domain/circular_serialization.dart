import 'circular.dart';

abstract final class CircularDraftCodec {
  static Map<String, dynamic> toJson(CircularDraft draft) => {
    'id': draft.id,
    'title': draft.title,
    'version': draft.expectedVersion,
    'status': draft.status.name,
    'response_policy': _responsePolicyToJson(draft.responsePolicy),
    'audiences': [for (final audience in draft.audiences) _audienceToJson(audience)],
    'responses_close_at': draft.responsesCloseAt?.toUtc().toIso8601String(),
    'blocks': [for (final block in draft.blocks) _blockToJson(block)],
  };

  static CircularDraft fromJson(Map<String, dynamic> json) => CircularDraft(
    id: _requiredText(json, 'id'),
    title: _requiredText(json, 'title'),
    expectedVersion: _requiredInt(json, 'version'),
    status: _statusFromJson(json['status'] as String? ?? 'draft'),
    responsePolicy: _responsePolicyFromJson(json['response_policy'] as String? ?? 'per_person'),
    audiences: (json['audiences'] as List? ?? const [])
        .map((value) => value is Map ? value['kind'] : value)
        .map((value) => _audienceFromJson(value.toString()))
        .toSet(),
    responsesCloseAt: _optionalDate(json['responses_close_at']),
    blocks: (json['blocks'] as List? ?? const [])
        .map((value) => _blockFromJson(Map<String, dynamic>.from(value as Map)))
        .toList(growable: false),
  );

  static Map<String, dynamic> _blockToJson(CircularBlock block) => switch (block) {
    CircularTextBlock() => {'id': block.id, 'kind': 'text', 'text': block.text},
    CircularMediaBlock() => {'id': block.id, 'kind': 'media', 'asset_ids': block.assetIds},
    CircularQuestionBlock() => {
      'id': block.id,
      'kind': 'question',
      'question': {
        'id': block.id,
        'prompt': block.prompt,
        'kind': _questionKindToJson(block.kind),
        'required': block.required,
        'options': [
          for (final option in block.options) {'id': option.id, 'label': option.label},
        ],
      },
    },
  };

  static CircularBlock _blockFromJson(Map<String, dynamic> json) {
    final id = _requiredText(json, 'id');
    return switch (json['kind']) {
      'text' => CircularTextBlock(id: id, text: json['text'] as String? ?? ''),
      'media' => CircularMediaBlock(
        id: id,
        assetIds: (json['asset_ids'] as List? ?? json['media'] as List? ?? const [])
            .map((value) => value is Map ? value['asset_id'].toString() : value.toString())
            .toList(growable: false),
      ),
      'question' => _questionBlockFromJson(id, json),
      _ => throw const FormatException('invalid_circular_block_kind'),
    };
  }

  static CircularQuestionBlock _questionBlockFromJson(String blockId, Map<String, dynamic> block) {
    final question = Map<String, dynamic>.from((block['question'] as Map?) ?? block);
    return CircularQuestionBlock(
      id: blockId,
      prompt: _requiredText(question, 'prompt'),
      kind: _questionKindFromJson(_requiredText(question, 'kind')),
      required: question['required'] as bool? ?? false,
      options: (question['options'] as List? ?? const [])
          .map((value) {
            final option = Map<String, dynamic>.from(value as Map);
            return CircularQuestionOption(
              id: _requiredText(option, 'id'),
              label: _requiredText(option, 'label'),
            );
          })
          .toList(growable: false),
    );
  }
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) throw FormatException('invalid_$key');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('invalid_$key');
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) throw const FormatException('invalid_date');
  return parsed;
}

String _questionKindToJson(CircularQuestionKind kind) => switch (kind) {
  CircularQuestionKind.singleChoice => 'single_choice',
  CircularQuestionKind.multipleChoice => 'multiple_choice',
};

CircularQuestionKind _questionKindFromJson(String value) => switch (value) {
  'single_choice' => CircularQuestionKind.singleChoice,
  'multiple_choice' => CircularQuestionKind.multipleChoice,
  _ => throw const FormatException('invalid_question_kind'),
};

String _responsePolicyToJson(CircularResponsePolicy policy) => switch (policy) {
  CircularResponsePolicy.perPerson => 'per_person',
  CircularResponsePolicy.perChildAnyGuardian => 'per_child_any_guardian',
  CircularResponsePolicy.perChildEachGuardian => 'per_child_each_guardian',
  CircularResponsePolicy.perStaffMember => 'per_staff_member',
};

CircularResponsePolicy _responsePolicyFromJson(String value) => switch (value) {
  'per_person' => CircularResponsePolicy.perPerson,
  'per_child_any_guardian' => CircularResponsePolicy.perChildAnyGuardian,
  'per_child_each_guardian' => CircularResponsePolicy.perChildEachGuardian,
  'per_staff_member' => CircularResponsePolicy.perStaffMember,
  _ => throw const FormatException('invalid_response_policy'),
};

CircularStatus _statusFromJson(String value) => switch (value) {
  'draft' => CircularStatus.draft,
  'scheduled' => CircularStatus.scheduled,
  'published' => CircularStatus.published,
  'closed' => CircularStatus.closed,
  'archived' => CircularStatus.archived,
  _ => throw const FormatException('invalid_circular_status'),
};

String _audienceToJson(CircularAudienceKind value) => switch (value) {
  CircularAudienceKind.families => 'families',
  CircularAudienceKind.students => 'students',
  CircularAudienceKind.schoolStaff => 'school_staff',
  CircularAudienceKind.guardiansOnly => 'guardians_only',
};

CircularAudienceKind _audienceFromJson(String value) => switch (value) {
  'families' => CircularAudienceKind.families,
  'students' => CircularAudienceKind.students,
  'school_staff' => CircularAudienceKind.schoolStaff,
  'guardians_only' => CircularAudienceKind.guardiansOnly,
  _ => throw const FormatException('invalid_audience_kind'),
};
