final class CoeloBreakpoint {
  const CoeloBreakpoint({
    required this.name,
    required this.minWidth,
    required this.maxWidth,
    required this.columns,
    required this.margin,
    required this.gutter,
  });

  final String name;
  final double minWidth;
  final double maxWidth;
  final int columns;
  final double margin;
  final double gutter;
}

abstract final class CoeloBreakpoints {
  static const compact = CoeloBreakpoint(
    name: 'compact',
    minWidth: 0,
    maxWidth: 599,
    columns: 4,
    margin: 16,
    gutter: 16,
  );

  static const medium = CoeloBreakpoint(
    name: 'medium',
    minWidth: 600,
    maxWidth: 839,
    columns: 8,
    margin: 24,
    gutter: 20,
  );

  static const expanded = CoeloBreakpoint(
    name: 'expanded',
    minWidth: 840,
    maxWidth: 1199,
    columns: 12,
    margin: 32,
    gutter: 24,
  );

  static const large = CoeloBreakpoint(
    name: 'large',
    minWidth: 1200,
    maxWidth: 1599,
    columns: 12,
    margin: 40,
    gutter: 24,
  );

  static const extraLarge = CoeloBreakpoint(
    name: 'extraLarge',
    minWidth: 1600,
    maxWidth: double.infinity,
    columns: 12,
    margin: 48,
    gutter: 32,
  );
}
