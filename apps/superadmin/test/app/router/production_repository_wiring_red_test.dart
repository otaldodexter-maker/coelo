import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final routerSource = File('lib/app/router/superadmin_router.dart').readAsStringSync();
  final profileSource = File(
    'lib/features/account/presentation/screens/profile_page.dart',
  ).readAsStringSync();
  final accountControllerSource = File(
    'lib/features/account/presentation/account_controller.dart',
  ).readAsStringSync();
  final firstDevelopmentRoute = routerSource.indexOf('path: SuperadminRoutes.dev');
  final productionRoutesSource = routerSource.substring(0, firstDevelopmentRoute);

  test('production composition has no demo or in-memory defaults', () {
    expect(firstDevelopmentRoute, greaterThanOrEqualTo(0));
    expect(productionRoutesSource, isNot(contains('?? SupportPrototypeController()')));
    expect(productionRoutesSource, isNot(contains('controller: developmentSupportController')));
    expect(productionRoutesSource, isNot(contains('controller: developmentAccountController')));
    expect(
      productionRoutesSource,
      isNot(contains('UserPreferencesController(InMemoryUserPreferencesRepository())')),
    );
    expect(
      productionRoutesSource,
      isNot(contains('const healthCareRepository = UnavailableHealthCareRepository()')),
    );
  });

  test('production account flow never exposes or validates a demo password', () {
    expect(profileSource, isNot(contains('coelo-demo')));
    expect(accountControllerSource, isNot(contains('coelo-demo')));
  });

  test('preview fixtures remain explicit and confined to development routes', () {
    expect(routerSource, contains('path: SuperadminRoutes.dev'));
    expect(routerSource, isNot(contains('FakePersonDirectoryRepository()')));
    expect(routerSource, isNot(contains('personDirectoryRepository ?? Fake')));
  });
}
