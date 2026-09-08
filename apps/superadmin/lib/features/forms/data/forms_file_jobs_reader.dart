import 'package:coelo_api/coelo_api.dart';

/// Context supplied by the candidate file-jobs projection for export actions.
/// It does not grant access or replace server-side concurrency checks.
final class FormsFileJobsContext {
  const FormsFileJobsContext({
    required this.formId,
    required this.managementVersion,
    required this.page,
  });

  final String formId;
  final int managementVersion;
  final FormCursorPage<FormFileJob> page;
}

/// Reads export context without requiring overview or authoring capabilities.
abstract interface class FormsFileJobsReader {
  Future<FormsFileJobsContext> listFileJobsContext({
    required String formId,
    String? cursor,
    int limit = 25,
  });
}
