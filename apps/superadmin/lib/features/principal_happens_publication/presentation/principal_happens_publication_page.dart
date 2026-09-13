import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';

import '../../principal_shared/presentation/principal_preview_app_bar.dart';
import '../../principal_shared/presentation/principal_publication_frame.dart';
import '../application/happens_publication_controller.dart';
import '../domain/happens_publication.dart';

typedef HappensMediaPicker = Future<List<HappensMediaDraft>> Function();

class PrincipalHappensPublicationPage extends StatefulWidget {
  const PrincipalHappensPublicationPage({
    required this.repository,
    required this.publicationContext,
    this.embedded = false,
    this.onClose,
    this.onCompleted,
    this.mediaPicker,
    super.key,
  });

  const PrincipalHappensPublicationPage.demo({
    required this.repository,
    this.publicationContext = HappensPublicationContext.demo,
    this.embedded = false,
    this.onClose,
    this.onCompleted,
    this.mediaPicker,
    super.key,
  });

  final HappensPublicationRepository repository;
  final bool embedded;
  final HappensPublicationContext publicationContext;
  final VoidCallback? onClose;
  final ValueChanged<HappensPublication>? onCompleted;
  final HappensMediaPicker? mediaPicker;

  @override
  State<PrincipalHappensPublicationPage> createState() => _PrincipalHappensPublicationPageState();
}

