import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/support_team_member.dart';

final class SupportAssigneeView extends StatelessWidget {
  const SupportAssigneeView({
    required this.ownerId,
    required this.collaboratorIds,
    required this.teamMembers,
    super.key,
  });

  final String? ownerId;
  final Set<String> collaboratorIds;
  final List<SupportTeamMember> teamMembers;

  @override
  Widget build(BuildContext context) {
    final members = [
      ...teamMembers.where((member) => member.id == ownerId),
      ...teamMembers.where((member) => member.id != ownerId && collaboratorIds.contains(member.id)),
    ];
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
