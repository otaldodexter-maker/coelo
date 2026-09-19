import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/entity_image_cache.dart';
import '../../data/entity_image_repository.dart';
import 'activity_icon_designer_dialog.dart';
import 'avatar_crop_dialog.dart';
import 'cover_crop_dialog.dart';

/// Fotos de uma entidade (perfil, capa e, na atividade, ícone). Com id a troca
/// grava na hora; sem id (formulário de criação) fica pendente e o formulário
/// chama [attach] com o id novo depois de salvar.
final class EntityImagesController extends ChangeNotifier {
  EntityImagesController({
    required this.kind,
    required this.repository,
    String? entityId,
    EntityImageCache? cache,
  }) : _entityId = entityId,
       _cache = cache;

  final EntityKind kind;
  final EntityImageRepository repository;

  /// Cache dos diretórios/cabeçalhos: recebe o que o formulário gravou.
  final EntityImageCache? _cache;
  String? _entityId;
  final Map<EntityImageKind, EntityImage> _images = {};
  final Map<EntityImageKind, ({Uint8List bytes, Map<String, Object?>? iconSpec})> _pending = {};
  final Set<EntityImageKind> _busy = {};
  String? error;
  bool _loaded = false;
  bool _disposed = false;

  String? get entityId => _entityId;
  bool get loaded => _loaded;
  bool isBusy(EntityImageKind kind) => _busy.contains(kind);
  bool get hasPending => _pending.isNotEmpty;

  /// Bytes a mostrar (pendente tem precedência sobre o gravado).
  Uint8List? bytesOf(EntityImageKind kind) => _pending[kind]?.bytes ?? _images[kind]?.bytes;
  Map<String, Object?>? iconSpecOf(EntityImageKind kind) =>
      _pending[kind]?.iconSpec ?? _images[kind]?.iconSpec;
  bool has(EntityImageKind kind) => bytesOf(kind) != null;

  Future<void> load() async {
    final id = _entityId;
    if (id == null) {
      _loaded = true;
      return;
    }
    try {
      final images = await repository.load(kind, id);
      if (_disposed) return;
      _images
        ..clear()
        ..addAll(images);
      error = null;
    } on Exception catch (failure) {
      error = failure.toString();
    }
    _loaded = true;
    _notify();
  }

  Future<void> setImage(
    EntityImageKind kind,
    Uint8List bytes, {
    Map<String, Object?>? iconSpec,
  }) async {
    final id = _entityId;
    if (id == null) {
      _pending[kind] = (bytes: bytes, iconSpec: iconSpec);
      _notify();
      return;
    }
    await _run(kind, () async {
      final entity = kind == EntityImageKind.icon || kind == EntityImageKind.iconVector
          ? EntityKind.activity
          : this.kind;
      final image = await repository.upload(
        entity,
        id,
        kind: kind,
        bytes: bytes,
        iconSpec: iconSpec,
        contentType: kind == EntityImageKind.iconVector ? 'image/svg+xml' : 'image/png',
      );
      _images[kind] = image;
      _pending.remove(kind);
      _cache?.put(entity, id, image);
    });
  }

  Future<void> removeImage(EntityImageKind kind) async {
    if (_pending.remove(kind) != null && _images[kind] == null) {
      _notify();
      return;
    }
    final image = _images[kind];
    final id = _entityId;
    if (image == null || id == null) return;
    await _run(kind, () async {
      await repository.remove(image.assetId);
      _images.remove(kind);
      _cache?.invalidate(this.kind, id);
    });
  }

  /// Formulário de criação: grava o que ficou pendente na entidade recém-criada.
  Future<void> attach(String entityId) async {
    _entityId = entityId;
    for (final entry in _pending.entries.toList()) {
      await setImage(entry.key, entry.value.bytes, iconSpec: entry.value.iconSpec);
    }
  }

