import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final authScope = File('lib/core/config/superadmin_auth_scope.dart').readAsStringSync();
  final app = File('lib/app/superadmin_app.dart').readAsStringSync();
  final mainSource = File('lib/main.dart').readAsStringSync();
  final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();

  test('composition roots exclude unavailable extended and media dependencies', () {
    for (final source in [authScope, app, mainSource, router]) {
      expect(source, isNot(contains('AccessProfileExtendedRepository')));
      expect(source, isNot(contains('accessProfileExtendedRepository')));
      expect(source, isNot(contains('FormMediaResolver')));
      expect(source, isNot(contains('formMediaResolver')));
      expect(source, isNot(contains('formMediaResolve')));
    }

    for (final importPath in const [
      'supabase_access_profile_extended_repository.dart',
      'unavailable_access_profile_extended_repository.dart',
      'access_profile_model_directory_page.dart',
      'access_profile_model_form_page.dart',
      'access_profile_model_detail_page.dart',
      'form_media_resolver.dart',
      'presentation/files/form_media_page.dart',
      'presentation/files/forms_files_route_page.dart',
    ]) {
      expect(router + authScope + app, isNot(contains(importPath)), reason: importPath);
    }
  });

  test('configured and fallback invitation composition remains unavailable', () {
    for (final source in [authScope, app, mainSource]) {
      expect(source, isNot(contains('SupabaseInviteRepository')));
      expect(source, isNot(contains('supabase_invite_repository.dart')));
      expect(source, isNot(contains('DevelopmentInviteRepository')));
      expect(source, isNot(contains('development_invite_repository.dart')));
    }
    expect(
      RegExp(r'inviteRepository:\s*const UnavailableInviteRepository\(\)').allMatches(authScope),
      hasLength(2),
    );
    expect(app, contains('this.inviteRepository = const UnavailableInviteRepository()'));
    expect(router, isNot(contains('SupabaseInviteRepository')));
    expect(router, isNot(contains('supabase_invite_repository.dart')));
    expect(RegExp(r'repository:\s*inviteRepository,').allMatches(router), hasLength(3));
    expect(RegExp(r'repository:\s*invitePreviewRepository\(\),').allMatches(router), hasLength(3));
  });

  test('Activities roots are fail-closed and never construct Supabase adapters', () {
    for (final source in [authScope, app, mainSource, router]) {
      expect(source, isNot(contains('SupabaseActivityDirectoryRepository')));
      expect(source, isNot(contains('SupabaseActivityCommandRepository')));
      expect(source, isNot(contains('supabase_activity_directory_repository.dart')));
      expect(source, isNot(contains('supabase_activity_command_repository.dart')));
    }
    expect(
      RegExp(
        r'activityDirectoryRepository:\s*const UnavailableActivityDirectoryRepository\(\)',
      ).allMatches(authScope),
      hasLength(2),
    );
    expect(
      RegExp(
        r'activityCommandRepository:\s*const UnavailableActivityCommandRepository\(\)',
      ).allMatches(authScope),
      hasLength(2),
    );
    expect(router, contains('DevActivitySessionStore.content()'));
    expect(router, contains('DevActivityDirectoryRepository'));
    expect(router, contains('DevActivityCommandRepository'));
    expect(router, contains('DevelopmentActivityProfileAboutRepository'));
  });

  test('basic Access routes stay statically unavailable without page composition', () {
    for (final page in const [
      'AccessProfileDirectoryPage',
      'AccessProfileFormPage',
      'AccessProfileDetailPage',
    ]) {
      expect(router, isNot(contains(page)), reason: page);
    }
    for (final route in const {
      'profiles': 'profilesName',
      'profileCreate': 'profileCreateName',
      'profileDetail': 'profileDetailName',
      'profileEdit': 'profileEditName',
    }.entries) {
      expect(
        RegExp(
          'path:\\s*SuperadminRoutes\\.${route.key},\\s*'
          'name:\\s*SuperadminRoutes\\.${route.value},\\s*'
          'builder:\\s*\\(context, state\\) =>\\s*'
          '_unavailableCompositionRootRoute\\(context\\)',
        ).hasMatch(router),
        isTrue,
        reason: route.key,
      );
    }
    expect(router, isNot(contains('extendedRepository:')));
    expect(router, contains('GroupDirectoryRepository groupDirectoryRepository'));
  });

  test('model and media route declarations stay fail-closed without missing pages', () {
    for (final routeName in const [
      'profileModelsName',
      'profileModelCreateName',
      'profileModelDetailName',
      'profileModelEditName',
      'profileModelDuplicateName',
      'formFilesName',
      'formMediaName',
    ]) {
      expect(router, contains('SuperadminRoutes.$routeName'), reason: routeName);
    }
    for (final page in const [
      'AccessProfileModelDirectoryPage',
      'AccessProfileModelFormPage',
      'AccessProfileModelDetailPage',
      'FormsFilesRoutePage',
      'FormMediaPage',
    ]) {
      expect(router, isNot(contains(page)), reason: page);
    }
  });
}
