import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/support_team_member.dart';

final class SupportAssigneeView extends StatelessWidget {
  const SupportAssigneeView({required this.assigneeIds, required this.teamMembers, super.key});

  final Set<String> assigneeIds;
  final List<SupportTeamMember> teamMembers;

  @override
  Widget build(BuildContext context) {
    final members = teamMembers.where((member) => assigneeIds.contains(member.id)).toList();
    if (members.isEmpty) {
      return const Text('Sem responsável', maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return CoeloAdminAssigneeStack(
      items: [
        for (final member in members)
          CoeloAdminAssigneeItem(
            label: member.name,
            initials: member.initials,
            roleLabel: _roleLabel(member.role),
          ),
      ],
    );
  }
}

String _roleLabel(SupportTeamRole role) => switch (role) {
  SupportTeamRole.support => 'Suporte',
  SupportTeamRole.development => 'Desenvolvimento',
  SupportTeamRole.customerSuccess => 'Sucesso do cliente',
  SupportTeamRole.qualityAssurance => 'Qualidade',
};
