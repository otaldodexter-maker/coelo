import 'package:flutter/foundation.dart';

import 'daily_routine.dart';

final class DailyRoutineController extends ChangeNotifier {
  DailyRoutineController({required this.repository, required this.permissions});

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;

  void publishInstitutionUpdate({required bool mandatory}) {
    _requireWrite();
    repository.publishInstitutionUpdate(mandatory: mandatory);
    notifyListeners();
  }

  void applyToParticipants(
    Set<String> participantIds, {
    required String fieldId,
    required Object? value,
    required bool overwrite,
  }) {
    _requireWrite();
    repository.applyToParticipants(
      participantIds,
      fieldId: fieldId,
      value: value,
      overwrite: overwrite,
    );
    notifyListeners();
  }

  void setParticipantFeeling(String participantId, DailyRoutineFeeling feeling) {
    _requireWrite();
    repository.setParticipantFeeling(participantId, feeling);
    notifyListeners();
  }

  void clearParticipantFeeling(String participantId) {
    _requireWrite();
    repository.clearParticipantFeeling(participantId);
    notifyListeners();
  }

  void suggestFeeling(String text) {
    _requireWrite();
    repository.suggestFeeling(text);
    notifyListeners();
  }

  void _requireWrite() {
    if (!permissions.canManage) throw StateError('Modo somente leitura.');
  }
}
