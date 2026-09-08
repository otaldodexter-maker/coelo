import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';

final class FormsAuthoringInstitution {
  const FormsAuthoringInstitution({required this.id, required this.publicName});
  final String id;
  final String publicName;
}

final class FormsAuthoringInstitutionCursor {
  const FormsAuthoringInstitutionCursor({required this.nameKey, required this.id});
  final String nameKey;
  final String id;
}

final class FormsAuthoringInstitutionQuery {
  const FormsAuthoringInstitutionQuery({this.search = '', this.limit = 20, this.cursor});
  final String search;
  final int limit;
  final FormsAuthoringInstitutionCursor? cursor;
}

final class FormsAuthoringInstitutionPage {
  FormsAuthoringInstitutionPage({required List<FormsAuthoringInstitution> items, this.nextCursor})
    : items = List.unmodifiable(items);
  final List<FormsAuthoringInstitution> items;
  final FormsAuthoringInstitutionCursor? nextCursor;
  bool get hasMore => nextCursor != null;
}

final class FormsAuthoringEditor {
  const FormsAuthoringEditor({
    required this.definition,
    required this.institution,
    required this.canManage,
  });
  final FormDefinition definition;
  final FormsAuthoringInstitution institution;
  final bool canManage;
}

/// Internal draft-only boundary. Absence of publish/distribution operations is
/// feature availability, not a claim about the actor's effective grants.
abstract interface class FormsAuthoringApi {
  Future<FormsAuthoringInstitutionPage> listInstitutions(FormsAuthoringInstitutionQuery query);
  Future<FormsAuthoringEditor> getEditor(String formId);
  Future<FormDefinition> saveDraft(FormCommand<FormDefinition> command);
}
