import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit has a productive route and the legacy preview path remains explicit', () {
    expect(SuperadminRoutes.audit, '/audit');
    expect(SuperadminRoutes.auditName, 'audit');
    expect(SuperadminRoutes.devAudit, '/dev/audit');
  });

  test('productive audit route uses the approved download opener', () {
    final source = File('lib/app/router/superadmin_router.dart').readAsStringSync();

    expect(source, contains('openDownloadUrl: openDownloadUrl'));
  });
}
