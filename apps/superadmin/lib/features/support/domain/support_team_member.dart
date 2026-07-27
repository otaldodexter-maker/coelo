enum SupportTeamRole { support, development, customerSuccess, qualityAssurance }

final class SupportTeamMember {
  const SupportTeamMember({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
  });

  final String id;
  final String name;
  final String initials;
  final SupportTeamRole role;
}
