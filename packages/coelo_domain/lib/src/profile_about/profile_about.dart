enum ProfileAboutSubjectType { institution, unit, group, activity, person }

enum ProfileAboutVisibility { profileAccess, linked, team, hidden }

enum ProfileAboutAudience { profileAccess, linked, team }

enum ProfileAboutOrigin { manual, suggestedOfficial, copiedOfficial, editedAfterCopy }

enum ProfileAboutSectionType { text, iconList, location, contact, hours, links, structuredInfo }

enum ProfileAboutSectionState { draft, published, archived }

enum ProfileAboutMove { up, down }

enum ProfileAboutOfficialUpdateDecision { aboutOnly, aboutAndOfficial }

enum ProfileAboutFieldKey {
  displayName,
  description,
  displayAddress,
  preciseLocation,
  institutionalLocation,
  phone,
  mobile,
  email,
  website,
  serviceHours,
  generalHours,
  cityState,
  foundedOn,
  institutionType,
  visibleLinks,
  institutionLink,
  unitLink,
  activityLinks,
  teamLinks,
  proposal,
  methodology,
  objective,
  audience,
  materials,
  generalGuidance,
  importantInformation,
  identityInstitutional,
  inheritanceOrigin,
  professionalRole,
}

final class ProfileAboutSubjectRef {
  const ProfileAboutSubjectRef({
    required this.type,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.activityId,
    this.personId,
  }) : assert(
         (type == ProfileAboutSubjectType.institution && institutionId != null) ||
             (type == ProfileAboutSubjectType.unit && institutionId != null && unitId != null) ||
             (type == ProfileAboutSubjectType.group &&
                 institutionId != null &&
                 unitId != null &&
                 groupId != null) ||
             (type == ProfileAboutSubjectType.activity &&
                 institutionId != null &&
                 activityId != null) ||
             (type == ProfileAboutSubjectType.person && institutionId != null && personId != null),
       );

  final ProfileAboutSubjectType type;
  final String? institutionId;
  final String? unitId;
  final String? groupId;
  final String? activityId;
  final String? personId;

  String get subjectId => switch (type) {
    ProfileAboutSubjectType.institution => institutionId!,
    ProfileAboutSubjectType.unit => unitId!,
    ProfileAboutSubjectType.group => groupId!,
    ProfileAboutSubjectType.activity => activityId!,
    ProfileAboutSubjectType.person => personId!,
  };
}

final class ProfileAboutSuggestion {
  const ProfileAboutSuggestion({
    required this.key,
    required this.value,
    required this.sourceLabel,
    this.latitude,
    this.longitude,
  });

  final ProfileAboutFieldKey key;
  final String value;
  final String sourceLabel;
  final double? latitude;
  final double? longitude;
}

final class ProfileAboutField {
  const ProfileAboutField({
    required this.key,
    required this.value,
    this.visibility = ProfileAboutVisibility.profileAccess,
    this.origin = ProfileAboutOrigin.manual,
    this.sourceLabel,
    this.latitude,
    this.longitude,
  });

  const ProfileAboutField.location({
    required String address,
    required double latitude,
    required double longitude,
    ProfileAboutVisibility visibility = ProfileAboutVisibility.profileAccess,
    ProfileAboutOrigin origin = ProfileAboutOrigin.manual,
    String? sourceLabel,
  }) : this(
         key: ProfileAboutFieldKey.preciseLocation,
         value: address,
         latitude: latitude,
         longitude: longitude,
         visibility: visibility,
         origin: origin,
         sourceLabel: sourceLabel,
       );

  final ProfileAboutFieldKey key;
  final String value;
  final ProfileAboutVisibility visibility;
  final ProfileAboutOrigin origin;
  final String? sourceLabel;
  final double? latitude;
  final double? longitude;

