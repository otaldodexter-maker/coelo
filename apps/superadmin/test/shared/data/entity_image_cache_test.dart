import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/shared/data/entity_image_cache.dart';
import 'package:coelo_superadmin/shared/data/entity_image_repository.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/entity_image_view.dart';

final class _FakeRepository implements EntityImageRepository {
  final List<String> listCalls = [];
  final List<String> readCalls = [];
  final Map<String, Uint8List> assets = {};
  final Map<String, Map<EntityImageKind, EntityImageRef>> refs = {};

  @override
  Future<Map<String, Map<EntityImageKind, EntityImageRef>>> list(EntityKind entity, List<String> entityIds) async {
    listCalls.add('${entity.name}:${entityIds.join(',')}');
    return {for (final id in entityIds) id: ?refs[id]};
  }

  @override
  Future<Uint8List> read(String assetId) async {
    readCalls.add(assetId);
    final bytes = assets[assetId];
    if (bytes == null) throw const EntityImageRepositoryException('Leitura de foto não autorizada.');
    return bytes;
  }

  @override
  Future<Map<EntityImageKind, EntityImage>> load(EntityKind entity, String entityId) => throw UnimplementedError();

  @override
  Future<void> remove(String assetId) => throw UnimplementedError();

  @override
  Future<EntityImage> upload(EntityKind entity, String entityId,
          {required EntityImageKind kind, required Uint8List bytes, String contentType = 'image/png', Map<String, Object?>? iconSpec}) =>
      throw UnimplementedError();
}

// PNG 1×1 válido para Image.memory.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0x00, //
  0x00, 0x00, 0x04, 0x00, 0x01, 0x5C, 0xCD, 0xFF, 0x69, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  test('pedidos do mesmo frame viram um lote por tipo de entidade; bytes lidos uma vez por asset', () async {
    final repository = _FakeRepository()
      ..refs['u1'] = {EntityImageKind.profile: const EntityImageRef(assetId: 'a1', kind: EntityImageKind.profile, contentType: 'image/png')}
      ..refs['u2'] = {EntityImageKind.profile: const EntityImageRef(assetId: 'a1', kind: EntityImageKind.profile, contentType: 'image/png')}
      ..assets['a1'] = _png;
    final cache = EntityImageCache(repository);
    final first = cache.watch(EntityKind.unit, 'u1');
    final second = cache.watch(EntityKind.unit, 'u2');
    final third = cache.watch(EntityKind.unit, 'u3');
    final other = cache.watch(EntityKind.group, 'g1');
    expect(first.value, isNull);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(repository.listCalls, ['unit:u1,u2,u3', 'group:g1']);
    expect(repository.readCalls, ['a1'], reason: 'mesmo asset em duas entidades lê uma vez');
    expect(first.value, same(_png));
    expect(second.value, same(_png));
    expect(third.value, isNull, reason: 'entidade sem foto fica no fallback');
    expect(other.value, isNull);
    expect(identical(cache.watch(EntityKind.unit, 'u1'), first), isTrue);
    expect(repository.listCalls, hasLength(2), reason: 'watch repetido não pede de novo');
  });

  test('invalidate esquece a entidade e pede de novo; put publica sem nova leitura', () async {
    final repository = _FakeRepository();
    final cache = EntityImageCache(repository);
    final listenable = cache.watch(EntityKind.person, 'p1');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(listenable.value, isNull);
    cache.put(EntityKind.person, 'p1', EntityImage(assetId: 'a9', kind: EntityImageKind.profile, contentType: 'image/png', bytes: _png));
    expect(listenable.value, same(_png));
    expect(repository.readCalls, isEmpty);
    cache.invalidate(EntityKind.person, 'p1');
    expect(listenable.value, isNull);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(repository.listCalls, hasLength(2));
  });

  testWidgets('EntityImageView mostra o fallback sem escopo e a foto quando ela chega', (tester) async {
    final repository = _FakeRepository()
      ..refs['i1'] = {EntityImageKind.profile: const EntityImageRef(assetId: 'a1', kind: EntityImageKind.profile, contentType: 'image/png')}
      ..assets['a1'] = _png;
    Widget view() => const EntityImageView(
          entity: EntityKind.institution,
          entityId: 'i1',
          semanticLabel: 'Foto da instituição',
          fallback: Text('AB'),
        );
    await tester.pumpWidget(MaterialApp(home: SizedBox.square(dimension: 44, child: view())));
    expect(find.text('AB'), findsOneWidget, reason: 'sem EntityImageScope fica o fallback');

    await tester.pumpWidget(
      MaterialApp(
        home: EntityImageScope(cache: EntityImageCache(repository), child: SizedBox.square(dimension: 44, child: view())),
      ),
    );
    expect(find.text('AB'), findsOneWidget, reason: 'antes da resposta ainda é o fallback');
    await tester.pump();
    await tester.pump();
    expect(find.text('AB'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(repository.listCalls, ['institution:i1']);
  });
}
