import 'dart:async';

import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_profile_about_repository.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_controller.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_profile_about_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ignores an old About read after controller and repository change', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controllerA = ActivityFormController.create(
      const ActivityFormOptions(),
      initialInstitutionId: 'institution-a',
    );
    final controllerB = ActivityFormController.create(
      const ActivityFormOptions(),
      initialInstitutionId: 'institution-b',
    );
    final repositoryA = _DelayedAboutRepository();
    final repositoryB = _DelayedAboutRepository();
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    await tester.pumpWidget(
      _app(controller: controllerA, repository: repositoryA, activityId: 'a'),
    );
    await tester.pump();

    await tester.pumpWidget(
      _app(controller: controllerB, repository: repositoryB, activityId: 'b'),
    );
    await tester.pump();
    expect(repositoryB.requestCount, 1);

    repositoryB.complete(
      _page(institutionId: 'institution-b', activityId: 'b', description: 'Sobre B'),
    );
    await tester.pump();
    expect(find.text('Sobre B'), findsOneWidget);

    repositoryA.complete(
      _page(institutionId: 'institution-a', activityId: 'a', description: 'Sobre A'),
    );
    await tester.pump();
    expect(find.text('Sobre B'), findsOneWidget);
    expect(find.text('Sobre A'), findsNothing);
    expect(controllerB.aboutPage?.subject.activityId, 'b');
  });

  testWidgets('rejects an About page bound to another activity', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ActivityFormController.create(
      const ActivityFormOptions(),
      initialInstitutionId: 'institution-a',
    );
    addTearDown(controller.dispose);
    final repository = _ImmediateAboutRepository(
      _page(
        institutionId: 'institution-a',
        activityId: 'activity-tampered',
        description: 'Conteúdo de outra atividade',
      ),
    );

    await tester.pumpWidget(
      _app(controller: controller, repository: repository, activityId: 'activity-expected'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-about-unauthorized')), findsOneWidget);
    expect(find.text('Conteúdo de outra atividade'), findsNothing);
    expect(controller.aboutPage, isNull);
  });
}

Widget _app({
  required ActivityFormController controller,
  required ActivityProfileAboutRepository repository,
  required String activityId,
}) => MaterialApp(
  home: Scaffold(
    body: ActivityProfileAboutSection(
      controller: controller,
      repository: repository,
      activityId: activityId,
    ),
  ),
);

ProfileAboutPage _page({
  required String institutionId,
  required String activityId,
  required String description,
}) => ProfileAboutPage(
  subject: ProfileAboutSubjectRef(
    type: ProfileAboutSubjectType.activity,
    institutionId: institutionId,
    activityId: activityId,
  ),
  version: 1,
  fields: [ProfileAboutField(key: ProfileAboutFieldKey.description, value: description)],
  sections: const [],
);

final class _DelayedAboutRepository implements ActivityProfileAboutRepository {
  final Completer<ProfileAboutPage> _load = Completer<ProfileAboutPage>();
  var requestCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<ProfileAboutPage> load({required String institutionId, String? activityId}) {
    requestCount++;
    return _load.future;
  }

  void complete(ProfileAboutPage page) => _load.complete(page);

  @override
  Future<ProfileAboutPage> save({
    required ProfileAboutPage page,
    required String institutionId,
    required String activityId,
    required String requestId,
  }) async => page;
}

final class _ImmediateAboutRepository implements ActivityProfileAboutRepository {
  const _ImmediateAboutRepository(this.page);

  final ProfileAboutPage page;

  @override
  bool get isAvailable => true;

  @override
  Future<ProfileAboutPage> load({required String institutionId, String? activityId}) async => page;

  @override
  Future<ProfileAboutPage> save({
    required ProfileAboutPage page,
    required String institutionId,
    required String activityId,
    required String requestId,
  }) async => page;
}
