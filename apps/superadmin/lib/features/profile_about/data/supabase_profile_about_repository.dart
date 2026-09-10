import 'package:coelo_domain/profile_about.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_about_repository.dart';

/// Supabase adapter for the contextual About page.
///
/// Writes go through `public.save_profile_about(p_subject_type, p_subject_id,
/// p_payload, p_expected_version, p_request_id, p_official_updates)`, the only
/// approved transaction of this domain. Idempotency belongs to the caller: the
/// `requestId` is forwarded untouched, because the RPC keeps the receipt in
/// `app_private.profile_about_command_receipts` and refuses the same
/// `request_id` with a different payload.
///
/// Reads prefer `public.get_profile_about(p_subject_type, p_subject_id)`, the
/// authorized read proposed in
/// `packages/coelo_database/plans/2026-09-09-profile-about-read-rpc.sql`, where
/// the actor, the subject scope and the published/visibility projection are all
/// resolved on the server.
///
/// That function is a candidate and has not been applied remotely, so when the
/// database answers that it does not exist — `42883`, or `PGRST202` from the
/// schema cache — `load` falls back to the direct table read that has always
/// been here: `public.profile_about_pages`,
/// `public.profile_about_structured_fields` and `public.profile_about_sections`
/// through PostgREST, leaning entirely on RLS, with no tenant filter invented on
/// the client beyond the requested subject. The fallback covers the absence of
/// the function and nothing else: a denial stays a denial and is never retried
/// as a table read, so a revoked grant cannot be laundered into a direct select.
/// Once the RPC is applied nominally the fallback stops being reached, and the
/// deny-by-default risk of those tables stops mattering to this screen.
///
/// Database tokens follow the snake_case of the domain enum names, the
/// convention the RPC's own defaults confirm (`profile_access`, `manual`,
/// `draft`).
final class SupabaseProfileAboutRepository implements ProfileAboutRepository {
  const SupabaseProfileAboutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async {
    try {
      final response = await _client.rpc<Object?>(
        'get_profile_about',
        params: <String, Object?>{
          'p_subject_type': profileAboutSubjectTypeToken(subject.type),
          'p_subject_id': subject.subjectId,
        },
      );
      final page = parseProfileAboutReadResponse(subject: subject, response: response);
      if (page == null) return null;
      return preview == null ? page : page.project(preview);
    } on PostgrestException catch (error) {
      // Only "the function is not there yet" falls back. Anything else — a
      // denial above all — keeps its meaning.
      if (!isMissingProfileAboutReadFunction(error.code, error.message)) {
        throw mapProfileAboutFailure(error.code, error.message);
      }
    } on FormatException {
      throw ProfileAboutUnavailableException();
    } on TypeError {
      throw ProfileAboutUnavailableException();
    }
    return _loadFromTables(subject, preview: preview);
  }

