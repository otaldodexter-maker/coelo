import 'package:coelo_domain/profile_about.dart';

abstract interface class ActivityProfileAboutRepository {
  bool get isAvailable;

  Future<ProfileAboutPage> load({required String institutionId, String? activityId});

  Future<ProfileAboutPage> save({
    required ProfileAboutPage page,
    required String institutionId,
    required String activityId,
    required String requestId,
  });
}

final class UnavailableActivityProfileAboutRepository implements ActivityProfileAboutRepository {
  const UnavailableActivityProfileAboutRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<ProfileAboutPage> load({required String institutionId, String? activityId}) =>
      Future.error(const ActivityProfileAboutUnavailableException());

  @override
  Future<ProfileAboutPage> save({
    required ProfileAboutPage page,
    required String institutionId,
    required String activityId,
    required String requestId,
  }) => Future.error(const ActivityProfileAboutUnavailableException());
}

final class ActivityProfileAboutUnavailableException implements Exception {
  const ActivityProfileAboutUnavailableException();
}

final class ActivityProfileAboutUnauthorizedException implements Exception {
  const ActivityProfileAboutUnauthorizedException();
}