class _PrincipalHappensPublicationPageState extends State<PrincipalHappensPublicationPage> {
  late HappensPublicationController controller;
  var _pageGeneration = 0;
  var _pickerInFlight = false;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    controller = HappensPublicationController(
      repository: widget.repository,
      context: widget.publicationContext,
    )..load();
  }

  @override
  void didUpdateWidget(covariant PrincipalHappensPublicationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        _sameContext(oldWidget.publicationContext, widget.publicationContext)) {
      return;
    }
    _pageGeneration += 1;
    controller.dispose();
    _pickerInFlight = false;
    _createController();
  }

  @override
  void dispose() {
    _pageGeneration += 1;
    controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_pickerInFlight || controller.operationInFlight) return;
    final generation = _pageGeneration;
    final requestedController = controller;
    setState(() => _pickerInFlight = true);
    try {
      final picked = widget.mediaPicker == null
          ? await _defaultPicker()
          : await widget.mediaPicker!();
      if (!mounted ||
          generation != _pageGeneration ||
          !identical(controller, requestedController)) {
        return;
      }
      for (final media in picked) {
        controller.addMedia(media);
      }
    } finally {
      if (mounted && generation == _pageGeneration && identical(controller, requestedController)) {
        setState(() => _pickerInFlight = false);
      }
    }
  }

  Future<List<HappensMediaDraft>> _defaultPicker() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
    );
    return (result?.files ?? const <PlatformFile>[])
        .where((file) => file.bytes != null)
        .map(
          (file) => HappensMediaDraft(
            localId: '${DateTime.now().microsecondsSinceEpoch}-${file.name}',
            name: file.name,
            mimeType: _mime(file.extension),
            bytes: file.bytes!,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.state;
      if (state.phase == HappensPublicationPhase.loading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(key: Key('happens-publication-loading'))),
        );
      }
      if (state.phase == HappensPublicationPhase.unauthorized) {
        return Scaffold(
          body: CoeloStatePanel(
            title: 'Publicação indisponível',
            message: state.message ?? 'Você não pode publicar neste contexto.',
            icon: Icons.lock_outline_rounded,
          ),
        );
      }
      if (state.phase == HappensPublicationPhase.failure &&
          state.failureSource == HappensPublicationFailureSource.load) {
        return Scaffold(
          body: CoeloStatePanel(
            title: 'Não foi possível carregar',
            message: state.message ?? 'Tente novamente.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Tentar novamente',
            onAction: controller.load,
          ),
        );
      }
      if (state.phase == HappensPublicationPhase.conflict) {
        return Scaffold(
          body: CoeloStatePanel(
            title: 'Rascunho alterado',
            message: state.message ?? 'O rascunho mudou em outro lugar.',
            icon: Icons.sync_problem_outlined,
            actionLabel: 'Recarregar rascunho',
            onAction: controller.load,
          ),
        );
      }
      final actionsEnabled =
          !controller.operationInFlight &&
          !_pickerInFlight &&
          (state.phase == HappensPublicationPhase.editing ||
              state.phase == HappensPublicationPhase.saved ||
              state.phase == HappensPublicationPhase.failure);
      final surfaceLocked = controller.operationInFlight || _pickerInFlight;
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: widget.embedded
            ? null
            : PrincipalPreviewAppBar(
                keyPrefix: 'principal-happens-publication',
                onReportBug: () => _prototypeMessage('Reporte de bug'),
                onOpenNotifications: () => _prototypeMessage('Notificações'),
                onOpenContext: () => _prototypeMessage('Troca de contexto'),
              ),
        body: PrincipalPublicationSheet(
          scrollKey: const Key('happens-publication-scroll'),
          subtitle: 'Publicar no Acontece',
          body: ExcludeFocus(
            key: const Key('happens-publication-body-focus-lock'),
            excluding: surfaceLocked,
            child: AbsorbPointer(
              key: const Key('happens-publication-body-lock'),
              absorbing: surfaceLocked,
              child: _PublicationBody(
                controller: controller,
                onPick: _pick,
                publicationContext: widget.publicationContext,
              ),
            ),
          ),
          asideKey: const Key('happens-publication-desktop-preview'),
          aside: _FeedPreview(state: state, publicationContext: widget.publicationContext),
          footer: PrincipalPublicationActionFooter(
            surfaceKey: const Key('happens-publication-footer'),
            tertiaryAction: TextButton(
              onPressed: actionsEnabled
                  ? widget.onClose ?? () => Navigator.maybePop(context)
                  : null,
              child: const Text('Cancelar'),
            ),
            continuationActions: [
              OutlinedButton(
                key: const Key('happens-publication-save'),
                onPressed: actionsEnabled ? controller.saveDraft : null,
                child: const Text('Salvar rascunho'),
              ),
              FilledButton.icon(
                key: const Key('happens-publication-publish'),
                onPressed: actionsEnabled
                    ? () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final generation = _pageGeneration;
                        final requestedController = controller;
                        final result = await controller.publish();
                        if (!mounted ||
                            generation != _pageGeneration ||
                            !identical(controller, requestedController)) {
                          return;
                        }
                        if (result != null) widget.onCompleted?.call(result);
                      }
                    : null,
                icon: const Icon(Icons.send_outlined),
                label: Text(
                  state.draft.publishAt == null ? 'Publicar no Acontece' : 'Agendar publicação',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _prototypeMessage(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label ainda não está disponível.')));
  }

  bool _sameContext(HappensPublicationContext a, HappensPublicationContext b) =>
      a.institutionId == b.institutionId &&
      a.institutionName == b.institutionName &&
      a.unitId == b.unitId &&
      a.unitName == b.unitName &&
      a.groupId == b.groupId &&
      a.groupName == b.groupName;
}

/// Familia Publicacao (Owner, 11/09/2026 17:19): midia primeiro, depois
/// Legenda, Publico e contexto (com chips), Agendamento e Opcoes, todos em uma
/// coluna; a previa vive na coluna lateral do sheet no desktop.
class _PublicationBody extends StatelessWidget {
  const _PublicationBody({
    required this.controller,
    required this.onPick,
    required this.publicationContext,
  });

  final HappensPublicationController controller;
  final VoidCallback onPick;
  final HappensPublicationContext publicationContext;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final draft = state.draft;
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.message != null) ...[
          CoeloStatePanel(
            title: 'Revise a publicação',
            message: state.message!,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        Text('Mídia', style: labelStyle),
        const SizedBox(height: CoeloSpacing.space2),
        _MediaStage(
          draft: draft,
          onPick: onPick,
          onRemove: controller.removeMedia,
          onReorder: controller.reorderMedia,
        ),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Legenda', style: labelStyle),
        const SizedBox(height: CoeloSpacing.space2),
        _CaptionField(value: draft.caption, onChanged: controller.setCaption),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Público e contexto', style: labelStyle),
        const SizedBox(height: CoeloSpacing.space2),
        _ContextCard(contextData: controller.context),
        const SizedBox(height: CoeloSpacing.space3),
        _AudienceSelector(selected: draft.audiences, onToggle: controller.toggleAudience),
        const SizedBox(height: CoeloSpacing.space4),
        _ScheduleField(value: draft.publishAt, onChanged: controller.setPublishAt),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Opções', style: labelStyle),
        const SizedBox(height: CoeloSpacing.space2),
        _AutosaveToggle(
          label: 'Salvar como rascunho',
          description: 'Ative para salvar automaticamente.',
          value: state.autosave,
          onChanged: controller.setAutosave,
        ),
      ],
    );
  }
}

class _CaptionField extends StatefulWidget {
  const _CaptionField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_CaptionField> createState() => _CaptionFieldState();
}

class _AudienceSelector extends StatelessWidget {
  const _AudienceSelector({required this.selected, required this.onToggle});

  final Set<HappensAudienceKind> selected;
  final ValueChanged<HappensAudienceKind> onToggle;

  @override
  Widget build(BuildContext context) {
    final toggles = HappensAudienceKind.values
        .map(
          (kind) => _AudienceToggle(
            label: Text(_audienceLabel(kind)),
            selected: selected.contains(kind),
            onPressed: () => onToggle(kind),
          ),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < toggles.length; index++) ...[
                  if (index > 0) const SizedBox(width: CoeloSpacing.space2),
                  toggles[index],
                ],
              ],
            ),
          );
        }
        return Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: toggles,
        );
      },
    );
  }
}

