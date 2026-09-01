import 'package:coelo_superadmin/core/config/superadmin_app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to hosted staging and keeps development previews disabled', () {
    expect(SuperadminAppConfig.environment, 'staging');
    expect(SuperadminAppConfig.allowDevelopmentPreview, isFalse);
  });

  test('development previews stay disabled in every release build', () {
    expect(canEnableDevelopmentPreview(isReleaseMode: true, environment: 'local'), isFalse);
    expect(canEnableDevelopmentPreview(isReleaseMode: true, environment: 'production'), isFalse);
  });

  test('development previews require a non-release local build', () {
    expect(canEnableDevelopmentPreview(isReleaseMode: false, environment: 'local'), isTrue);
    expect(canEnableDevelopmentPreview(isReleaseMode: false, environment: 'staging'), isFalse);
  });
}
