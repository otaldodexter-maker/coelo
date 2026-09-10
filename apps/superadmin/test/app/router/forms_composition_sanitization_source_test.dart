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

  // Este teste ficou para tras quando a composicao avancou. Ele exigia que
  // monitor, responses, responseDetail e files continuassem const sem api,
  // mas as quatro foram deliberadamente compostas com api real sob
  // withFormsAuthorization. O contrato de comportamento que passou a valer e
  // forms_fail_closed_routes_test: la as quatro declaram readsFromApi e
  // exigem expect(api.calls, 1), enquanto /test e /respond exigem 0.
  //
  // Quando dois testes se contradizem, o comportamental e o autoritativo. As
  // quatro literais saem daqui e sao substituidas pela verificacao de que a
  // composicao delas passa por withFormsAuthorization. Nao reverter para as
  // literais const sem antes mudar forms_fail_closed_routes_test.
  test('production routes use real fail-closed Forms surfaces', () {
    // Continuam fail-closed por contrato: montam a pagina real sem api.
    for (final surface in const ['const FormsTestPage()', 'const FormResponsePage()']) {
      expect(router, contains(surface), reason: surface);
    }
    expect(router, contains('FormsMediaPage('));

    // Compostas com api real, e por isso protegidas pela guarda de sessao.
    for (final surface in const [
      'FormsOperationsPage.monitor(',
      'FormsOperationsPage.responses(',
      'FormsOperationsPage.responseDetail(',
      'FormsOperationsPage.files(',
    ]) {
      expect(router, contains(surface), reason: surface);
      expect(router, isNot(contains('const $surface)')), reason: 'const $surface');
    }
    expect('withFormsAuthorization('.allMatches(router).length, greaterThanOrEqualTo(4));

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
    expect(router, contains('FormsOperationsPage.files('));
    expect(router, contains('developmentStore: developmentFormsFilesStore'));
    expect(router, contains('FormsMediaPage('));
    expect(router, contains('FormsMediaPage.development('));
  });
}