  /// The read that exists while `public.get_profile_about` is not applied.
  Future<ProfileAboutPage?> _loadFromTables(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async {
    try {
      final pageRows = _asRows(
        await _client
            .from('profile_about_pages')
            .select('id,version,state')
            .eq('subject_type', profileAboutSubjectTypeToken(subject.type))
            .eq(profileAboutSubjectColumn(subject.type), subject.subjectId)
            .limit(1),
      );
      if (pageRows.isEmpty) return null;
      final pageId = pageRows.first['id'];
      if (pageId is! String || pageId.isEmpty) {
        throw const FormatException('invalid_page_id');
      }
      final fieldRows = _asRows(
        await _client
            .from('profile_about_structured_fields')
            .select('field_key,value,latitude,longitude,visibility,origin,source_label')
            .eq('page_id', pageId),
      );
      final sectionRows = _asRows(
        await _client
            .from('profile_about_sections')
            .select('id,section_type,title,body,items,position,visibility,state,origin,revision')
            .eq('page_id', pageId)
            .order('position'),
      );
      final page = parseProfileAboutPage(
        subject: subject,
        pageRow: pageRows.first,
        fieldRows: fieldRows,
        sectionRows: sectionRows,
      );
      return preview == null ? page : page.project(preview);
    } on PostgrestException catch (error) {
      throw mapProfileAboutFailure(error.code, error.message);
    } on FormatException {
      throw ProfileAboutUnavailableException();
    } on TypeError {
      throw ProfileAboutUnavailableException();
    }
  }

  @override
  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  }) async {
    try {
      final response = await _client.rpc<Object?>(
        'save_profile_about',
        params: <String, Object?>{
          'p_subject_type': profileAboutSubjectTypeToken(page.subject.type),
          'p_subject_id': page.subject.subjectId,
          'p_payload': buildProfileAboutSavePayload(page),
          'p_expected_version': page.version,
          'p_request_id': requestId,
          'p_official_updates': buildProfileAboutOfficialUpdates(officialUpdates),
        },
      );
      return parseProfileAboutSaveResult(response);
    } on PostgrestException catch (error) {
      throw mapProfileAboutFailure(error.code, error.message);
    } on FormatException {
      throw ProfileAboutUnavailableException();
    } on TypeError {
      throw ProfileAboutUnavailableException();
    }
  }
}

List<Map<String, Object?>> _asRows(Object? value) {
  if (value is! List) throw const FormatException('invalid_rows');
  return value
      .map((row) {
        if (row is! Map) throw const FormatException('invalid_row');
        return Map<String, Object?>.from(row);
      })
      .toList(growable: false);
}

/// Converts the domain `camelCase` into the snake_case token Postgres stores.
String profileAboutToken(String enumName) {
  final buffer = StringBuffer();
  for (final unit in enumName.runes) {
    final character = String.fromCharCode(unit);
    final lower = character.toLowerCase();
    if (character != lower) buffer.write('_');
    buffer.write(lower);
  }
  return buffer.toString();
}

String profileAboutSubjectTypeToken(ProfileAboutSubjectType type) => profileAboutToken(type.name);

/// The `public.profile_about_pages` column that holds the subject id.
String profileAboutSubjectColumn(ProfileAboutSubjectType type) => switch (type) {
  ProfileAboutSubjectType.institution => 'institution_subject_id',
  ProfileAboutSubjectType.unit => 'unit_subject_id',
  ProfileAboutSubjectType.group => 'group_subject_id',
  ProfileAboutSubjectType.activity => 'activity_subject_id',
  ProfileAboutSubjectType.person => 'person_subject_id',
};

String profileAboutFieldKeyToken(ProfileAboutFieldKey key) => profileAboutToken(key.name);

ProfileAboutFieldKey? profileAboutFieldKeyFromToken(Object? token) =>
    _fromToken(ProfileAboutFieldKey.values, token);

String profileAboutVisibilityToken(ProfileAboutVisibility visibility) =>
    profileAboutToken(visibility.name);

ProfileAboutVisibility profileAboutVisibilityFromToken(Object? token) =>
    _fromToken(ProfileAboutVisibility.values, token) ?? ProfileAboutVisibility.profileAccess;

String profileAboutOriginToken(ProfileAboutOrigin origin) => profileAboutToken(origin.name);

ProfileAboutOrigin profileAboutOriginFromToken(Object? token) =>
    _fromToken(ProfileAboutOrigin.values, token) ?? ProfileAboutOrigin.manual;

String profileAboutSectionTypeToken(ProfileAboutSectionType type) => profileAboutToken(type.name);

ProfileAboutSectionType? profileAboutSectionTypeFromToken(Object? token) =>
    _fromToken(ProfileAboutSectionType.values, token);

String profileAboutSectionStateToken(ProfileAboutSectionState state) =>
    profileAboutToken(state.name);

ProfileAboutSectionState profileAboutSectionStateFromToken(Object? token) =>
    _fromToken(ProfileAboutSectionState.values, token) ?? ProfileAboutSectionState.draft;

