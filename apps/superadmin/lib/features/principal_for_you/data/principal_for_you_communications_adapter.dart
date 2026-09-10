import '../../notices/domain/platform_notice.dart';
import '../../principal_shared/domain/principal_runtime_context.dart';
import '../domain/principal_for_you_preview_data.dart';

/// Actor scope used to evaluate the audience rules of a communication.
///
/// Derived from [PrincipalRuntimeContext]; the projection never reads audience
/// from the wire payload or from client-held claims beyond the active context.
final class PrincipalForYouAudienceScope {
  const PrincipalForYouAudienceScope({
    required this.institutionId,
    this.unitId,
    this.groupId,
    this.personId,
    this.roleCode,
    this.membershipId,
  });

  factory PrincipalForYouAudienceScope.fromRuntimeContext(PrincipalRuntimeContext context) =>
      PrincipalForYouAudienceScope(
        institutionId: context.institutionId,
        unitId: context.unitId,
        groupId: context.groupId,
        personId: context.personId,
        roleCode: context.roleCode,
        membershipId: context.membershipId,
      );

  final String institutionId;
  final String? unitId;
  final String? groupId;
  final String? personId;
  final String? roleCode;
  final String? membershipId;

  /// Every identifier that can be named by an exclusion list.
  Iterable<String> get allIdentifiers => <String?>[
    institutionId,
    unitId,
    groupId,
    personId,
    roleCode,
    membershipId,
  ].whereType<String>();

  String? identifierFor(NoticeAudienceDimension dimension) => switch (dimension) {
    NoticeAudienceDimension.institution => institutionId,
    NoticeAudienceDimension.unit => unitId,
    NoticeAudienceDimension.group => groupId,
    NoticeAudienceDimension.person => personId,
    NoticeAudienceDimension.role => roleCode,
    // `platform` is not a targetable identifier and `plan` has no counterpart in
    // PrincipalRuntimeContext today, so neither can be resolved to an actor id.
    NoticeAudienceDimension.platform || NoticeAudienceDimension.plan => null,
  };

  /// Value equality, because this scope is rebuilt from the runtime context on
  /// every route build. Comparing it by instance would make each rebuild look
  /// like a new actor and send the hub back to the server for nothing.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrincipalForYouAudienceScope &&
          other.institutionId == institutionId &&
          other.unitId == unitId &&
          other.groupId == groupId &&
          other.personId == personId &&
          other.roleCode == roleCode &&
          other.membershipId == membershipId;

  @override
  int get hashCode =>
      Object.hash(institutionId, unitId, groupId, personId, roleCode, membershipId);
}

/// Projects the shared Communications contract into the read-only Principal hub.
///
/// Popup-only fields deliberately do not cross this boundary.
final class PrincipalForYouCommunicationsAdapter {
  const PrincipalForYouCommunicationsAdapter._();

  /// Projects [communications] into ordered highlights.
  ///
  /// Popup (`CommunicationType.notice`) items are dropped entirely. Every other
  /// item is projected and carries `eligible` so the UI can keep rendering the
  /// full projection while only eligible items count as content.
  ///
  /// [scope] is required: an optional audience gate is one forgotten argument
  /// away from silently projecting communications the actor may not see.
  static List<PrincipalForYouHighlight> highlights(
    Iterable<PlatformNotice> communications, {
    required DateTime now,
    required PrincipalForYouAudienceScope scope,
  }) => PrincipalForYouPreviewData.orderHighlights(
    communications
        .where((item) => item.type != CommunicationType.notice)
        .map(
          (item) => PrincipalForYouHighlight(
            id: item.id,
            type: _type(item.type),
            priority: _priority(item.priority),
            eligible: isEligible(item, now: now, scope: scope),
            title: item.title,
            body: item.message,
            cta: item.linkLabel ?? item.buttonLabel,
          ),
        ),
  );

  /// Convenience entry point for callers that already hold a runtime context.
  static List<PrincipalForYouHighlight> highlightsForContext(
    Iterable<PlatformNotice> communications, {
    required DateTime now,
    required PrincipalRuntimeContext context,
  }) => highlights(
    communications,
    now: now,
    scope: PrincipalForYouAudienceScope.fromRuntimeContext(context),
  );