class _AudienceToggle extends StatefulWidget {
  const _AudienceToggle({required this.label, required this.selected, required this.onPressed});

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_AudienceToggle> createState() => _AudienceToggleState();
}

class _AudienceToggleState extends State<_AudienceToggle> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlighted = widget.selected || _hovered || _focused;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        // Focus, not FocusableActionDetector: the child is already a real button
        // with keyboard activation, and the detector was a second Tab stop over
        // the same chip that looked focused and activated nothing.
        child: Focus(
          canRequestFocus: false,
          onFocusChange: (value) => setState(() => _focused = value),
          child: TextButton.icon(
            onPressed: widget.onPressed,
            style: TextButton.styleFrom(
              foregroundColor: highlighted ? colors.onPrimaryContainer : colors.onSurface,
              backgroundColor: highlighted ? colors.primaryContainer : colors.surface,
              side: BorderSide(color: widget.selected ? colors.primary : colors.outlineVariant),
              minimumSize: const Size(0, CoeloSize.touchMin),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.full)),
              overlayColor: Colors.transparent,
            ),
            icon: Icon(widget.selected ? Icons.check_rounded : Icons.group_outlined, size: 18),
            label: widget.label,
          ),
        ),
      ),
    );
  }
}

class _AutosaveToggle extends StatelessWidget {
  const _AutosaveToggle({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => PrincipalPublicationToggleField(
    key: const Key('happens-autosave-toggle'),
    label: label,
    description: description,
    value: value,
    onChanged: onChanged,
  );
}

class _CaptionFieldState extends State<_CaptionField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _CaptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloFormTextField(
    fieldKey: const Key('happens-caption'),
    controller: _controller,
    labelText: 'Legenda',
    hintText: 'Aprender juntos é crescer juntos.',
    prefixIcon: Icons.notes_rounded,
    maxLength: 2200,
    maxLines: 5,
    onChanged: widget.onChanged,
  );
}

class _MediaStage extends StatelessWidget {
  const _MediaStage({
    required this.draft,
    required this.onPick,
    required this.onRemove,
    required this.onReorder,
  });
  final HappensPostDraft draft;
  final VoidCallback onPick;
  final Future<void> Function(int) onRemove;
  final void Function(int, int) onReorder;
  @override
  Widget build(BuildContext context) {
    final media = draft.media.isEmpty ? null : draft.media.first;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Referencia aprovada (acontece-web-1440): carrossel largo, ate 300 px
        // de altura no desktop; no mobile mantem a proporcao da largura.
        LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: AspectRatio(
              aspectRatio: media == null && MediaQuery.textScalerOf(context).scale(1) > 1.5
                  ? 1
                  : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                  ? 16 / 7
                  : 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                child: Container(
                  color: colors.surfaceContainerLow,
                  child: media == null
                      ? CoeloCreateAction(
                          label: 'Adicionar fotos ou vídeos',
                          icon: Icons.add_photo_alternate_outlined,
                          onPressed: onPick,
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            _media(context, media),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: _Pill(text: '1/${draft.media.length}'),
                            ),
                            Positioned(right: 12, bottom: 12, child: _Pill(text: 'Editar capa')),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        SizedBox(
          height: CoeloSpacing.space16,
          child: Row(
            children: [
              SizedBox.square(
                dimension: CoeloSpacing.space16,
                child: OutlinedButton(onPressed: onPick, child: const Icon(Icons.add)),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIndex, adjustedNewIndex) {
                    final legacyNewIndex = adjustedNewIndex > oldIndex
                        ? adjustedNewIndex + 1
                        : adjustedNewIndex;
                    onReorder(oldIndex, legacyNewIndex);
                  },
                  itemCount: draft.media.length,
                  itemBuilder: (context, index) {
                    final item = draft.media[index];
                    return Padding(
                      key: ValueKey(item.localId),
                      padding: const EdgeInsets.only(right: CoeloSpacing.space2),
                      child: ReorderableDragStartListener(
                        index: index,
                        child: Stack(
                          children: [
                            SizedBox(
                              width: CoeloSpacing.space16,
                              height: CoeloSpacing.space16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(CoeloRadius.sm),
                                child: _media(context, item),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: IconButton(
                                tooltip: 'Remover mídia ${index + 1}',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: CoeloSize.touchMin,
                                  height: CoeloSize.touchMin,
                                ),
                                onPressed: () => onRemove(index),
                                icon: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: colors.scrim.withValues(alpha: 0.68),
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: colors.onInverseSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _media(BuildContext context, HappensMediaDraft media) {
  final colors = Theme.of(context).colorScheme;
  if (media.isVideo) {
    return ColoredBox(
      color: colors.inverseSurface,
      child: Center(child: Icon(Icons.play_circle_fill, color: colors.onInverseSurface, size: 48)),
    );
  }
  final remoteUrl = media.remoteUrl;
  if (remoteUrl != null) {
    return Image.network(
      remoteUrl,
      key: const Key('happens-media-image'),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _unavailableMedia(colors),
    );
  }
  if (media.bytes.isNotEmpty) {
    return Image.memory(
      media.bytes,
      key: const Key('happens-media-image'),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _unavailableMedia(colors),
    );
  }
  return _unavailableMedia(colors);
}

Widget _unavailableMedia(ColorScheme colors) => ColoredBox(
  color: colors.surfaceContainerLow,
  child: const Center(child: Icon(Icons.image_not_supported_outlined)),
);

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.contextData});
  final HappensPublicationContext contextData;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        color: colors.surface,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: Icon(Icons.school_outlined, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contextData.institutionName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  contextData.scopeLabel,
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => CoeloDateTimeField(
    value: value,
    onChanged: onChanged,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    labelText: 'Agendamento',
  );
}

class _FeedPreview extends StatelessWidget {
  const _FeedPreview({required this.state, required this.publicationContext});
  final HappensPublicationState state;
  final HappensPublicationContext publicationContext;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prévia do post no Acontece',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space3),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primary,
                      child: Text('co', style: TextStyle(color: colors.onPrimary)),
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publicationContext.institutionName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          Text(
                            'Agora',
                            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  state.draft.caption.isEmpty ? 'Sua legenda aparecerá aqui.' : state.draft.caption,
                ),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              AspectRatio(
                aspectRatio: 1,
                child: state.draft.media.isEmpty
                    ? Container(
                        color: colors.surfaceContainerLow,
                        child: Icon(Icons.photo_outlined, size: 54, color: colors.primary),
                      )
                    : _media(context, state.draft.media.first),
              ),
              Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space3),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: colors.primary),
                    const SizedBox(width: CoeloSpacing.space2),
                    const Text('128'),
                    const SizedBox(width: CoeloSpacing.space2),
                    const Icon(Icons.chat_bubble_outline),
                    const SizedBox(width: CoeloSpacing.space2),
                    const Text('14'),
                    const Spacer(),
                    const Icon(Icons.bookmark_border),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Container(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.sm),
          ),
          child: const Text(
            'A prévia é uma simulação de como seu post aparecerá no feed do Acontece.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.scrim.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(CoeloRadius.full),
      ),
      child: Text(text, style: TextStyle(color: colors.onInverseSurface, fontSize: 11)),
    );
  }
}

String _audienceLabel(HappensAudienceKind value) => switch (value) {
  HappensAudienceKind.families => 'Famílias',
  HappensAudienceKind.students => 'Alunos',
  HappensAudienceKind.schoolStaff => 'Equipe escolar',
  HappensAudienceKind.guardiansOnly => 'Somente responsáveis',
};
String _mime(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'mp4' => 'video/mp4',
  _ => 'application/octet-stream',
};
