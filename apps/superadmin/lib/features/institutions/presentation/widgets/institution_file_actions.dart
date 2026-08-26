import 'package:flutter/material.dart';

import '../../../../app/activity/superadmin_activity.dart';

/// Fail-closed placeholder until institution import/export has a production
/// gateway, worker identity, private Storage lifecycle, and integrated tests.
class InstitutionFileActions extends StatelessWidget {
  const InstitutionFileActions({required this.activityController, this.compact = false, super.key});

  final SuperadminActivityController activityController;
  final bool compact;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
