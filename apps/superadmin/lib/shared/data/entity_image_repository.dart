import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entidades que têm foto de perfil/capa (e ícone, no caso da atividade).
enum EntityKind { institution, unit, group, activity, person }

enum EntityImageKind { profile, cover, icon }

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
  const EntityImageScope({super.key, required this.repository, required super.child});

  final EntityImageRepository repository;

  static EntityImageRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EntityImageScope>()?.repository;

  @override
  bool updateShouldNotify(EntityImageScope oldWidget) => repository != oldWidget.repository;
}

final class EntityImageRepositoryException implements Exception {
  const EntityImageRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class SupabaseEntityImageRepository implements EntityImageRepository {
  const SupabaseEntityImageRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<EntityImageKind, EntityImage>> load(EntityKind entity, String entityId) async {
    final data = await _client.rpc<dynamic>(
      'superadmin_entity_images_get_v1',
      params: {'p_entity_kind': entity.name, 'p_entity_id': entityId},
    );
    if (data is! Map) return const {};
    final result = <EntityImageKind, EntityImage>{};
    for (final kind in EntityImageKind.values) {
      final entry = data[kind.name];
      if (entry is! Map || entry['asset_id'] is! String) continue;
      final assetId = entry['asset_id'] as String;
      final bytes = await _bytes({'action': 'read', 'asset_id': assetId});
      result[kind] = EntityImage(
        assetId: assetId,
        kind: kind,
        contentType: entry['content_type'] is String ? entry['content_type'] as String : 'image/png',
        bytes: bytes,
        iconSpec: entry['icon_spec'] is Map ? Map<String, Object?>.from(entry['icon_spec'] as Map) : null,
      );
    }
    return result;
  }

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
      'entity_kind': entity.name,
      'entity_id': entityId,
      'image_kind': kind.name,
      'file_name': '${kind.name}.${contentType == 'image/jpeg' ? 'jpg' : contentType.split('/').last}',
      'content_type': contentType,
      'byte_size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'icon_spec': ?iconSpec,
    });
    final assetId = prepared['asset_id'];
    if (assetId is! String) throw const EntityImageRepositoryException('Não foi possível preparar a foto.');
    final finalized = await _json(
      bytes,
      headers: {'x-coelo-asset-id': assetId},
      failure: 'Não foi possível enviar a foto.',
    );
    if (finalized['status'] != 'active') {
      throw const EntityImageRepositoryException('Não foi possível confirmar a foto.');
    }
    return EntityImage(assetId: assetId, kind: kind, contentType: contentType, bytes: bytes, iconSpec: iconSpec);
  }

  @override
  Future<void> remove(String assetId) async {
    await _json({'action': 'remove', 'asset_id': assetId}, failure: 'Não foi possível remover a foto.');
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

  Future<Object?> _invoke(Object body, {Map<String, String>? headers, required String failure}) async {
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

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
