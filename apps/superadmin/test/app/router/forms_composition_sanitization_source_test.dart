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

  test('production routes use real fail-closed Forms surfaces', () {
    for (final surface in const [
      'const FormsTestPage()',
      'const FormsOperationsPage.monitor()',
      'const FormResponsePage()',
      'const FormsOperationsPage.responses()',
      'const FormsOperationsPage.responseDetail()',
      'const FormsOperationsPage.files()',
    ]) {
      expect(router, contains(surface), reason: surface);
    }
    expect(router, isNot(contains('_unavailableFormsRoute')));
    expect(router, isNot(contains('FormsRouteCapabilities')));
    expect(router, isNot(contains('formsCapabilities')));
  });

  test('Forms files and media keep production fail-closed and dev fixtures separated', () {
    for (final routeName in const [
      'formFilesName',
      'formMediaName',
      'devFormFilesName',
      'devFormMediaName',
    ]) {
      expect(router, contains('SuperadminRoutes.$routeName'), reason: routeName);
    }
    expect(router, contains('const FormsOperationsPage.files()'));
    expect(router, contains('const FormsOperationsPage.files(development: true)'));
  });
}
