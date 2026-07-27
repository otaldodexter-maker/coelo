import 'package:coelo_tokens/coelo_tokens.dart';
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
    const overlap = 20.0;
    return Semantics(
      label: members.map((member) => '${member.name}, ${_roleLabel(member.role)}').join('; '),
      child: ExcludeSemantics(
        child: SizedBox(
          width: CoeloSpacing.space8 + (members.length - 1) * overlap,
          height: CoeloSpacing.space8,
          child: Stack(
            children: [
              for (var index = 0; index < members.length; index++)
                Positioned(
                  left: index * overlap,
                  child: _AssigneeCircle(
                    member: members[index],
                    principal: members[index].id == ownerId,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AssigneeCircle extends StatelessWidget {
  const _AssigneeCircle({required this.member, required this.principal});

  final SupportTeamMember member;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '${member.name} · ${_roleLabel(member.role)}',
      child: Container(
        width: CoeloSpacing.space8,
        height: CoeloSpacing.space8,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: principal ? colors.primaryContainer : colors.secondaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: colors.surface, width: 2),
        ),
        child: Text(
          member.initials,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: principal ? colors.onPrimaryContainer : colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

String _roleLabel(SupportTeamRole role) => switch (role) {
  SupportTeamRole.support => 'Suporte',
  SupportTeamRole.development => 'Desenvolvimento',
  SupportTeamRole.customerSuccess => 'Sucesso do cliente',
  SupportTeamRole.qualityAssurance => 'Qualidade',
};
