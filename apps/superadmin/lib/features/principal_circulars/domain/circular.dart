import 'package:flutter/foundation.dart';

abstract final class HappensContentLimits {
  static const bodyCharacters = 2200;
}

abstract final class CircularLimits {
  static const titleCharacters = 120;
  static const bodyCharacters = 10000;
  static const files = 4;
  static const questions = 10;
  static const questionCharacters = 240;
  static const optionCharacters = 120;
  static const minimumOptions = 2;
  static const maximumOptions = 10;
  static const imageBytes = 10 * 1024 * 1024;
  static const videoBytes = 25 * 1024 * 1024;
  static const pdfBytes = 5 * 1024 * 1024;
}

enum CircularStatus { draft, scheduled, published, closed, archived }

enum CircularRevisionStatus { working, published, superseded }

enum CircularQuestionKind { singleChoice, multipleChoice }

enum CircularResponsePolicy { perPerson, perChildAnyGuardian, perChildEachGuardian, perStaffMember }

enum CircularResponseState { unanswered, partial, answered }

enum CircularAudienceKind { families, students, schoolStaff, guardiansOnly }

enum CircularValidationCode {
  titleRequired,
  titleTooLong,
  bodyTooLong,
  tooManyFiles,
  tooManyQuestions,
  questionRequired,
  questionTooLong,
  invalidOptionCount,
  optionRequired,
  optionTooLong,
  duplicateBlockId,
  duplicateOptionId,
  audienceRequired,
}

@immutable
final class CircularValidationIssue {
  const CircularValidationIssue(this.code, {this.blockId, this.optionId});

  final CircularValidationCode code;
  final String? blockId;
  final String? optionId;
}

@immutable
sealed class CircularBlock {
  const CircularBlock({required this.id});

  final String id;
}

@immutable
final class CircularTextBlock extends CircularBlock {
  const CircularTextBlock({required super.id, required this.text});

  final String text;
}

@immutable
final class CircularMediaBlock extends CircularBlock {
  const CircularMediaBlock({required super.id, required this.assetIds});

  final List<String> assetIds;
}

@immutable
final class CircularQuestionOption {
  const CircularQuestionOption({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
final class CircularQuestionBlock extends CircularBlock {
  const CircularQuestionBlock({
    required super.id,
    required this.prompt,
    required this.kind,
    required this.required,
    required this.options,
  });

  final String prompt;
  final CircularQuestionKind kind;
  final bool required;
  final List<CircularQuestionOption> options;
}

@immutable
final class CircularDraft {
  const CircularDraft({
    required this.id,
    required this.title,
    required this.blocks,
    this.status = CircularStatus.draft,
    this.responsePolicy = CircularResponsePolicy.perPerson,
    this.audiences = const {},
    this.responsesCloseAt,
    this.expectedVersion = 0,
  });

  final String id;
  final String title;
  final List<CircularBlock> blocks;
  final CircularStatus status;
  final CircularResponsePolicy responsePolicy;
  final Set<CircularAudienceKind> audiences;
  final DateTime? responsesCloseAt;
  final int expectedVersion;

  List<CircularValidationIssue> validate({bool requireAudience = false}) {
    final issues = <CircularValidationIssue>[];
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      issues.add(const CircularValidationIssue(CircularValidationCode.titleRequired));
    } else if (cleanTitle.length > CircularLimits.titleCharacters) {
      issues.add(const CircularValidationIssue(CircularValidationCode.titleTooLong));
    }

    final blockIds = <String>{};
    var bodyCharacters = 0;
    var fileCount = 0;
    var questionCount = 0;
    for (final block in blocks) {
      if (!blockIds.add(block.id)) {
        issues.add(
          CircularValidationIssue(CircularValidationCode.duplicateBlockId, blockId: block.id),
        );
      }
      switch (block) {
        case CircularTextBlock():
          bodyCharacters += block.text.length;
        case CircularMediaBlock():
          fileCount += block.assetIds.length;
        case CircularQuestionBlock():
          questionCount++;
          _validateQuestion(block, issues);
      }
    }
    if (bodyCharacters > CircularLimits.bodyCharacters) {
      issues.add(const CircularValidationIssue(CircularValidationCode.bodyTooLong));
    }
    if (fileCount > CircularLimits.files) {
      issues.add(const CircularValidationIssue(CircularValidationCode.tooManyFiles));
    }
    if (questionCount > CircularLimits.questions) {
      issues.add(const CircularValidationIssue(CircularValidationCode.tooManyQuestions));
    }
    if (requireAudience && audiences.isEmpty) {
      issues.add(const CircularValidationIssue(CircularValidationCode.audienceRequired));
    }
    return List.unmodifiable(issues);
  }

  static void _validateQuestion(
    CircularQuestionBlock question,
    List<CircularValidationIssue> issues,
  ) {
    final prompt = question.prompt.trim();
    if (prompt.isEmpty) {
      issues.add(
        CircularValidationIssue(CircularValidationCode.questionRequired, blockId: question.id),
      );
    } else if (prompt.length > CircularLimits.questionCharacters) {
      issues.add(
        CircularValidationIssue(CircularValidationCode.questionTooLong, blockId: question.id),
      );
    }
    if (question.options.length < CircularLimits.minimumOptions ||
        question.options.length > CircularLimits.maximumOptions) {
      issues.add(
        CircularValidationIssue(CircularValidationCode.invalidOptionCount, blockId: question.id),
      );
    }
    final optionIds = <String>{};
    for (final option in question.options) {
      if (!optionIds.add(option.id)) {
        issues.add(
          CircularValidationIssue(
            CircularValidationCode.duplicateOptionId,
            blockId: question.id,
            optionId: option.id,
          ),
        );
      }
      final label = option.label.trim();
      if (label.isEmpty) {
        issues.add(
          CircularValidationIssue(
            CircularValidationCode.optionRequired,
            blockId: question.id,
            optionId: option.id,
          ),
        );
      } else if (label.length > CircularLimits.optionCharacters) {
        issues.add(
          CircularValidationIssue(
            CircularValidationCode.optionTooLong,
            blockId: question.id,
            optionId: option.id,
          ),
        );
      }
    }
  }
}