  Future<void> _run(EntityImageKind kind, Future<void> Function() action) async {
    _busy.add(kind);
    error = null;
    _notify();
    try {
      await action();
    } on Exception catch (failure) {
      error = failure.toString();
    } finally {
      _busy.remove(kind);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class EntityImagesSection extends StatefulWidget {
  const EntityImagesSection({
    required this.kind,
    this.entityId,
    this.controller,
    this.showProfile = true,
    this.showCover = true,
    this.showIcon = false,
    this.profileTitle = 'Foto de perfil',
    this.coverTitle = 'Foto de capa',
    this.onChanged,
    super.key,
  });

  final EntityKind kind;
  final String? entityId;

  /// Quando o formulário precisa de [EntityImagesController.attach] após criar.
  final EntityImagesController? controller;
  final bool showProfile;
  final bool showCover;
  final bool showIcon;
  final String profileTitle;
  final String coverTitle;
  final VoidCallback? onChanged;

  @override
  State<EntityImagesSection> createState() => _EntityImagesSectionState();
}

final class _EntityImagesSectionState extends State<EntityImagesSection> {
  EntityImagesController? _own;
  EntityImagesController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = widget.controller ?? _own ?? _create();
    if (!identical(next, _controller)) {
      _controller?.removeListener(_onChanged);
      _controller = next?..addListener(_onChanged);
      if (next != null && !next.loaded) next.load();
    }
  }

  EntityImagesController? _create() {
    final repository = EntityImageScope.maybeOf(context);
    if (repository == null) return null;
    return _own = EntityImagesController(
      kind: widget.kind,
      repository: repository,
      entityId: widget.entityId,
      cache: EntityImageScope.cacheOf(context),
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _own?.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pickFile(String title) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
      allowMultiple: false,
      dialogTitle: title,
    );
    final file = result?.files.single;
    if (file == null || !mounted) return null;
    if (file.size > 5 * 1024 * 1024) {
      _showMessage('A imagem deve ter no máximo 5 MB.');
      return null;
    }
    return file.bytes;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickProfile() async {
    final bytes = await _pickFile('Escolher ${widget.profileTitle.toLowerCase()}');
    if (bytes == null || !mounted) return;
    final result = await showDialog<AvatarCropResult>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AvatarCropDialog(bytes: bytes),
    );
    if (result != null) await _controller?.setImage(EntityImageKind.profile, result.bytes);
  }

  Future<void> _pickCover() async {
    final bytes = await _pickFile('Escolher ${widget.coverTitle.toLowerCase()}');
    if (bytes == null || !mounted) return;
    final result = await showDialog<CoverCropResult>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => CoverCropDialog(bytes: bytes),
    );
    if (result != null) await _controller?.setImage(EntityImageKind.cover, result.bytes);
  }

  Future<void> _designIcon() async {
    final controller = _controller;
    if (controller == null) return;
    final result = await showDialog<ActivityIconDesign>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ActivityIconDesignerDialog(
        initial: ActivityIconDesign.fromSpec(controller.iconSpecOf(EntityImageKind.icon)),
      ),
    );
    if (result == null) return;
    final bytes = await result.rasterize();
    if (bytes == null) return;
    await controller.setImage(EntityImageKind.icon, bytes, iconSpec: result.toSpec());
    // O mesmo desenho em SVG vai junto (icon_vector), para superfícies vetoriais.
    final svg = result.toSvg();
    if (svg != null && controller.error == null) {
      await controller.setImage(EntityImageKind.iconVector, svg, iconSpec: result.toSpec());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showProfile)
          _ImageRow(
            key: const Key('entity-image-profile'),
            title: widget.profileTitle,
            description:
                'Imagem quadrada em PNG, JPG ou WebP, até 5 MB. Você ajusta o enquadramento.',
            preview: _Preview(
              bytes: controller.bytesOf(EntityImageKind.profile),
              circular: true,
              icon: _profileIcon,
            ),
            has: controller.has(EntityImageKind.profile),
            busy: controller.isBusy(EntityImageKind.profile),
            pickKey: const Key('entity-image-profile-pick'),
            onPick: _pickProfile,
            onRemove: () => controller.removeImage(EntityImageKind.profile),
          ),
        if (widget.showProfile && widget.showCover) const SizedBox(height: CoeloSpacing.space3),
        if (widget.showCover)
          _ImageRow(
            key: const Key('entity-image-cover'),
            title: widget.coverTitle,
            description: 'Imagem larga (proporção 2,7:1) em PNG, JPG ou WebP, até 5 MB.',
            preview: _Preview(
              bytes: controller.bytesOf(EntityImageKind.cover),
              circular: false,
              icon: Icons.panorama_outlined,
            ),
            has: controller.has(EntityImageKind.cover),
            busy: controller.isBusy(EntityImageKind.cover),
            pickKey: const Key('entity-image-cover-pick'),
            onPick: _pickCover,
            onRemove: () => controller.removeImage(EntityImageKind.cover),
          ),
        if (widget.showIcon) ...[
          if (widget.showProfile || widget.showCover) const SizedBox(height: CoeloSpacing.space3),
          _ImageRow(
            key: const Key('entity-image-icon'),
            title: 'Ícone',
            description:
                'Escolha um símbolo, a cor dele e a cor do fundo. Vale quando não há foto.',
            preview: _Preview(
              bytes: controller.bytesOf(EntityImageKind.icon),
              circular: false,
              icon: Icons.emoji_symbols_outlined,
              rounded: true,
            ),
            has: controller.has(EntityImageKind.icon),
            busy: controller.isBusy(EntityImageKind.icon),
            pickKey: const Key('entity-image-icon-pick'),
            pickLabel: controller.has(EntityImageKind.icon) ? 'Editar ícone' : 'Criar ícone',
            pickIcon: Icons.palette_outlined,
            onPick: _designIcon,
            onRemove: () async {
              await controller.removeImage(EntityImageKind.icon);
              await controller.removeImage(EntityImageKind.iconVector);
            },
          ),
        ],
        if (controller.error case final error?) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            error,
            key: const Key('entity-image-error'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  IconData get _profileIcon => switch (widget.kind) {
    EntityKind.institution => Icons.apartment_rounded,
    EntityKind.unit => Icons.location_city_rounded,
    EntityKind.group => Icons.groups_rounded,
    EntityKind.activity => Icons.local_activity_outlined,
    EntityKind.person || EntityKind.internalUser => Icons.person_outline,
  };
}

final class _ImageRow extends StatelessWidget {
  const _ImageRow({
    required this.title,
    required this.description,
    required this.preview,
    required this.has,
    required this.busy,
    required this.pickKey,
    required this.onPick,
    required this.onRemove,
    this.pickLabel,
    this.pickIcon = Icons.add_a_photo_outlined,
    super.key,
  });

  final String title;
  final String description;
  final Widget preview;
  final bool has;
  final bool busy;
  final Key pickKey;
  final String? pickLabel;
  final IconData pickIcon;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          preview,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.spaceHalf),
                Text(description, style: theme.textTheme.bodySmall),
                const SizedBox(height: CoeloSpacing.space2),
                Wrap(
                  spacing: CoeloSpacing.space2,
                  runSpacing: CoeloSpacing.space2,
                  children: [
                    OutlinedButton.icon(
                      key: pickKey,
                      onPressed: busy ? null : onPick,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: CoeloSize.iconSm,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(pickIcon),
                      label: Text(
                        busy
                            ? 'Enviando…'
                            : (pickLabel ?? (has ? 'Trocar foto' : 'Adicionar foto')),
                      ),
                    ),
                    if (has)
                      TextButton(onPressed: busy ? null : onRemove, child: const Text('Remover')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _Preview extends StatelessWidget {
  const _Preview({
    required this.bytes,
    required this.circular,
    required this.icon,
    this.rounded = false,
  });

  final Uint8List? bytes;
  final bool circular;
  final bool rounded;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(circular ? CoeloRadius.full : CoeloRadius.md);
    return Container(
      width: circular || rounded ? CoeloSize.touchMin * 2 : CoeloSize.touchMin * 3,
      height: CoeloSize.touchMin * 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: radius,
        border: circular ? null : Border.all(color: colors.outlineVariant),
      ),
      child: bytes == null
          ? Icon(icon, color: colors.primary, size: CoeloSize.iconLg)
          : Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}
