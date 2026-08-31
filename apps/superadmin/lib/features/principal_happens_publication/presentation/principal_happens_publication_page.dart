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
  var _step = 0;
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
    _step = 0;
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
        body: LayoutBuilder(
          builder: (context, constraints) => PrincipalPublicationFrame(
            scrollKey: Key('happens-publication-step-$_step'),
            navigation: ExcludeFocus(
              excluding: surfaceLocked,
              child: AbsorbPointer(
                absorbing: surfaceLocked,
                child: PrincipalPublicationStepNavigation(
                  steps: [
                    for (var index = 0; index < _publicationSteps.length; index++)
                      PrincipalPublicationStep(
                        label: _publicationSteps[index],
                        status: index == _step
                            ? PrincipalPublicationStepStatus.current
                            : index < _step
                            ? PrincipalPublicationStepStatus.complete
                            : PrincipalPublicationStepStatus.incomplete,
                        enabled: actionsEnabled && index <= _step,
                      ),
                  ],
                  currentIndex: _step,
                  onStepSelected: (index) {
                    if (actionsEnabled) setState(() => _step = index);
                  },
                ),
              ),
            ),
            body: ExcludeFocus(
              key: const Key('happens-publication-body-focus-lock'),
              excluding: surfaceLocked,
              child: AbsorbPointer(
                key: const Key('happens-publication-body-lock'),
                absorbing: surfaceLocked,
                child: _WizardBody(
                  controller: controller,
                  step: _step,
                  onPick: _pick,
                  publicationContext: widget.publicationContext,
                ),
              ),
            ),
            footer: PrincipalPublicationActionFooter(
              tertiaryAction: TextButton(
                onPressed: actionsEnabled
                    ? widget.onClose ?? () => Navigator.maybePop(context)
                    : null,
                child: const Text('Cancelar'),
              ),
              continuationActions: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: actionsEnabled ? () => setState(() => _step--) : null,
                    child: const Text('Anterior'),
                  ),
                if (_step < _publicationSteps.length - 1)
                  FilledButton(
                    onPressed: actionsEnabled ? () => setState(() => _step++) : null,
                    child: const Text('Continuar'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: actionsEnabled ? controller.saveDraft : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar rascunho'),
                  ),
                  FilledButton.icon(
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
              ],
            ),
          ),
        ),
      );
    },
  );

  void _prototypeMessage(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label estará disponível na experiência completa.')));
  }

  bool _sameContext(HappensPublicationContext a, HappensPublicationContext b) =>
      a.institutionId == b.institutionId &&
      a.institutionName == b.institutionName &&
      a.unitId == b.unitId &&
      a.unitName == b.unitName &&
      a.groupId == b.groupId &&
      a.groupName == b.groupName;
}

class _WizardBody extends StatelessWidget {
  const _WizardBody({
    required this.controller,
    required this.step,
    required this.onPick,
    required this.publicationContext,
  });

  final HappensPublicationController controller;
  final int step;
  final VoidCallback onPick;
  final HappensPublicationContext publicationContext;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final draft = state.draft;
    final colors = Theme.of(context).colorScheme;
    final useDesktopPreview =
        MediaQuery.sizeOf(context).width >= 840 && MediaQuery.textScalerOf(context).scale(1) <= 1.5;
    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sua publicação', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space1),
        Text('Publicar no Acontece', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space1),
        Text(
          'Etapa ${step + 1} de ${_publicationSteps.length} · ${_publicationSteps[step]}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (state.message != null) ...[
          CoeloStatePanel(
            title: 'Revise a publicação',
            message: state.message!,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        if (step == 0) ...[
          const Text('Mídia', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: CoeloSpacing.space2),
          Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: _MediaStage(
                draft: draft,
                onPick: onPick,
                onRemove: controller.removeMedia,
                onReorder: controller.reorderMedia,
              ),
            ),
          ),
        ] else if (step == 1) ...[
          Row(
            children: [
              const Expanded(
                child: Text('Legenda', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Text(
                '${draft.caption.length}/2.200',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          _CaptionField(value: draft.caption, onChanged: controller.setCaption),
          const SizedBox(height: CoeloSpacing.space4),
          _AutosaveToggle(
            label: 'Salvar como rascunho',
            description: 'Ative para salvar automaticamente.',
            value: state.autosave,
            onChanged: controller.setAutosave,
          ),
        ] else if (step == 2) ...[
          const Text('Público e contexto', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: CoeloSpacing.space2),
          _ContextCard(contextData: controller.context),
          const SizedBox(height: CoeloSpacing.space3),
          _AudienceSelector(selected: draft.audiences, onToggle: controller.toggleAudience),
        ] else ...[
          const Text('Agendamento', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: CoeloSpacing.space2),
          _ScheduleField(value: draft.publishAt, onChanged: controller.setPublishAt),
          if (!useDesktopPreview) ...[
            const SizedBox(height: CoeloSpacing.space6),
            _FeedPreview(state: state, publicationContext: publicationContext),
          ],
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!useDesktopPreview || constraints.maxWidth < 840) return editor;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: editor),
            const SizedBox(width: CoeloSpacing.space5),
            SizedBox(
              key: const Key('happens-publication-desktop-preview'),
              width: 320,
              child: _FeedPreview(state: state, publicationContext: publicationContext),
            ),
          ],
        );
      },
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
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => _focused = value),
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
    hintText: 'Aprender juntos é crescer juntos. 🌱',
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
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            child: Container(
              color: colors.surfaceContainerLow,
              child: media == null
                  ? TextButton(
                      onPressed: onPick,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 42,
                              color: colors.primary,
                            ),
                            const SizedBox(height: CoeloSpacing.space2),
                            const Text(
                              'Adicionar fotos ou vídeos',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
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
                        Positioned(left: 12, bottom: 12, child: _Pill(text: 'Editar capa')),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        SizedBox(
          height: CoeloSpacing.space16,
          child: Row(
            children: [
              OutlinedButton(onPressed: onPick, child: const Icon(Icons.add)),
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
                  '${contextData.unitName} · ${contextData.groupName}',
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
const _publicationSteps = ['Mídia', 'Conteúdo', 'Público', 'Revisão'];
String _mime(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'mp4' => 'video/mp4',
  _ => 'application/octet-stream',
};