  /// Status + validity + audience gate.
  static bool isEligible(
    PlatformNotice item, {
    required DateTime now,
    required PrincipalForYouAudienceScope scope,
  }) {
    if (item.type == CommunicationType.notice) return false;
    if (item.status != NoticeStatus.active) return false;
    if (item.startsAt.isAfter(now)) return false;
    if (item.endsAt != null && !item.endsAt!.isAfter(now)) return false;
    return matchesAudience(item, scope);
  }

  /// Evaluates the audience rules that the current [PlatformNotice] model can
  /// actually express.
  ///
  /// Limitations of the existing model (no invented fields):
  /// - `NoticeAudienceDimension.plan` cannot be evaluated because
  ///   [PrincipalRuntimeContext] carries no plan identifier; such a rule never
  ///   grants access and its exclusions cannot be checked.
  /// - `NoticeAudience.coeloTeam` has no counterpart in the Principal runtime
  ///   context, so it never matches a Principal actor.
  /// - Rules are combined with OR (any rule that grants is enough), which
  ///   mirrors how `NoticeFormController` writes a single rule per notice.
  /// - Exclusions always win over any grant.
  static bool matchesAudience(PlatformNotice item, PrincipalForYouAudienceScope scope) {
    final selection = item.audienceSelection;

    for (final rule in selection.rules) {
      if (rule.excludedIds.isEmpty) continue;
      if (rule.dimension == NoticeAudienceDimension.platform) {
        // Platform-wide exclusions may name any entity the actor belongs to.
        if (scope.allIdentifiers.any(rule.excludedIds.contains)) return false;
        continue;
      }
      final identifier = scope.identifierFor(rule.dimension);
      if (identifier != null && rule.excludedIds.contains(identifier)) return false;
    }

    // Role gate: the form stores role targeting in `roleCodes`, not in a rule.
    if (selection.roleCodes.isNotEmpty) {
      final roleCode = scope.roleCode;
      if (roleCode == null || !selection.roleCodes.contains(roleCode)) return false;
    }

    if (selection.rules.isEmpty) {
      // Fallback to the coarse audience enum when no rule was persisted.
      return switch (item.audience) {
        NoticeAudience.everyone => true,
        NoticeAudience.role => selection.roleCodes.isNotEmpty,
        NoticeAudience.coeloTeam ||
        NoticeAudience.institution ||
        NoticeAudience.unit ||
        NoticeAudience.group ||
        NoticeAudience.person => false,
      };
    }

    if (item.audience == NoticeAudience.coeloTeam) return false;

    return selection.rules.any((rule) => _ruleGrants(rule, scope));
  }

  static bool _ruleGrants(NoticeAudienceRule rule, PrincipalForYouAudienceScope scope) {
    switch (rule.dimension) {
      case NoticeAudienceDimension.platform:
        // Platform reaches everyone; `targetIds` has no meaning at this level.
        return true;
      case NoticeAudienceDimension.plan:
        // Not evaluable with the current runtime context.
        return false;
      case NoticeAudienceDimension.institution:
      case NoticeAudienceDimension.unit:
      case NoticeAudienceDimension.group:
      case NoticeAudienceDimension.person:
      case NoticeAudienceDimension.role:
        final identifier = scope.identifierFor(rule.dimension);
        if (identifier == null) return false;
        if (rule.selectAll) return true;
        return rule.targetIds.contains(identifier);
    }
  }

  static PrincipalForYouContentType _type(CommunicationType type) => switch (type) {
    CommunicationType.highlight => PrincipalForYouContentType.highlight,
    CommunicationType.content => PrincipalForYouContentType.content,
    CommunicationType.forYou => PrincipalForYouContentType.forYou,
    CommunicationType.notice => throw ArgumentError.value(type, 'type'),
  };

  static int _priority(NoticePriority priority) => switch (priority) {
    NoticePriority.urgent => 0,
    NoticePriority.important => 10,
    NoticePriority.routine => 20,
  };
}