T? _fromToken<T extends Enum>(List<T> values, Object? token) {
  if (token is! String) return null;
  for (final value in values) {
    if (profileAboutToken(value.name) == token) return value;
  }
  return null;
}

/// The `p_payload` argument of the `save_profile_about` RPC.
///
/// The page state (`draft`/`published`) is not sent: [ProfileAboutPage] does not
/// model page state and the RPC applies `coalesce(p_payload->>'state', state)`,
/// preserving the remote state. Publishing without an explicit intent would
/// demand `profiles.about.publish`. Per-section state is still sent.
Map<String, Object?> buildProfileAboutSavePayload(ProfileAboutPage page) => <String, Object?>{
  'fields': [
    for (final field in page.fields)
      <String, Object?>{
        'key': profileAboutFieldKeyToken(field.key),
        'value': field.value,
        'visibility': profileAboutVisibilityToken(field.visibility),
        'origin': profileAboutOriginToken(field.origin),
        if (field.sourceLabel != null) 'source_label': field.sourceLabel,
        if (field.latitude != null) 'latitude': field.latitude,
        if (field.longitude != null) 'longitude': field.longitude,
      },
  ],
  'sections': [
    for (final section in page.sections)
      <String, Object?>{
        'id': section.id,
        'type': profileAboutSectionTypeToken(section.type),
        'title': section.title,
        'body': section.body,
        'items': List<String>.from(section.items),
        'position': section.position,
        'visibility': profileAboutVisibilityToken(section.visibility),
        'state': profileAboutSectionStateToken(section.state),
        'origin': profileAboutOriginToken(section.origin),
      },
  ],
};

/// Payload `p_official_updates`: array de `{key, value}`.
List<Map<String, Object?>> buildProfileAboutOfficialUpdates(
  Map<ProfileAboutFieldKey, String> updates,
) => [
  for (final entry in updates.entries)
    <String, Object?>{'key': profileAboutFieldKeyToken(entry.key), 'value': entry.value},
];

/// Le o retorno jsonb da RPC:
/// `{page_id, version, about, official:[{key,status,message?}]}`.
ProfileAboutSaveResult parseProfileAboutSaveResult(Object? response) {
  if (response is! Map) throw const FormatException('invalid_save_result');
  final json = Map<String, Object?>.from(response);
  final pageId = json['page_id'];
  final version = json['version'];
  if (pageId is! String || pageId.isEmpty || version is! num) {
    throw const FormatException('invalid_save_result');
  }
  final rawOfficial = json['official'];
  final official = <ProfileAboutOfficialDestinationResult>[];
  if (rawOfficial is List) {
    for (final entry in rawOfficial) {
      if (entry is! Map) continue;
      final item = Map<String, Object?>.from(entry);
      final key = profileAboutFieldKeyFromToken(item['key']);
      final status = item['status'];
      if (key == null || status is! String) continue;
      final message = item['message'];
      official.add(
        ProfileAboutOfficialDestinationResult(
          key: key,
          status: status,
          message: message is String ? message : null,
        ),
      );
    }
  }
  return ProfileAboutSaveResult(
    pageId: pageId,
    version: version.toInt(),
    official: List.unmodifiable(official),
  );
}

/// True only when the database says `public.get_profile_about` does not exist.
///
/// `42883` is Postgres' `undefined_function`; `PGRST202` is PostgREST failing to
/// find it in the schema cache. Neither is a denial, and nothing else here is
/// treated as absence — mistaking a denial for absence would turn a revoked
/// grant into a direct table read.
bool isMissingProfileAboutReadFunction(String? code, String message) {
  if (code == '42883' || code == 'PGRST202') return true;
  if (code != null) return false;
  final text = message.toLowerCase();
  return text.contains('could not find the function') ||
      (text.contains('get_profile_about') && text.contains('does not exist'));
}

