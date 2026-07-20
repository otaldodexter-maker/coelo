import 'package:flutter/material.dart';

class SuperadminThemeModeScope extends InheritedWidget {
  const SuperadminThemeModeScope({
    required this.mode,
    required this.onChanged,
    required super.child,
    super.key,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static SuperadminThemeModeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SuperadminThemeModeScope>();
  }

  static SuperadminThemeModeScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'SuperadminThemeModeScope not found in context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(SuperadminThemeModeScope oldWidget) {
    return mode != oldWidget.mode || onChanged != oldWidget.onChanged;
  }
}
