import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares protected profile and settings locations', () {
    expect(SuperadminRoutes.profile, '/profile');
    expect(SuperadminRoutes.settings, '/settings');
  });
}
