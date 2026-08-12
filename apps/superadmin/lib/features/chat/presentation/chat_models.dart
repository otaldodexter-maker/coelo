/// Hierarchy kinds used to constrain conversation recipients server-side.
///
/// This UI model never authorises access: the database/RPC revalidates the
/// effective tenant and membership scope for every command.
enum ChatContextKind { institution, unit, group, activity, person, child, conversationGroup }

/// A context selection supplied by an authorised directory query.
final class SuperadminChatContextOption {
  const SuperadminChatContextOption({
    required this.id,
    required this.label,
    required this.kind,
    this.subtitle,
    this.children = const [],
    this.isGuardian = false,
    this.guardianIds = const {},
  });

  final String id;
  final String label;
  final ChatContextKind kind;
  final String? subtitle;
  final List<SuperadminChatContextOption> children;
  final bool isGuardian;
  final Set<String> guardianIds;
}
