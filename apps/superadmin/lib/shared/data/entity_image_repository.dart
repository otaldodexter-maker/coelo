import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entity_image_cache.dart';

/// Entidades que têm foto de perfil/capa (e ícone, no caso da atividade).
/// `internalUser` só existe para leitura em lote: a chave é o id da identidade
/// interna e a foto é a da pessoa de serviço (o formulário grava em `person`).
enum EntityKind {
  institution('institution'),
  unit('unit'),
  group('group'),
  activity('activity'),
  person('person'),
  internalUser('internal_user');

  const EntityKind(this.wire);

  /// Nome no contrato do servidor (`entity_kind`).
  final String wire;
}

/// `icon` é o PNG rasterizado do ícone da atividade; `iconVector` é o mesmo
/// desenho em SVG (fundo + path), gravado junto para as superfícies vetoriais.
/// `floorPlan` é a planta baixa (spec 067) de instituição/unidade, só raster.
enum EntityImageKind {
  profile('profile'),
  cover('cover'),
  icon('icon'),
  iconVector('icon_vector'),
  floorPlan('floor_plan');

  const EntityImageKind(this.wire);

  /// Nome no contrato do servidor (`image_kind`).
  final String wire;

  static EntityImageKind? fromWire(String value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// Referência a uma imagem ativa (sem bytes): o que a RPC em lote devolve.
final class EntityImageRef {
  const EntityImageRef({
    required this.assetId,
    required this.kind,
    required this.contentType,
    this.iconSpec,
  });

  final String assetId;
  final EntityImageKind kind;
  final String contentType;
  final Map<String, Object?>? iconSpec;

  static EntityImageRef? fromJson(EntityImageKind kind, Object? entry) {
    if (entry is! Map || entry['asset_id'] is! String) return null;
    return EntityImageRef(
      assetId: entry['asset_id'] as String,
      kind: kind,
      contentType: entry['content_type'] is String ? entry['content_type'] as String : 'image/png',
      iconSpec: entry['icon_spec'] is Map
          ? Map<String, Object?>.from(entry['icon_spec'] as Map)
          : null,
    );
  }
}

final class EntityImage {
  const EntityImage({
    required this.assetId,
    required this.kind,
    required this.contentType,
    required this.bytes,
    this.iconSpec,
  });

  final String assetId;
  final EntityImageKind kind;
  final String contentType;
  final Uint8List bytes;

  /// Para o ícone de atividade: `{icon, color, background}` — permite reeditar.
  final Map<String, Object?>? iconSpec;
}

/// Fotos das entidades em R2 privado. Os bytes passam pela Edge `entity-media`
/// (prepare → upload binário → leitura inline); o navegador nunca fala com o R2.
abstract interface class EntityImageRepository {
  Future<Map<EntityImageKind, EntityImage>> load(EntityKind entity, String entityId);

  /// Referências ativas de várias entidades de uma vez (diretórios, cards,
  /// cabeçalhos). Só volta o que o ator pode ler; até 200 ids por chamada.
  Future<Map<String, Map<EntityImageKind, EntityImageRef>>> list(
    EntityKind entity,
    List<String> entityIds,
  );

  /// Bytes de uma imagem ativa, pela Edge (o navegador nunca fala com o R2).
  Future<Uint8List> read(String assetId);

  Future<EntityImage> upload(
    EntityKind entity,
    String entityId, {
    required EntityImageKind kind,
    required Uint8List bytes,
    String contentType = 'image/png',
    Map<String, Object?>? iconSpec,
  });

  Future<void> remove(String assetId);
}

/// Repositório visível pelos formulários (produção). Sem escopo (mock/testes)
/// a seção de fotos não aparece.
final class EntityImageScope extends InheritedWidget {
  const EntityImageScope({
    super.key,
    required this.cache,
    this.principalCache,
    required super.child,
  });

  /// Cache das fotos (diretórios/cabeçalhos); o repositório vive dentro dele.
  final EntityImageCache cache;

  /// Leitor do Principal (RPCs `principal_*`: equipe do tenant ou responsável
  /// por `guardian_links` + `can_view`); só leitura.
  final EntityImageCache? principalCache;

  EntityImageRepository get repository => cache.repository;

  static EntityImageRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EntityImageScope>()?.repository;

  static EntityImageCache? cacheOf(BuildContext context, {bool principal = false}) {
    final scope = context.dependOnInheritedWidgetOfExactType<EntityImageScope>();
    return principal ? scope?.principalCache : scope?.cache;
  }

  @override
  bool updateShouldNotify(EntityImageScope oldWidget) =>
      cache != oldWidget.cache || principalCache != oldWidget.principalCache;
}

final class EntityImageRepositoryException implements Exception {
  const EntityImageRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// [principal] lê pelas RPCs do Principal (equipe do tenant ou responsável por
/// `guardian_links` + `can_view`, regra no servidor); sem escrita.
final class SupabaseEntityImageRepository implements EntityImageRepository {
  const SupabaseEntityImageRepository(this._client, {bool principal = false})
    : _principal = principal;

  final SupabaseClient _client;
  final bool _principal;

  @override
  Future<Map<EntityImageKind, EntityImage>> load(EntityKind entity, String entityId) async {
    final refs = (await list(entity, [entityId]))[entityId] ?? const {};
    final result = <EntityImageKind, EntityImage>{};
    for (final ref in refs.values) {
      final bytes = await read(ref.assetId);
      result[ref.kind] = EntityImage(
        assetId: ref.assetId,
        kind: ref.kind,
        contentType: ref.contentType,
        bytes: bytes,
        iconSpec: ref.iconSpec,
      );
    }
    return result;
  }

  @override
  Future<Map<String, Map<EntityImageKind, EntityImageRef>>> list(
    EntityKind entity,
    List<String> entityIds,
  ) async {
    if (entityIds.isEmpty) return const {};
    final data = await _client.rpc<dynamic>(
      _principal ? 'principal_entity_images_list_v1' : 'superadmin_entity_images_list_v1',
      params: {'p_entity_kind': entity.wire, 'p_entity_ids': entityIds},
    );
    if (data is! Map) return const {};
    final result = <String, Map<EntityImageKind, EntityImageRef>>{};
    for (final entry in data.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final images = <EntityImageKind, EntityImageRef>{};
      for (final image in (entry.value as Map).entries) {
        final kind = image.key is String ? EntityImageKind.fromWire(image.key as String) : null;
        final ref = kind == null ? null : EntityImageRef.fromJson(kind, image.value);
        if (ref != null) images[kind!] = ref;
      }
      result[entry.key as String] = images;
    }
    return result;
  }

  @override
  Future<Uint8List> read(String assetId) =>
      _bytes({'action': 'read', 'asset_id': assetId, if (_principal) 'reader': 'principal'});

  @override
  Future<EntityImage> upload(
    EntityKind entity,
    String entityId, {
    required EntityImageKind kind,
    required Uint8List bytes,
    String contentType = 'image/png',
    Map<String, Object?>? iconSpec,
  }) async {
    final prepared = await _json({
      'action': 'prepare',
      'request_id': _uuidV4(),
      'entity_kind': entity.wire,
      'entity_id': entityId,
      'image_kind': kind.wire,
      'file_name': '${kind.wire}.${_extension(contentType)}',
      'content_type': contentType,
      'byte_size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'icon_spec': ?iconSpec,
    });
    final assetId = prepared['asset_id'];
    if (assetId is! String) {
      throw const EntityImageRepositoryException('Não foi possível preparar a foto.');
    }
    final finalized = await _json(
      bytes,
      headers: {'x-coelo-asset-id': assetId},
      failure: 'Não foi possível enviar a foto.',
    );
    if (finalized['status'] != 'active') {
      throw const EntityImageRepositoryException('Não foi possível confirmar a foto.');
    }
    return EntityImage(
      assetId: assetId,
      kind: kind,
      contentType: contentType,
      bytes: bytes,
      iconSpec: iconSpec,
    );
  }

  @override
  Future<void> remove(String assetId) async {
    await _json({
      'action': 'remove',
      'asset_id': assetId,
    }, failure: 'Não foi possível remover a foto.');
  }

  Future<Map<String, dynamic>> _json(
    Object body, {
    Map<String, String>? headers,
    String failure = 'Operação de foto não autorizada.',
  }) async {
    final data = await _invoke(body, headers: headers, failure: failure);
    if (data is! Map) throw EntityImageRepositoryException(failure);
    return Map<String, dynamic>.from(data);
  }

  Future<Uint8List> _bytes(Map<String, dynamic> body) async {
    final data = await _invoke(body, failure: 'Leitura de foto não autorizada.');
    if (data is! Uint8List || data.isEmpty) {
      throw const EntityImageRepositoryException('Leitura de foto não autorizada.');
    }
    return data;
  }

  Future<Object?> _invoke(
    Object body, {
    Map<String, String>? headers,
    required String failure,
  }) async {
    try {
      final response = await _client.functions.invoke('entity-media', body: body, headers: headers);
      if (response.status != 200) throw EntityImageRepositoryException(failure);
      return response.data;
    } on FunctionException catch (error) {
      throw EntityImageRepositoryException(
        error.details is Map ? '${(error.details as Map)['error'] ?? failure}' : failure,
      );
    }
  }
}

String _extension(String contentType) => switch (contentType) {
  'image/jpeg' => 'jpg',
  'image/svg+xml' => 'svg',
  _ => contentType.split('/').last,
};

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
