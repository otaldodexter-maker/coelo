import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../data/entity_image_repository.dart';

/// Foto real de uma entidade (perfil, capa ou ícone) em diretórios, cards e
/// cabeçalhos. Sem [EntityImageScope] (mock/testes) ou enquanto a foto não
/// chega, mostra [fallback] — as iniciais/ícone que a tela já tinha.
///
/// A leitura vai pelo cache do escopo: um lote por tipo de entidade e frame,
/// bytes pela Edge, sem URL assinada no navegador.
final class EntityImageView extends StatelessWidget {
  const EntityImageView({
    required this.entity,
    required this.entityId,
    required this.fallback,
    this.kind = EntityImageKind.profile,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.principal = false,
    super.key,
  });

  final EntityKind entity;
  final String entityId;
  final EntityImageKind kind;
  final Widget fallback;
  final BoxShape shape;

  /// Lê pelo leitor do Principal (responsável ou equipe, regra no servidor).
  final bool principal;

  /// Só com [shape] retangular.
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cache = EntityImageScope.cacheOf(context, principal: principal);
    if (cache == null || entityId.isEmpty) return fallback;
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: cache.watch(entity, entityId, kind: kind),
      builder: (context, bytes, _) {
        if (bytes == null) return fallback;
        final image = Image.memory(bytes, fit: fit, gaplessPlayback: true, semanticLabel: semanticLabel);
        return shape == BoxShape.circle
            ? ClipOval(child: SizedBox.expand(child: image))
            : ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: SizedBox.expand(child: image));
      },
    );
  }
}

/// Cabeçalho de página de detalhe: capa (quando houver), foto de perfil e nome.
/// Sem foto fica o ícone/iniciais e o nome; sem escopo de imagens (mock/testes)
/// o cabeçalho não existe, porque a página já lista o nome nos campos.
final class EntityIdentityHeader extends StatelessWidget {
  const EntityIdentityHeader({
    required this.entity,
    required this.entityId,
    required this.name,
    required this.fallbackIcon,
    this.subtitle,
    this.initials,
    this.showCover = true,
    super.key,
  });

  final EntityKind entity;
  final String entityId;
  final String name;
  final String? subtitle;
  final String? initials;
  final IconData fallbackIcon;
  final bool showCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cache = EntityImageScope.cacheOf(context);
    if (cache == null) return const SizedBox.shrink();
    final fallback = Container(
      decoration: BoxDecoration(color: colors.secondaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: initials == null || initials!.isEmpty
          ? Icon(fallbackIcon, color: colors.onSecondaryContainer, size: CoeloSize.iconLg)
          : Text(initials!, style: theme.textTheme.titleMedium?.copyWith(color: colors.onSecondaryContainer)),
    );
    return Card(
      key: Key('entity-identity-header-$entityId'),
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A faixa da capa só existe quando há capa gravada.
          if (showCover)
            ValueListenableBuilder<Uint8List?>(
              valueListenable: cache.watch(entity, entityId, kind: EntityImageKind.cover),
              builder: (context, bytes, _) => bytes == null
                  ? const SizedBox.shrink()
                  : SizedBox(
                      height: CoeloSize.touchMin * 2.5,
                      width: double.infinity,
                      child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, semanticLabel: 'Capa de $name'),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: CoeloSize.touchMin * 1.5,
                  child: EntityImageView(
                    entity: entity,
                    entityId: entityId,
                    semanticLabel: 'Foto de $name',
                    fallback: fallback,
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(name, style: theme.textTheme.titleLarge)),
                      if (subtitle case final subtitle? when subtitle.isNotEmpty)
                        Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