/// Reads the jsonb of `public.get_profile_about`:
/// `{page: null | {id, version, state}, fields: [...], sections: [...]}`.
///
/// The row keys are the same column names the table read already uses, so both
/// sources land on [parseProfileAboutPage] and there is a single grammar for the
/// About page. A null `page` means "no page for this subject", which the caller
/// already distinguishes from denial and from failure.
ProfileAboutPage? parseProfileAboutReadResponse({
  required ProfileAboutSubjectRef subject,
  required Object? response,
}) {
  if (response is! Map) throw const FormatException('invalid_read_response');
  final json = Map<String, Object?>.from(response);
  final page = json['page'];
  if (page == null) return null;
  if (page is! Map) throw const FormatException('invalid_read_response');
  return parseProfileAboutPage(
    subject: subject,
    pageRow: Map<String, Object?>.from(page),
    fieldRows: _asRows(json['fields'] ?? const <Object?>[]),
    sectionRows: _asRows(json['sections'] ?? const <Object?>[]),
  );
}

/// Builds the page from the rows read out of the tables.
///
/// Fields with an unknown key and sections with an unknown type are skipped, so
/// a new token in the database never brings the whole read down.
ProfileAboutPage parseProfileAboutPage({
  required ProfileAboutSubjectRef subject,
  required Map<String, Object?> pageRow,
  required List<Map<String, Object?>> fieldRows,
  required List<Map<String, Object?>> sectionRows,
}) {
  final version = pageRow['version'];
  if (version is! num) throw const FormatException('invalid_version');
  final fields = <ProfileAboutField>[];
  for (final row in fieldRows) {
    final key = profileAboutFieldKeyFromToken(row['field_key']);
    final value = row['value'];
    if (key == null || value is! String) continue;
    final sourceLabel = row['source_label'];
    fields.add(
      ProfileAboutField(
        key: key,
        value: value,
        visibility: profileAboutVisibilityFromToken(row['visibility']),
        origin: profileAboutOriginFromToken(row['origin']),
        sourceLabel: sourceLabel is String ? sourceLabel : null,
        latitude: _asDouble(row['latitude']),
        longitude: _asDouble(row['longitude']),
      ),
    );
  }
  final sections = <ProfileAboutSection>[];
  for (final row in sectionRows) {
    final type = profileAboutSectionTypeFromToken(row['section_type']);
    final id = row['id'];
    if (type == null || id is! String || id.isEmpty) continue;
    final title = row['title'];
    final body = row['body'];
    final items = row['items'];
    sections.add(
      ProfileAboutSection(
        id: id,
        type: type,
        title: title is String ? title : '',
        body: body is String ? body : '',
        position: _asInt(row['position']) ?? sections.length,
        items: [
          if (items is List)
            for (final item in items)
              if (item is String) item,
        ],
        visibility: profileAboutVisibilityFromToken(row['visibility']),
        state: profileAboutSectionStateFromToken(row['state']),
        origin: profileAboutOriginFromToken(row['origin']),
        revision: _asInt(row['revision']) ?? 1,
      ),
    );
  }
  sections.sort((a, b) => a.position.compareTo(b.position));
  return ProfileAboutPage(
    subject: subject,
    version: version.toInt(),
    fields: fields,
    sections: sections,
  );
}

double? _asDouble(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text),
  _ => null,
};

int? _asInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text),
  _ => null,
};

/// Maps PostgREST and Postgres failures onto the domain contract exceptions.
Exception mapProfileAboutFailure(String? code, String message) {
  final text = message.toLowerCase();
  return switch (code) {
    '42501' || 'PGRST301' || '401' || '403' => ProfileAboutUnauthorizedException(),
    '40001' || '23505' => ProfileAboutConflictException(),
    'P0001' when text.contains('version') => ProfileAboutConflictException(),
    _ =>
      text.contains('insufficient_privilege') || text.contains('required')
          ? ProfileAboutUnauthorizedException()
          : ProfileAboutUnavailableException(),
  };
}
