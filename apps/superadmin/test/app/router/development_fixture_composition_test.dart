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

    expect(RegExp(r'repository:\s*activityDirectoryRepository,').allMatches(source), hasLength(4));
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
    expect(router, contains('pedagogicalConfiguration: draft.pedagogicalConfiguration.toJson()'));
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
