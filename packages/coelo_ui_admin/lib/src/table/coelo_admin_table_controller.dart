import 'package:flutter/foundation.dart';

typedef CoeloAdminTableFocusRow = bool Function(Object rowKey);

/// Imperative focus bridge for accessible list/detail table workflows.
final class CoeloAdminTableController {
  CoeloAdminTableFocusRow? _focusRow;

  bool focusRow(Object rowKey) => _focusRow?.call(rowKey) ?? false;

  @internal
  void attach(CoeloAdminTableFocusRow focusRow) {
    _focusRow = focusRow;
  }

  @internal
  void detach(CoeloAdminTableFocusRow focusRow) {
    if (identical(_focusRow, focusRow)) {
      _focusRow = null;
    }
  }
}
