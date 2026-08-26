import 'package:coelo_superadmin/features/activities/presentation/activity_pedagogical_configuration_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityPedagogicalConfigurationDraft', () {
    test('disabled configuration is explicit and has no assessment children', () {
      const draft = ActivityPedagogicalConfigurationDraft.disabled();

      expect(draft.enabled, isFalse);
      expect(draft.periods, isEmpty);
      expect(draft.instruments, isEmpty);
      expect(draft.categories, isEmpty);
      expect(draft.toJson()['enabled'], isFalse);
      expect(draft.validationErrors, isEmpty);
    });

    test('generates contiguous suggested periods for every periodicity', () {
      final start = DateTime(2027, 1, 1);
      final end = DateTime(2027, 12, 31);
      final expectations = {
        ActivityAssessmentPeriodicity.bimonthly: 4,
        ActivityAssessmentPeriodicity.trimester: 3,
        ActivityAssessmentPeriodicity.semester: 2,
        ActivityAssessmentPeriodicity.annual: 1,
      };

      for (final entry in expectations.entries) {
        final periods = ActivityPedagogicalConfigurationDraft.suggestPeriods(
          periodicity: entry.key,
          validityStart: start,
          validityEnd: end,
          timezone: 'America/Sao_Paulo',
        );
        expect(periods, hasLength(entry.value));
        expect(periods.first.startsOn, start);
        expect(periods.last.endsOn, end);
        for (var index = 1; index < periods.length; index++) {
          expect(periods[index].startsOn, periods[index - 1].endsOn.add(const Duration(days: 1)));
        }
      }
    });

    test('requires dates and times in start end deadline release order', () {
      final period = ActivityAssessmentPeriodDraft(
        name: '1º período',
        order: 1,
        startsOn: DateTime(2027, 1, 1),
        endsOn: DateTime(2027, 2, 28),
        entryDeadlineAt: DateTime(2027, 2, 27, 18),
        familyReleaseAt: DateTime(2027, 3, 2, 8),
        timezone: 'America/Sao_Paulo',
      );

      expect(period.validationErrors, contains('period_date_order'));
      expect(period.toJson()['entry_deadline_at'], contains('18:00:00'));
      expect(period.toJson()['family_release_at'], contains('08:00:00'));
      expect(period.toJson()['timezone'], 'America/Sao_Paulo');
    });

    test('grade instruments must have positive weights totaling exactly 100 percent', () {
      final draft = _validGradeDraft().copyWith(
        instruments: const [
          ActivityAssessmentInstrumentDraft(
            clientId: 'exam',
            name: 'Prova',
            kind: ActivityAssessmentInstrumentKind.exam,
            weight: 60,
            order: 1,
          ),
          ActivityAssessmentInstrumentDraft(
            clientId: 'project',
            name: 'Projeto',
            kind: ActivityAssessmentInstrumentKind.project,
            weight: 30,
            order: 2,
          ),
        ],
      );

      expect(draft.totalInstrumentWeight, 90);
      expect(draft.validationErrors, contains('instrument_weights_total'));
      expect(
        draft
            .copyWith(
              instruments: const [
                ActivityAssessmentInstrumentDraft(
                  clientId: 'invalid',
                  name: 'Inválido',
                  kind: ActivityAssessmentInstrumentKind.custom,
                  weight: -1,
                  order: 1,
                ),
              ],
            )
            .validationErrors,
        contains('instrument_weight_range'),
      );
    });

    test('competencies require the 1-5 scale and a single taxonomy version', () {
      final draft = _validGradeDraft().copyWith(
        model: ActivityAssessmentModel.gradeAndCompetencies,
        competencyScale: ActivityCompetencyScale.oneToFive,
        taxonomyVersionId: 'taxonomy-v1',
        categories: const [
          ActivityAssessmentCategoryDraft(
            clientId: 'communication',
            name: 'Comunicação',
            order: 1,
            taxonomyVersionId: 'taxonomy-v1',
            competencies: [
              ActivityAssessmentCompetencyDraft(
                clientId: 'speech',
                name: 'Fala',
                order: 1,
                taxonomyVersionId: 'taxonomy-v2',
              ),
            ],
          ),
        ],
      );

      expect(draft.validationErrors, contains('mixed_taxonomy_versions'));
    });

    test('recovery is rejected for non numeric grade scales', () {
      final draft = _validGradeDraft().copyWith(
        gradeScale: ActivityGradeScale.concepts,
        conceptLevels: const ['A', 'B', 'C'],
        recoveryRule: ActivityRecoveryRule.keepHigher,
      );

      expect(draft.validationErrors, contains('recovery_requires_numeric_scale'));
    });

    test('round trips complete configuration including expected version and justification', () {
      final source = _validGradeDraft().copyWith(
        expectedVersion: 7,
        changeJustification: 'Nova vigência após lançamentos.',
        usedByResults: true,
      );

      final restored = ActivityPedagogicalConfigurationDraft.fromJson(source.toJson());

      expect(restored.toJson(), source.toJson());
      expect(restored.expectedVersion, 7);
      expect(restored.changeJustification, isNotEmpty);
    });
  });
}

ActivityPedagogicalConfigurationDraft _validGradeDraft() {
  final periods = ActivityPedagogicalConfigurationDraft.suggestPeriods(
    periodicity: ActivityAssessmentPeriodicity.annual,
    validityStart: DateTime(2027, 1, 1),
    validityEnd: DateTime(2027, 12, 31),
    timezone: 'America/Sao_Paulo',
  );
  return ActivityPedagogicalConfigurationDraft(
    enabled: true,
    model: ActivityAssessmentModel.gradeOnly,
    periodicity: ActivityAssessmentPeriodicity.annual,
    validityStart: DateTime(2027, 1, 1),
    validityEnd: DateTime(2027, 12, 31),
    timezone: 'America/Sao_Paulo',
    gradeScale: ActivityGradeScale.numeric0To10,
    periods: [
      periods.single.copyWith(
        entryDeadlineAt: DateTime(2028, 1, 5, 18),
        familyReleaseAt: DateTime(2028, 1, 8, 8),
      ),
    ],
    instruments: const [
      ActivityAssessmentInstrumentDraft(
        clientId: 'exam',
        name: 'Prova',
        kind: ActivityAssessmentInstrumentKind.exam,
        weight: 100,
        order: 1,
      ),
    ],
  );
}
