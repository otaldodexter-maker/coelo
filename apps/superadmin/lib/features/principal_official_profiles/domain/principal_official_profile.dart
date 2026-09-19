import '../../notices/domain/platform_notice.dart';

/// Perfil oficial do Coelo visto pelo Principal (spec 068, lote 104).
final class PrincipalOfficialProfile {
  const PrincipalOfficialProfile({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.personId,
    this.description = '',
    this.mandatory = false,
    this.followers = 0,
    this.following = false,
  });

  static PrincipalOfficialProfile? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString();
    final personId = value['person_id']?.toString();
    if (id == null || id.isEmpty || personId == null || personId.isEmpty) return null;
    return PrincipalOfficialProfile(
      id: id,
      handle: value['handle']?.toString() ?? '',
      displayName: value['display_name']?.toString() ?? 'Coelo',
      personId: personId,
      description: value['description']?.toString() ?? '',
      mandatory: value['mandatory'] == true,
      followers: (value['followers'] as num?)?.toInt() ?? 0,
      following: value['following'] == true,
    );
  }

  final String id;
  final String handle;
  final String displayName;
  final String personId;
  final String description;

  /// `coelo`: todo mundo segue e ninguém deixa de seguir.
  final bool mandatory;
  final int followers;
  final bool following;

  String get initials {
    final words = displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'C';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1)).toUpperCase();
  }

  PrincipalOfficialProfile copyWith({bool? following, int? followers}) => PrincipalOfficialProfile(
    id: id,
    handle: handle,
    displayName: displayName,
    personId: personId,
    description: description,
    mandatory: mandatory,
    followers: followers ?? this.followers,
    following: following ?? this.following,
  );
}

/// Post de texto do perfil no Acontece (spec 068 §4, lote 107).
final class PrincipalOfficialPost {
  const PrincipalOfficialPost({required this.id, required this.caption, required this.publishedAt});

  static PrincipalOfficialPost? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString();
    final publishedAt = DateTime.tryParse(value['published_at']?.toString() ?? '');
    if (id == null || id.isEmpty || publishedAt == null) return null;
    return PrincipalOfficialPost(
      id: id,
      caption: value['caption']?.toString() ?? '',
      publishedAt: publishedAt.toUtc(),
    );
  }

  final String id;
  final String caption;
  final DateTime publishedAt;
}

/// Perfil aberto + catálogo ativo + publicações que o ator pode ver.
final class PrincipalOfficialProfileDetail {
  const PrincipalOfficialProfileDetail({
    required this.profile,
    required this.profiles,
    required this.items,
    this.posts = const [],
  });

  final PrincipalOfficialProfile profile;
  final List<PrincipalOfficialProfile> profiles;

  /// Publicações do Para você assinadas pelo perfil.
  final List<PlatformNotice> items;

  /// Posts do perfil no Acontece.
  final List<PrincipalOfficialPost> posts;
}

/// Leitor do Principal para perfis oficiais. Erros são os do repositório de
/// avisos (`NoticeRepositoryException`): não encontrado, sem acesso, indisponível.
abstract interface class PrincipalOfficialProfilesReader {
  Future<List<PrincipalOfficialProfile>> loadOfficialProfiles();

  Future<PrincipalOfficialProfileDetail> loadOfficialProfile(String handle);

  /// Segue/deixa de seguir a pessoa técnica do perfil; devolve `following`
  /// real. O servidor recusa deixar de seguir o obrigatório.
  Future<bool> setOfficialFollowing(String personId, {required bool follow});
}
