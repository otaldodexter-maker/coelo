import 'package:flutter/material.dart';

class ShellAccountDestination {
  const ShellAccountDestination(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const shellAccountDestinations = <ShellAccountDestination>[
  ShellAccountDestination('profile', 'Perfil', Icons.person_outline),
  ShellAccountDestination('settings', 'Configurações', Icons.settings_outlined),
];
