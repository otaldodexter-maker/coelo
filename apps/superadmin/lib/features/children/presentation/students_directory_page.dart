import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import 'child_directory_controller.dart';
import 'child_directory_panel.dart';

/// Route target for the authorized read-only list of students.
///
/// It composes the shell around the CHILD read pipeline and nothing else. The
/// management actions of Alunos — link, transfer, edit, revoke — are not part
/// of this screen while their commands do not exist, so the page shows no
/// control that would fail or mislead.
final class StudentsDirectoryPage extends StatelessWidget {
  const StudentsDirectoryPage({
    required this.logout,
    this.read,
    this.sessionAvailable = false,
    this.institutionId,
    this.revision = 0,
    this.onDestinationSelected,
    super.key,
  });

  final LogoutAction logout;

  /// Absent by default: composition must inject a real read, never a fixture.
  final ChildDirectoryRead? read;
  final bool sessionAvailable;
  final String? institutionId;
  final int revision;
  final ValueChanged<String>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: theme.colorScheme.surface),
      child: SuperadminShell(
        logout: logout,
        title: 'Alunos',
        subtitle: 'Acompanhe os alunos autorizados no seu contexto.',
        currentDestination: 'students',
        onDestinationSelected: onDestinationSelected,
        child: ChildDirectoryPanel(
          key: const Key('students-directory'),
          read: read,
          sessionAvailable: sessionAvailable,
          institutionId: institutionId,
          revision: revision,
        ),
      ),
    );
  }
}
