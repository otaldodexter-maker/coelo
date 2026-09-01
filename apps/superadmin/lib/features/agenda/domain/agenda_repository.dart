import 'dart:async';

import 'package:flutter/foundation.dart';

import 'agenda_models.dart';

abstract class AgendaRepository extends ChangeNotifier {
  DateTime get referenceDate;
  List<AgendaItem> get items;
  List<AgendaContext> get contexts;
  List<GuardianBirthdayRequest> get requests;
  List<AgendaPublicationRequest> get publicationRequests;
  bool get isLoading;
  String? get errorMessage;
  String? get lastSavedItemId;
  bool get supportsOccurrenceScopedEdits;

  AgendaItem? itemById(String id);
  GuardianBirthdayRequest? requestById(String id);

  Future<void> loadEvents({
    required DateTime from,
    required DateTime to,
    String? institutionId,
    String search = '',
  });
  Future<void> loadContexts();
  Future<void> loadItem(String id);
  Future<void> loadRequests();

  FutureOr<AgendaMutationResult> requestPublication(String itemId, {required String requestedBy});
  FutureOr<AgendaMutationResult> decidePublicationRequest({
    required String requestId,
    required bool approve,
    required String decidedBy,
    required String reason,
  });
  FutureOr<AgendaMutationResult> cancelItem(String id, {required String actorName});
  FutureOr<AgendaMutationResult> restoreItem(
    String id, {
    required String actorName,
    String? actorContextId,
    bool overrideConflict = false,
    String? reason,
  });
  FutureOr<AgendaMutationResult> deleteDraft(String id);
  FutureOr<AgendaMutationResult> recordOccurrenceEdit({
    required String itemId,
    required DateTime occurrenceStartsAt,
    required AgendaOccurrenceEditScope scope,
    required String actorName,
  });
  FutureOr<AgendaMutationResult> saveItem(
    AgendaItem item, {
    required String actorContextId,
    String actorName = 'Owner Coelo',
    bool overrideConflict = false,
    String? reason,
  });

  List<AgendaItem> itemsForInstitution(String id);
  List<AgendaItem> itemsForContext(String id);
  List<AgendaOccurrence> occurrencesBetween(DateTime start, DateTime end);
  PermissionResolution resolveCapability(String contextId, AgendaCapability capability);
  bool setCapabilityRestricted(String contextId, AgendaCapability capability, bool restricted);
  FutureOr<RequestDecisionResult> decideRequest({
    required String requestId,
    required String actorContextId,
    required String actorName,
    required bool approve,
    String? reason,
  });
}
