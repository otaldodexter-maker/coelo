import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();
  final editor = File(
    'lib/features/forms/presentation/editor/forms_editor_page.dart',
  ).readAsStringSync();
  final response = File(
    'lib/features/forms/presentation/response/form_response_page.dart',
  ).readAsStringSync();
  final testSurface = File(
    'lib/features/forms/presentation/response/forms_test_page.dart',
  ).readAsStringSync();

  test('tracked Forms composition excludes the ten unavailable targets', () {
    final trackedComposition = '$router\n$editor\n$response\n$testSurface';

    for (final target in const [
      'FormAssetUploadController',
      'FormAutosaveController',
      'FormAnonymousEditSecretStore',
      'FormAssetPicker',
      'FormAssetUploader',
      'FormsEditorRoutePage',
      'FormsMonitorPage',
      'FormResponseRoutePage',
      'FormsResponsesPage',
      'FormResponseDetailPage',
    ]) {
      expect(trackedComposition, isNot(contains(target)), reason: target);
    }
  });

  test('remaining dormant route builders stay declared and statically unavailable', () {
    expect(
      RegExp(
        r'builder:\s*\(context, state\) => _unavailableFormsRoute\(context\)',
      ).allMatches(router),
      hasLength(12),
    );
    expect(router, isNot(contains('FormsRouteCapabilities')));
    expect(router, isNot(contains('formsCapabilities')));
  });

  test('C0 Forms files and media routes remain fail-closed', () {
    for (final routeName in const [
      'formFilesName',
      'formMediaName',
      'devFormFilesName',
      'devFormMediaName',
    ]) {
      expect(router, contains('SuperadminRoutes.$routeName'), reason: routeName);
    }
    expect(
      RegExp(
        r'builder:\s*\(context, state\)\s*=>\s*'
        r'_unavailableCompositionRootRoute\(\s*context\s*\)',
      ).allMatches(router),
      hasLength(greaterThanOrEqualTo(4)),
    );
  });
}
