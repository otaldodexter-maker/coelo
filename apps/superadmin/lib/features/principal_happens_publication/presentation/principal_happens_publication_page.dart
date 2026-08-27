import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';

import '../../principal_shared/presentation/principal_preview_app_bar.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../application/happens_publication_controller.dart';
import '../domain/happens_publication.dart';

typedef HappensMediaPicker = Future<List<HappensMediaDraft>> Function();

class PrincipalHappensPublicationPage extends StatefulWidget {
  const PrincipalHappensPublicationPage({
    required this.repository,
    this.publicationContext = HappensPublicationContext.demo,
    this.onClose,
    this.onCompleted,
    this.mediaPicker,
    super.key,
  });

  final HappensPublicationRepository repository;
  final HappensPublicationContext publicationContext;
  final VoidCallback? onClose;
  final ValueChanged<HappensPublication>? onCompleted;
  final HappensMediaPicker? mediaPicker;

  @override
  State<PrincipalHappensPublicationPage> createState() => _PrincipalHappensPublicationPageState();
}

class _PrincipalHappensPublicationPageState extends State<PrincipalHappensPublicationPage> {
  late final HappensPublicationController controller;
  var _step = 0;

  @override
  void initState() {
    super.initState();
    controller = HappensPublicationController(
      repository: widget.repository,
      context: widget.publicationContext,
    )..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = widget.mediaPicker == null
        ? await _defaultPicker()
        : await widget.mediaPicker!();
    for (final media in picked) {
      controller.addMedia(media);
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
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: PrincipalPreviewAppBar(
          keyPrefix: 'principal-happens-publication',
          onReportBug: () => _prototypeMessage('Reporte de bug'),
          onOpenNotifications: () => _prototypeMessage('Notificações'),
          onOpenContext: () => _prototypeMessage('Troca de contexto'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => SuperadminFormFrame(
            viewportWidth: constraints.maxWidth,
            scrollKey: Key('happens-publication-step-$_step'),
            navigation: SuperadminFormStepNavigation(
              steps: [
                for (var index = 0; index < _publicationSteps.length; index++)
                  SuperadminFormStep(
                    label: _publicationSteps[index],
                    status: index == _step
                        ? SuperadminFormStepStatus.current
                        : index < _step
                        ? SuperadminFormStepStatus.complete
                        : SuperadminFormStepStatus.incomplete,
                    enabled: index <= _step,
                  ),
              ],
              currentIndex: _step,
              onStepSelected: (index) => setState(() => _step = index),
            ),
            body: _WizardBody(
              controller: controller,
              step: _step,
              onPick: _pick,
              publicationContext: widget.publicationContext,
            ),
            footer: SuperadminFormActionFooter(
              tertiaryAction: TextButton(
                onPressed: state.phase == HappensPublicationPhase.publishing
                    ? null
                    : widget.onClose ?? () => Navigator.maybePop(context),
                child: const Text('Cancelar'),
              ),
              continuationActions: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: state.phase == HappensPublicationPhase.publishing
                        ? null
                        : () => setState(() => _step--),
                    child: const Text('Anterior'),
                  ),
                if (_step < _publicationSteps.length - 1)
                  FilledButton(
                    onPressed: () => setState(() => _step++),
                    child: const Text('Continuar'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: state.phase == HappensPublicationPhase.autosaving
                        ? null
                        : controller.saveDraft,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar rascunho'),
                  ),
                  FilledButton.icon(
                    onPressed: state.phase == HappensPublicationPhase.publishing
                        ? null
                        : () async {
                            final result = await controller.publish();
                            if (result != null) widget.onCompleted?.call(result);
                          },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Publicar no Acontece', style: Theme.of(context).textTheme.headlineSmall),
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
          const SizedBox(height: CoeloSpacing.space6),
          _FeedPreview(state: state, publicationContext: publicationContext),
        ],
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

class _AutosaveToggle extends StatefulWidget {
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
  State<_AutosaveToggle> createState() => _AutosaveToggleState();
}

class _AutosaveToggleState extends State<_AutosaveToggle> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Salvar como rascunho');
  bool _hovered = false;
  bool _focused = false;

  void _toggle() => widget.onChanged(!widget.value);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(CoeloRadius.lg);
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      toggled: widget.value,
      label: widget.label,
      hint: widget.description,
      onTap: _toggle,
      child: FocusableActionDetector(
        key: const Key('happens-autosave-toggle'),
        focusNode: _focusNode,
        mouseCursor: SystemMouseCursors.click,
        onFocusChange: (value) => setState(() => _focused = value),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle())},
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: AnimatedContainer(
              key: const Key('happens-autosave-surface'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? CoeloMotion.instant
                  : CoeloMotion.short,
              decoration: BoxDecoration(
                color: _hovered || _focused ? colors.primaryContainer : colors.surface,
                borderRadius: radius,
                border: Border.all(color: _focused ? colors.primary : colors.outlineVariant),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: CoeloSpacing.space1),
                            Text(
                              widget.description,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space3),
                      _ToggleIndicator(value: widget.value),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleIndicator extends StatelessWidget {
  const _ToggleIndicator({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? CoeloMotion.instant
        : CoeloMotion.short;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: duration,
        width: CoeloSpacing.space10,
        height: CoeloSpacing.space6,
        padding: const EdgeInsets.all(CoeloSpacing.spaceHalf),
        decoration: BoxDecoration(
          color: value ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(CoeloRadius.full),
          border: Border.all(color: value ? colors.primary : colors.outlineVariant),
        ),
        child: AnimatedAlign(
          duration: duration,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: CoeloSpacing.space5,
            height: CoeloSpacing.space5,
            decoration: BoxDecoration(
              color: value ? colors.onPrimary : colors.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
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
  return media.isVideo
      ? ColoredBox(
          color: colors.inverseSurface,
          child: Center(
            child: Icon(Icons.play_circle_fill, color: colors.onInverseSurface, size: 48),
          ),
        )
      : Image.memory(
          media.bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(
            color: colors.surfaceContainerLow,
            child: const Icon(Icons.image_outlined),
          ),
        );
}

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
