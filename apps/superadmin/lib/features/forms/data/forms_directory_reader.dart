import 'package:coelo_api/coelo_api.dart';

/// Read-only directory boundary for the internal Superadmin realm.
abstract interface class FormsDirectoryReader {
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query);
}
