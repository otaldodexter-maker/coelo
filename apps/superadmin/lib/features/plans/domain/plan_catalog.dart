enum PlanStatus { active, archived }

enum PlanDirectoryView { cards, table }

enum PlanDataState { ready, loading, error, unauthorized }

enum PlanSurface { admin, principal }

enum PlanFeature {
  communication,
  agenda,
  invitations,
  chat,
  notices,
  routine,
  happens,
  now,
  moments,
}

extension PlanFeaturePresentation on PlanFeature {
  String get label => switch (this) {
    PlanFeature.communication => 'Comunicação',
    PlanFeature.agenda => 'Agenda',
    PlanFeature.invitations => 'Convites',
    PlanFeature.chat => 'Chat',
    PlanFeature.notices => 'Avisos',
    PlanFeature.routine => 'Rotina',
    PlanFeature.happens => 'Happens',
    PlanFeature.now => 'Now',
    PlanFeature.moments => 'Moments',
  };

  PlanSurface get surface => switch (this) {
    PlanFeature.invitations || PlanFeature.notices => PlanSurface.admin,
    PlanFeature.happens || PlanFeature.now || PlanFeature.moments => PlanSurface.principal,
    _ => PlanSurface.admin,
  };
}

final class PlanLimits {
  const PlanLimits({
    required this.units,
    required this.memberships,
    required this.storageGb,
    required this.mediaGb,
  });

  final int units;
  final int memberships;
  final int storageGb;
  final int mediaGb;

  PlanLimits copyWith({int? units, int? memberships, int? storageGb, int? mediaGb}) => PlanLimits(
    units: units ?? this.units,
    memberships: memberships ?? this.memberships,
    storageGb: storageGb ?? this.storageGb,
    mediaGb: mediaGb ?? this.mediaGb,
  );
}

final class PlanLinkedInstitution {
  const PlanLinkedInstitution({
    required this.id,
    required this.name,
    required this.subscriptionStatus,
    required this.startsAt,
    required this.unitsWithOverride,
  });

  final String id;
  final String name;
  final String subscriptionStatus;
  final DateTime startsAt;
  final int unitsWithOverride;
}

final class PlanCatalog {
  const PlanCatalog({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.status,
    required this.features,
    required this.limits,
    this.usedByInstitutionCount = 0,
    this.revision = 1,
  });

  final String id;
  final String name;
  final String code;
  final String description;
  final PlanStatus status;
  final Set<PlanFeature> features;
  final PlanLimits limits;
  final int usedByInstitutionCount;
  final int revision;

  PlanCatalog copyWith({
    String? name,
    String? description,
    PlanStatus? status,
    Set<PlanFeature>? features,
    PlanLimits? limits,
    int? usedByInstitutionCount,
    int? revision,
  }) => PlanCatalog(
    id: id,
    name: name ?? this.name,
    code: code,
    description: description ?? this.description,
    status: status ?? this.status,
    features: features ?? this.features,
    limits: limits ?? this.limits,
    usedByInstitutionCount: usedByInstitutionCount ?? this.usedByInstitutionCount,
    revision: revision ?? this.revision,
  );
}

final class PlanDraft {
  const PlanDraft({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.status,
    required this.features,
    required this.limits,
  });

  final String id;
  final String name;
  final String code;
  final String description;
  final PlanStatus status;
  final Set<PlanFeature> features;
  final PlanLimits limits;

  PlanCatalog toPlan({int usedByInstitutionCount = 0}) => PlanCatalog(
    id: id,
    name: name,
    code: code,
    description: description,
    status: status,
    features: features,
    limits: limits,
    usedByInstitutionCount: usedByInstitutionCount,
  );
}

final class PlanQuery {
  const PlanQuery({this.search = '', this.status, this.feature, this.page = 1, this.pageSize = 11});

  final String search;
  final PlanStatus? status;
  final PlanFeature? feature;
  final int page;
  final int pageSize;

  PlanQuery copyWith({
    String? search,
    PlanStatus? status,
    bool clearStatus = false,
    PlanFeature? feature,
    bool clearFeature = false,
    int? page,
    int? pageSize,
  }) => PlanQuery(
    search: search ?? this.search,
    status: clearStatus ? null : status ?? this.status,
    feature: clearFeature ? null : feature ?? this.feature,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );
}

final class PlanPage {
  const PlanPage({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.pageSize,
  });

  final List<PlanCatalog> items;
  final int totalItems;
  final int page;
  final int pageSize;

  int get totalPages => totalItems == 0 ? 1 : (totalItems / pageSize).ceil();
}
