import 'dart:async';

import 'package:flutter/foundation.dart';

import 'entity_image_repository.dart';

/// Cache das fotos das entidades para diretórios, cards e cabeçalhos.
///
/// Quem pede a foto de uma entidade recebe um [ValueListenable] que começa
/// vazio e recebe os bytes quando chegarem. Pedidos feitos no mesmo frame
/// viram uma única chamada em lote (`*_entity_images_list_v1`) por tipo de
/// entidade; os bytes vêm pela Edge e ficam em memória por asset.
final class EntityImageCache {
  EntityImageCache(this.repository, {int batchLimit = 200}) : _batchLimit = batchLimit;

  final EntityImageRepository repository;
  final int _batchLimit;

  final Map<String, Map<EntityImageKind, EntityImageRef>> _refs = {};
  final Map<String, Future<Uint8List?>> _bytes = {};
  final Map<String, ValueNotifier<Uint8List?>> _listeners = {};
  final Map<EntityKind, Set<String>> _pending = {};
  final Map<EntityKind, Set<String>> _inFlight = {};
  bool _flushScheduled = false;

  static String _refKey(EntityKind entity, String entityId) => '${entity.name}:$entityId';

  static String _listenerKey(EntityKind entity, String entityId, EntityImageKind kind) =>
      '${entity.name}:$entityId:${kind.wire}';

  /// Bytes da imagem [kind] da entidade; `null` enquanto não chegou ou quando
  /// a entidade não tem imagem. Chamadas repetidas devolvem o mesmo listenable.
  ValueListenable<Uint8List?> watch(
    EntityKind entity,
    String entityId, {
    EntityImageKind kind = EntityImageKind.profile,
  }) {
    final notifier = _listeners.putIfAbsent(
      _listenerKey(entity, entityId, kind),
      () => ValueNotifier<Uint8List?>(null),
    );
    final refs = _refs[_refKey(entity, entityId)];
    if (refs == null) {
      _enqueue(entity, entityId);
    } else if (notifier.value == null) {
      _resolve(notifier, refs[kind]);
    }
    return notifier;
  }

  /// Referência já conhecida (sem pedir nada); útil para o `icon_spec`.
  EntityImageRef? refOf(EntityKind entity, String entityId, EntityImageKind kind) =>
      _refs[_refKey(entity, entityId)]?[kind];

  /// Depois de trocar/remover uma imagem pelo formulário: esquece a entidade e
  /// pede de novo para quem estiver ouvindo.
  void invalidate(EntityKind entity, String entityId) {
    _refs.remove(_refKey(entity, entityId));
    for (final kind in EntityImageKind.values) {
      final notifier = _listeners[_listenerKey(entity, entityId, kind)];
      if (notifier != null) {
        notifier.value = null;
        _enqueue(entity, entityId);
      }
    }
  }

  /// Atalho para o formulário: publica os bytes recém-gravados sem nova leitura.
  void put(EntityKind entity, String entityId, EntityImage image) {
    final refs = _refs.putIfAbsent(_refKey(entity, entityId), () => {});
    refs[image.kind] = EntityImageRef(
      assetId: image.assetId,
      kind: image.kind,
      contentType: image.contentType,
      iconSpec: image.iconSpec,
    );
    _bytes[image.assetId] = Future.value(image.bytes);
    _listeners[_listenerKey(entity, entityId, image.kind)]?.value = image.bytes;
  }

  void _enqueue(EntityKind entity, String entityId) {
    if (_inFlight[entity]?.contains(entityId) ?? false) return;
    _pending.putIfAbsent(entity, () => {}).add(entityId);
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(_flush);
  }

  Future<void> _flush() async {
    _flushScheduled = false;
    final batches = Map.of(_pending);
    _pending.clear();
    for (final entry in batches.entries) {
      final ids = entry.value.toList();
      for (var start = 0; start < ids.length; start += _batchLimit) {
        final slice = ids.sublist(
          start,
          start + _batchLimit > ids.length ? ids.length : start + _batchLimit,
        );
        _inFlight.putIfAbsent(entry.key, () => {}).addAll(slice);
        unawaited(_load(entry.key, slice));
      }
    }
  }

  Future<void> _load(EntityKind entity, List<String> ids) async {
    Map<String, Map<EntityImageKind, EntityImageRef>> listed;
    try {
      listed = await repository.list(entity, ids);
    } on Exception {
      listed = const {};
    } finally {
      _inFlight[entity]?.removeAll(ids);
    }
    for (final id in ids) {
      final refs = Map<EntityImageKind, EntityImageRef>.of(listed[id] ?? const {});
      _refs[_refKey(entity, id)] = refs;
      for (final kind in EntityImageKind.values) {
        final notifier = _listeners[_listenerKey(entity, id, kind)];
        if (notifier != null) _resolve(notifier, refs[kind]);
      }
    }
  }

  void _resolve(ValueNotifier<Uint8List?> notifier, EntityImageRef? ref) {
    if (ref == null) {
      notifier.value = null;
      return;
    }
    final future = _bytes.putIfAbsent(
      ref.assetId,
      () => repository.read(ref.assetId).then<Uint8List?>((bytes) => bytes).catchError((_) {
        _bytes.remove(ref.assetId);
        return null;
      }),
    );
    unawaited(
      future.then((bytes) {
        if (bytes != null) notifier.value = bytes;
      }),
    );
  }
}
