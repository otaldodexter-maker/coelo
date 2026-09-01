final class FormsEditorContext {
  const FormsEditorContext({required this.institutions});

  final List<FormsEditorInstitution> institutions;
}

final class FormsEditorInstitution {
  const FormsEditorInstitution({
    required this.id,
    required this.name,
    required this.canManageForms,
    required this.canPublishForms,
  });

  final String id;
  final String name;
  final bool canManageForms;
  final bool canPublishForms;
}

abstract interface class FormsEditorContextApi {
  Future<FormsEditorContext> getEditorContext();
}
