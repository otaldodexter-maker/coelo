import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();

  test('Activities DEV composes one shared session and local repositories', () {
    expect(RegExp(r'DevActivitySessionStore\.content\(\)').allMatches(router), hasLength(1));
    expect(
      RegExp(
        r'DevActivityDirectoryRepository\(\s*store:\s*developmentActivityStore,?\s*\)',
      ).hasMatch(router),
      isTrue,
    );
    expect(
      RegExp(
        r'DevActivityCommandRepository\(\s*store:\s*developmentActivityStore,?\s*\)',
      ).hasMatch(router),
      isTrue,
    );
    expect(router, contains('DevelopmentActivityProfileAboutRepository()'));
  });

  test('four DEV Activity builders use only the local directory session', () {
    final start = router.indexOf('path: SuperadminRoutes.devActivities,');
    final end = router.indexOf('path: SuperadminRoutes.devActivityAssessmentSettings,', start);
    final source = router.substring(start, end);

    expect(
      RegExp(r'repository:\s*developmentActivityDirectoryRepository,').allMatches(source),
      hasLength(4),
    );
    expect(source, isNot(contains('repository: activityDirectoryRepository,')));
    expect(source, contains('developmentActivityCommandRepository'));
    expect(source, contains('developmentActivityAboutRepository'));
  });

  test('production Activity builders keep only injected fail-closed dependencies', () {
    final start = router.indexOf('path: SuperadminRoutes.activities,');
    final end = router.indexOf('path: SuperadminRoutes.assessmentEntry,', start);
    final source = router.substring(start, end);

    // e06eb62/d01c318 deliberately split the authorized read projection from
    // legacy directory/form DTOs. All four dependencies must still be injected;
    // the new reader defaults to Unavailable, never a development fallback.
    expect(RegExp(r'repository:\s*activityDirectoryRepository,').allMatches(source), hasLength(3));
    expect(RegExp(r'repository:\s*activityReadDetailRepository,').allMatches(source), hasLength(1));
    expect(source.contains('ActivityReadDetailPage('), isTrue);
    expect(source.contains('ActivityDetailPage('), isFalse);
    expect(router.contains('const UnavailableActivityReadDetailRepository()'), isTrue);
    expect(
      RegExp(r'commandRepository:\s*activityCommandRepository,').allMatches(source),
      hasLength(4),
    );
    expect(
      RegExp(r'aboutRepository:\s*productionActivityAboutRepository,').allMatches(source),
      hasLength(6),
    );
    expect(source, isNot(contains('developmentActivity')));
  });

  test('assessment settings and pedagogical command fields remain wired', () {
    expect(router, contains('SuperadminRoutes.activityAssessmentSettings'));
    expect(router, contains('SuperadminRoutes.devActivityAssessmentSettings'));
    expect(router, contains('ActivityFormStep.pedagogical'));
    // d33ef498 intentionally normalizes ONLY the canonical empty disabled
    // payload for the atomic aggregate; populated/enabled configs retain every
    // field. Behavioral cases live in activity_pedagogical_configuration_draft_test.
    expect(
      router.contains(
        'pedagogicalConfiguration: draft.pedagogicalConfiguration.toAggregateCommandJson()',
      ),
      isTrue,
    );
    expect(
      router,
      contains('expectedAssessmentVersion: draft.pedagogicalConfiguration.expectedVersion'),
    );
    expect(
      router,
      contains('assessmentChangeJustification: draft.pedagogicalConfiguration.changeJustification'),
    );
  });
}
