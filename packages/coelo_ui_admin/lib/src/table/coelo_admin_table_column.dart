import 'package:flutter/widgets.dart';

typedef CoeloAdminCellBuilder<T> = Widget Function(BuildContext context, T item);

final class CoeloAdminTableColumn<T> {
  const CoeloAdminTableColumn({
    required this.id,
    required this.label,
    required this.initialWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.cellBuilder,
  });

  final String id;
  final String label;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final CoeloAdminCellBuilder<T> cellBuilder;
}