  bool get isValid {
    if (value.trim().isEmpty || value.length > 4000) return false;
    if (key != ProfileAboutFieldKey.preciseLocation) return true;
    final lat = latitude;
    final lng = longitude;
    return lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  ProfileAboutField copyWith({
    String? value,
    ProfileAboutVisibility? visibility,
    ProfileAboutOrigin? origin,
    String? sourceLabel,
    double? latitude,
    double? longitude,
  }) {
    final nextValue = value ?? this.value;
    final changedAfterCopy =
        nextValue != this.value &&
        (this.origin == ProfileAboutOrigin.copiedOfficial ||
            this.origin == ProfileAboutOrigin.suggestedOfficial);
    return ProfileAboutField(
      key: key,
      value: nextValue,
      visibility: visibility ?? this.visibility,
      origin: origin ?? (changedAfterCopy ? ProfileAboutOrigin.editedAfterCopy : this.origin),
      sourceLabel: sourceLabel ?? this.sourceLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

final class ProfileAboutSection {
  const ProfileAboutSection({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.position,
    this.items = const [],
    this.visibility = ProfileAboutVisibility.profileAccess,
    this.state = ProfileAboutSectionState.draft,
    this.origin = ProfileAboutOrigin.manual,
    this.revision = 1,
  });

  final String id;
  final ProfileAboutSectionType type;
  final String title;
  final String body;
  final int position;
  final List<String> items;
  final ProfileAboutVisibility visibility;
  final ProfileAboutSectionState state;
  final ProfileAboutOrigin origin;
  final int revision;

  bool get isEmpty =>
      title.trim().isEmpty && body.trim().isEmpty && items.every((item) => item.trim().isEmpty);

  ProfileAboutSection copyWith({
    String? id,
    String? title,
    String? body,
    int? position,
    List<String>? items,
    ProfileAboutVisibility? visibility,
    ProfileAboutSectionState? state,
    ProfileAboutOrigin? origin,
    int? revision,
  }) => ProfileAboutSection(
    id: id ?? this.id,
    type: type,
    title: title ?? this.title,
    body: body ?? this.body,
    position: position ?? this.position,
    items: List.unmodifiable(items ?? this.items),
    visibility: visibility ?? this.visibility,
    state: state ?? this.state,
    origin: origin ?? this.origin,
    revision: revision ?? this.revision,
  );
}

final class ProfileAboutPage {
  ProfileAboutPage({
    required this.subject,
    required this.version,
    required List<ProfileAboutField> fields,
    required List<ProfileAboutSection> sections,
  }) : fields = List.unmodifiable(fields),
       sections = List.unmodifiable(sections);

  factory ProfileAboutPage.empty(ProfileAboutSubjectRef subject) =>
      ProfileAboutPage(subject: subject, version: 0, fields: const [], sections: const []);

  final ProfileAboutSubjectRef subject;
  final int version;
  final List<ProfileAboutField> fields;
  final List<ProfileAboutSection> sections;

  ProfileAboutPage copySuggestions(
    Iterable<ProfileAboutSuggestion> suggestions,
    Set<ProfileAboutFieldKey> selected,
  ) {
    final allowed = ProfileAboutPolicy.allowedFields(subject.type);
    final next = <ProfileAboutFieldKey, ProfileAboutField>{
      for (final field in fields) field.key: field,
    };
    for (final suggestion in suggestions) {
      if (!selected.contains(suggestion.key) || !allowed.contains(suggestion.key)) continue;
      next[suggestion.key] = ProfileAboutField(
        key: suggestion.key,
        value: suggestion.value,
        latitude: suggestion.latitude,
        longitude: suggestion.longitude,
        origin: ProfileAboutOrigin.copiedOfficial,
        sourceLabel: suggestion.sourceLabel,
      );
    }
    return _copy(fields: next.values.toList(growable: false));
  }

  ProfileAboutPage replaceField(ProfileAboutField field) {
    if (!ProfileAboutPolicy.allowedFields(subject.type).contains(field.key)) return this;
    final next = [...fields.where((item) => item.key != field.key), field];
    return _copy(fields: next);
  }

  ProfileAboutPage addSection(ProfileAboutSection section) => _copy(
    sections: [
      ...sections,
      section.copyWith(position: sections.length),
    ],
  );

  ProfileAboutPage updateSection(
    String id, {
    String? title,
    String? body,
    List<String>? items,
    ProfileAboutVisibility? visibility,
    ProfileAboutSectionState? state,
  }) => _copy(
    sections: [
      for (final section in sections)
        if (section.id == id)
          section.copyWith(
            title: title,
            body: body,
            items: items,
            visibility: visibility,
            state: state,
            revision: section.revision + 1,
          )
        else
          section,
    ],
  );

  ProfileAboutPage duplicateSection(String id, String newId) {
    final source = sections.where((section) => section.id == id).firstOrNull;
    if (source == null) return this;
    return addSection(
      source.copyWith(
        id: newId,
        title: '${source.title} (cópia)',
        origin: ProfileAboutOrigin.manual,
        revision: 1,
      ),
    );
  }

  ProfileAboutPage removeSection(String id) {
    final remaining = sections.where((section) => section.id != id).toList();
    return _copy(
      sections: [
        for (var index = 0; index < remaining.length; index++)
          remaining[index].copyWith(position: index),
      ],
    );
  }

  ProfileAboutPage rebind(ProfileAboutSubjectRef subject, {int? version}) => ProfileAboutPage(
    subject: subject,
    version: version ?? this.version,
    fields: fields,
    sections: sections,
  );

  ProfileAboutPage moveSection(String sectionId, ProfileAboutMove direction) {
    final ordered = [...sections]..sort((a, b) => a.position.compareTo(b.position));
    final from = ordered.indexWhere((section) => section.id == sectionId);
    if (from < 0) return this;
    final to = direction == ProfileAboutMove.up ? from - 1 : from + 1;
    if (to < 0 || to >= ordered.length) return this;
    final moved = ordered.removeAt(from);
    ordered.insert(to, moved);
    return _copy(
      sections: [
        for (var index = 0; index < ordered.length; index++)
          ordered[index].copyWith(position: index),
      ],
    );
  }

  ProfileAboutPage reorderSection(int oldIndex, int newIndex) {
    final ordered = [...sections]..sort((a, b) => a.position.compareTo(b.position));
    if (oldIndex < 0 || oldIndex >= ordered.length || newIndex < 0 || newIndex > ordered.length) {
      return this;
    }
    if (newIndex > oldIndex) newIndex--;
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    return _copy(
      sections: [
        for (var index = 0; index < ordered.length; index++)
          ordered[index].copyWith(position: index),
      ],
    );
  }

  ProfileAboutPage project(ProfileAboutAudience audience) => _copy(
    fields: fields.where((field) => _isVisible(field.visibility, audience)).toList(growable: false),
    sections: sections
        .where((section) => !section.isEmpty && _isVisible(section.visibility, audience))
        .toList(growable: false),
  );

  ProfileAboutPage _copy({List<ProfileAboutField>? fields, List<ProfileAboutSection>? sections}) =>
      ProfileAboutPage(
        subject: subject,
        version: version,
        fields: fields ?? this.fields,
        sections: sections ?? this.sections,
      );
}

abstract final class ProfileAboutPolicy {
  static Set<ProfileAboutFieldKey> allowedFields(ProfileAboutSubjectType type) => switch (type) {
    ProfileAboutSubjectType.institution => _institutionFields,
    ProfileAboutSubjectType.unit => _unitFields,
    ProfileAboutSubjectType.group => _groupFields,
    ProfileAboutSubjectType.activity => _activityFields,
    ProfileAboutSubjectType.person => _personFields,
  };

  static const _institutionFields = <ProfileAboutFieldKey>{
    ProfileAboutFieldKey.displayName,
    ProfileAboutFieldKey.displayAddress,
    ProfileAboutFieldKey.preciseLocation,
    ProfileAboutFieldKey.phone,
    ProfileAboutFieldKey.mobile,
    ProfileAboutFieldKey.email,
    ProfileAboutFieldKey.website,
    ProfileAboutFieldKey.serviceHours,
    ProfileAboutFieldKey.cityState,
    ProfileAboutFieldKey.foundedOn,
    ProfileAboutFieldKey.institutionType,
    ProfileAboutFieldKey.visibleLinks,
    ProfileAboutFieldKey.identityInstitutional,
  };
  static const _unitFields = <ProfileAboutFieldKey>{
    ProfileAboutFieldKey.displayName,
    ProfileAboutFieldKey.displayAddress,
    ProfileAboutFieldKey.preciseLocation,
    ProfileAboutFieldKey.phone,
    ProfileAboutFieldKey.mobile,
    ProfileAboutFieldKey.email,
    ProfileAboutFieldKey.website,
    ProfileAboutFieldKey.serviceHours,
    ProfileAboutFieldKey.cityState,
    ProfileAboutFieldKey.visibleLinks,
    ProfileAboutFieldKey.unitLink,
    ProfileAboutFieldKey.inheritanceOrigin,
  };
  static const _groupFields = <ProfileAboutFieldKey>{
    ProfileAboutFieldKey.displayName,
    ProfileAboutFieldKey.description,
    ProfileAboutFieldKey.proposal,
    ProfileAboutFieldKey.generalHours,
    ProfileAboutFieldKey.unitLink,
    ProfileAboutFieldKey.institutionLink,
    ProfileAboutFieldKey.activityLinks,
    ProfileAboutFieldKey.teamLinks,
    ProfileAboutFieldKey.importantInformation,
  };
  static const _activityFields = <ProfileAboutFieldKey>{
    ProfileAboutFieldKey.displayName,
    ProfileAboutFieldKey.description,
    ProfileAboutFieldKey.objective,
    ProfileAboutFieldKey.audience,
    ProfileAboutFieldKey.generalHours,
    ProfileAboutFieldKey.institutionalLocation,
    ProfileAboutFieldKey.methodology,
    ProfileAboutFieldKey.materials,
    ProfileAboutFieldKey.generalGuidance,
    ProfileAboutFieldKey.teamLinks,
  };
  static const _personFields = <ProfileAboutFieldKey>{
    ProfileAboutFieldKey.displayName,
    ProfileAboutFieldKey.cityState,
    ProfileAboutFieldKey.professionalRole,
    ProfileAboutFieldKey.visibleLinks,
  };
}

final class ProfileAboutOfficialUpdateRequest {
  const ProfileAboutOfficialUpdateRequest({
    required this.field,
    required this.aboutValue,
    required this.canUpdateOfficialData,
  });

  final ProfileAboutFieldKey field;
  final String aboutValue;
  final bool canUpdateOfficialData;

  List<ProfileAboutOfficialUpdateDecision> get availableDecisions => [
    ProfileAboutOfficialUpdateDecision.aboutOnly,
    if (canUpdateOfficialData) ProfileAboutOfficialUpdateDecision.aboutAndOfficial,
  ];
}

bool _isVisible(ProfileAboutVisibility visibility, ProfileAboutAudience audience) =>
    switch (visibility) {
      ProfileAboutVisibility.profileAccess => true,
      ProfileAboutVisibility.linked =>
        audience == ProfileAboutAudience.linked || audience == ProfileAboutAudience.team,
      ProfileAboutVisibility.team => audience == ProfileAboutAudience.team,
      ProfileAboutVisibility.hidden => false,
    };
