import 'package:flutter/material.dart';

@immutable
class UserPreferences {
  const UserPreferences({this.themeMode = ThemeMode.system, this.reduceMotion = false});

  final ThemeMode themeMode;
  final bool reduceMotion;

  UserPreferences copyWith({ThemeMode? themeMode, bool? reduceMotion}) => UserPreferences(
    themeMode: themeMode ?? this.themeMode,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.themeMode == themeMode &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(themeMode, reduceMotion);
}
