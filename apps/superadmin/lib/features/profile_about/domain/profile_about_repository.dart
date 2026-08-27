import 'dart:math';

import 'package:coelo_domain/profile_about.dart';

abstract interface class ProfileAboutRepository {
  Future<ProfileAboutPage?> load(ProfileAboutSubjectRef subject, {ProfileAboutAudience? preview});

  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  });
}

final class ProfileAboutSaveResult {
  const ProfileAboutSaveResult({
    required this.pageId,
    required this.version,
    required this.official,
  });
  final String pageId;
  final int version;
  final List<ProfileAboutOfficialDestinationResult> official;
}

final class ProfileAboutOfficialDestinationResult {
  const ProfileAboutOfficialDestinationResult({
    required this.key,
    required this.status,
    this.message,
  });
  final ProfileAboutFieldKey key;
  final String status;
  final String? message;
}

final class ProfileAboutUnauthorizedException implements Exception {}

final class ProfileAboutConflictException implements Exception {}

final class ProfileAboutUnavailableException implements Exception {}

String newProfileAboutRequestId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
