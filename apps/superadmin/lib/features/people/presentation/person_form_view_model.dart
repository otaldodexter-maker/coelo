import 'package:flutter/foundation.dart';

import '../domain/person_directory.dart';

enum PersonFormStep {
  identity('Identidade'),
  contexts('Vínculos contextuais'),
  review('Revisão');

  const PersonFormStep(this.label);
  final String label;
}

final class PersonFormViewModel extends ChangeNotifier {
  PersonFormViewModel(this._repository, {this.original})
    : type = original?.type ?? PersonType.adult,
      firstName = original?.firstName ?? '',
      lastName = original?.lastName ?? '',
      displayName = original?.displayName ?? '',
      legalName = original?.legalName ?? '',
      memberships = [...?original?.memberships],
      childContexts = [...?original?.childContexts];

  final PersonDirectoryRepository _repository;
  final PersonDirectoryItem? original;

  PersonFormStep step = PersonFormStep.identity;
  PersonType type;
  String firstName;
  String lastName;
  String displayName;
  String legalName;
  final List<PersonMembership> memberships;
  final List<PersonChildContext> childContexts;
  final List<PersonMembershipChange> membershipChanges = [];
  final List<PersonChildContextChange> childContextChanges = [];
  bool saving = false;
  Object? saveError;

  bool get isEditing => original != null;
  bool get isReadOnly => original?.type == PersonType.service;

  void next() {
    if (step.index < PersonFormStep.values.length - 1) {
      step = PersonFormStep.values[step.index + 1];
      notifyListeners();
    }
  }

  void previous() {
    if (step.index > 0) {
      step = PersonFormStep.values[step.index - 1];
      notifyListeners();
    }
  }

  void addMembership(PersonMembership membership) {
    memberships.add(membership);
    membershipChanges.add(PersonMembershipChange.add(membership));
    notifyListeners();
  }

  void updateMembership(PersonMembership membership) {
    final index = memberships.indexWhere((item) => item.id == membership.id);
    if (index < 0) return;
    memberships[index] = membership;
    final pendingAdd = membershipChanges.indexWhere(
      (change) =>
          change.membership.id == membership.id && change.kind == PersonMembershipChangeKind.add,
    );
    membershipChanges.removeWhere(
      (change) =>
          change.membership.id == membership.id && change.kind == PersonMembershipChangeKind.update,
    );
    if (pendingAdd >= 0) {
      membershipChanges[pendingAdd] = PersonMembershipChange.add(membership);
    } else {
      membershipChanges.add(PersonMembershipChange.update(membership));
    }
    notifyListeners();
  }

  void removeMembership(PersonMembership membership) {
    memberships.removeWhere((item) => item.id == membership.id);
    final wasPendingAdd = membershipChanges.any(
      (change) =>
          change.membership.id == membership.id && change.kind == PersonMembershipChangeKind.add,
    );
    membershipChanges.removeWhere((change) => change.membership.id == membership.id);
    if (wasPendingAdd) {
      notifyListeners();
      return;
    }
    membershipChanges.add(PersonMembershipChange.remove(membership));
    notifyListeners();
  }

  void addChildContext(PersonChildContext context) {
    childContexts.add(context);
    childContextChanges.add(PersonChildContextChange.add(context));
    notifyListeners();
  }

  void updateChildContext(PersonChildContext context) {
    final index = childContexts.indexWhere((item) => item.id == context.id);
    if (index < 0) return;
    childContexts[index] = context;
    final pendingAdd = childContextChanges.indexWhere(
      (change) =>
          change.context.id == context.id && change.kind == PersonChildContextChangeKind.add,
    );
    childContextChanges.removeWhere(
      (change) =>
          change.context.id == context.id && change.kind == PersonChildContextChangeKind.update,
    );
    if (pendingAdd >= 0) {
      childContextChanges[pendingAdd] = PersonChildContextChange.add(context);
    } else {
      childContextChanges.add(PersonChildContextChange.update(context));
    }
    notifyListeners();
  }

  void removeChildContext(PersonChildContext context) {
    childContexts.removeWhere((item) => item.id == context.id);
    final wasPendingAdd = childContextChanges.any(
      (change) =>
          change.context.id == context.id && change.kind == PersonChildContextChangeKind.add,
    );
    childContextChanges.removeWhere((change) => change.context.id == context.id);
    if (wasPendingAdd) {
      notifyListeners();
      return;
    }
    childContextChanges.add(PersonChildContextChange.remove(context));
    notifyListeners();
  }

  Future<PersonDirectoryItem> save() async {
    if (isReadOnly) throw const PersonDirectoryReadOnlyException();
    if ([firstName, lastName, displayName, legalName].any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Identity fields are required.');
    }
    saving = true;
    saveError = null;
    notifyListeners();
    try {
      final value = original == null
          ? await _repository.createDraft(
              PersonDraft(
                type: type,
                firstName: firstName.trim(),
                lastName: lastName.trim(),
                displayName: displayName.trim(),
                legalName: legalName.trim(),
                memberships: memberships
                    .map(
                      (item) => PersonMembershipDraft(
                        institutionId: item.institutionId,
                        unitId: item.unitId,
                        groupId: item.groupId,
                        role: item.role,
                      ),
                    )
                    .toList(growable: false),
                childContexts: childContexts
                    .map(
                      (item) => PersonChildContextDraft(
                        institutionId: item.institutionId,
                        unitId: item.unitId,
                        groupId: item.groupId,
                      ),
                    )
                    .toList(growable: false),
              ),
            )
          : await _repository.updatePerson(
              PersonUpdate(
                personId: original!.id,
                expectedUpdatedAt: original!.updatedAt,
                firstName: firstName.trim(),
                lastName: lastName.trim(),
                displayName: displayName.trim(),
                legalName: legalName.trim(),
                membershipChanges: membershipChanges,
                childContextChanges: childContextChanges,
              ),
            );
      return value;
    } on Object catch (error) {
      saveError = error;
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
