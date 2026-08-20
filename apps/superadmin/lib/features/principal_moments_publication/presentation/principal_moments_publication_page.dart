import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/moments_publication_controller.dart';
import '../domain/moments_publication.dart';

class PrincipalMomentsPublicationPage extends StatefulWidget {
  const PrincipalMomentsPublicationPage({
    super.key,
    this.controller,
    this.onAddMedia,
    this.onEditCover,
    this.onSelectContext,
    this.onOpenSchedule,
    this.onDraftSaved,
    this.onPublished,
    this.onClose,
  });

  final MomentsPublicationController? controller;
  final VoidCallback? onAddMedia;
  final VoidCallback? onEditCover;
  final VoidCallback? onSelectContext;
  final VoidCallback? onOpenSchedule;
  final ValueChanged<MomentsDraft>? onDraftSaved;
  final ValueChanged<MomentsPublication>? onPublished;
  final VoidCallback? onClose;

  @override
  State<PrincipalMomentsPublicationPage> createState() => _PrincipalMomentsPublicationPageState();
}

class _PrincipalMomentsPublicationPageState extends State<PrincipalMomentsPublicationPage> {
  late final MomentsPublicationController _controller;
  late final bool _ownsController;
  late final TextEditingController _captionController;
  int _selectedMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _createDemoController();
    _captionController = TextEditingController();
    _controller.addListener(_syncCaption);
    unawaited(_load());
  }

  MomentsPublicationController _createDemoController() {
    final draft = MomentsDraft(
      caption:
          'Aprender juntos é crescer juntos. 🌱\n\n'
          'Momentos que fortalecem laços, despertam curiosidade e constroem o futuro.\n\n'
          '#coelomomentos',
      audiences: const {MomentsAudienceKind.families},
      media: List.generate(5, MomentsMediaDraft.demo),
    );
    return MomentsPublicationController(
      repository: InMemoryMomentsPublicationRepository(draft: draft),
      context: MomentsPublicationContext.demo,
    );
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted) return;
    _syncCaption();
  }

  void _syncCaption() {
    final caption = _controller.state.draft.caption;
    if (_captionController.text == caption) return;
    _captionController.value = TextEditingValue(
      text: caption,
      selection: TextSelection.collapsed(offset: caption.length),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_syncCaption);
    _captionController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width >= 1200) return _desktop(width);
              return _compactOrTablet(width);
            },
          ),
        ),
      ),
    );
  }

  Widget _compactOrTablet(double width) {
    final isTablet = width >= 700;
    final padding = isTablet ? CoeloSpacing.space6 : CoeloSpacing.space4;
    return Column(
      children: [
        if (isTablet) ...[
          _CompactHeader(onNotifications: _showNotifications),
          _PageHeading(onClose: widget.onClose),
        ] else
          _MobilePageHeader(onClose: widget.onClose, onNotifications: _showNotifications),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('moments-publication-scroll'),
            padding: EdgeInsets.fromLTRB(padding, CoeloSpacing.space4, padding, 112),
            child: isTablet ? _tabletEditor() : _mobileEditor(),
          ),
        ),
        _ActionFooter(state: _controller.state, onSave: _saveDraft, onPublish: _publish),
      ],
    );
  }

  Widget _desktop(double width) => Column(
    children: [
      _DesktopHeader(onNotifications: _showNotifications),
      Expanded(
        child: Row(
          children: [
            const _DesktopRail(),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('moments-publication-scroll'),
                      padding: const EdgeInsets.all(CoeloSpacing.space8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Publicar em Momentos',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: CoeloSpacing.space5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 10, child: _mediaPanel()),
                                  const SizedBox(width: CoeloSpacing.space4),
                                  Expanded(flex: 10, child: _editorPanel()),
                                  const SizedBox(width: CoeloSpacing.space4),
                                  Expanded(flex: 8, child: _previewPanel()),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _ActionFooter(
                    state: _controller.state,
                    onSave: _saveDraft,
                    onPublish: _publish,
                    maxWidth: 1120,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _mobileEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _mediaPanel(),
      const SizedBox(height: CoeloSpacing.space3),
      _captionCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _audienceCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _scheduleCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _optionsCard(),
    ],
  );

  Widget _tabletEditor() => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 11, child: _mediaPanel()),
          const SizedBox(width: CoeloSpacing.space4),
          Expanded(
            flex: 9,
            child: Column(
              children: [
                _captionCard(),
                const SizedBox(height: CoeloSpacing.space3),
                _audienceCard(),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _scheduleCard()),
          const SizedBox(width: CoeloSpacing.space4),
          Expanded(child: _optionsCard()),
        ],
      ),
    ],
  );

  Widget _editorPanel() => Column(
    children: [
      _captionCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _audienceCard(),
      const SizedBox(height: CoeloSpacing.space3),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _scheduleCard()),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(child: _optionsCard()),
        ],
      ),
    ],
  );

  Widget _mediaPanel() {
    final media = _controller.state.draft.media;
    final selectedIndex = media.isEmpty ? 0 : _selectedMediaIndex.clamp(0, media.length - 1);
    final selected = media.isEmpty ? MomentsMediaDraft.demo(0) : media[selectedIndex];
    return _SectionCard(
      label: 'Mídia',
      child: Column(
        children: [
          AspectRatio(
            key: const Key('moments-publication-primary-media'),
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MomentAsset(media: selected, radius: CoeloRadius.md),
                Positioned(
                  right: CoeloSpacing.space2,
                  top: CoeloSpacing.space2,
                  child: _MediaBadge(
                    label: '${selectedIndex + 1}/${media.isEmpty ? 1 : media.length}',
                  ),
                ),
                Positioned(
                  left: CoeloSpacing.space2,
                  bottom: CoeloSpacing.space2,
                  child: FilledButton.tonalIcon(
                    key: const Key('moments-publication-edit-cover'),
                    onPressed: _editCover,
                    icon: const Icon(Icons.edit_outlined, size: CoeloSize.iconSm),
                    label: const Text('Editar capa'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.66),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size(48, 48),
                      overlayColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                _AddMediaButton(onPressed: _addMedia),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: media.length,
                    separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space2),
                    itemBuilder: (context, index) => _MediaThumbnail(
                      key: ValueKey('moments-media-${media[index].localId}'),
                      media: media[index],
                      selected: index == selectedIndex,
                      onPressed: () => setState(() => _selectedMediaIndex = index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _captionCard() => _SectionCard(
    label: 'Legenda',
    trailing: Text('${_controller.state.draft.captionCharacters}/2200'),
    child: CoeloFormTextField(
      fieldKey: const Key('moments-publication-caption'),
      controller: _captionController,
      labelText: 'Legenda',
      prefixIcon: Icons.notes_rounded,
      hintText: 'Conte o que torna este momento especial.',
      onChanged: _controller.setCaption,
      maxLines: 6,
    ),
  );

  Widget _audienceCard() {
    final context = _controller.context;
    return _SectionCard(
      label: 'Público e contexto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContextTile(context: context, onPressed: _selectContext),
          const SizedBox(height: CoeloSpacing.space3),
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: MomentsAudienceKind.values
                .map(
                  (audience) => _AudienceChip(
                    key: Key('moments-audience-${audience.keyName}'),
                    audience: audience,
                    selected: _controller.state.draft.audiences.contains(audience),
                    onSelected: () => _controller.toggleAudience(audience),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard() => _SectionCard(
    label: 'Agendamento',
    child: _SettingRow(
      key: const Key('moments-publication-schedule'),
      icon: Icons.calendar_today_outlined,
      label: 'Publicar agora',
      valueColor: true,
      trailing: Icons.keyboard_arrow_down_rounded,
      onPressed: _openSchedule,
    ),
  );

  Widget _optionsCard() => _SectionCard(
    label: 'Opções',
    child: _MomentToggleField(
      key: const Key('moments-publication-save-toggle'),
      label: 'Salvar como rascunho',
      value: _controller.state.draft.saveAsDraft,
      onChanged: _controller.setSaveAsDraft,
    ),
  );

  Widget _previewPanel() => _SectionCard(
    key: const Key('moments-publication-preview'),
    label: 'Prévia do momento',
    trailing: const Tooltip(
      message: 'Simulação de como a publicação aparecerá em Momentos.',
      child: Icon(Icons.info_outline_rounded, size: CoeloSize.iconSm),
    ),
    child: _MomentPreview(draft: _controller.state.draft, context: _controller.context),
  );

  void _addMedia() {
    if (widget.onAddMedia case final callback?) {
      callback();
      return;
    }
    _controller.addMedia(MomentsMediaDraft.demo(_controller.state.draft.media.length));
    if (_controller.state.draft.media.isNotEmpty) {
      setState(() => _selectedMediaIndex = _controller.state.draft.media.length - 1);
    }
    _showMessage(_controller.state.message ?? 'Mídia adicionada à demonstração.');
  }

  void _editCover() {
    if (widget.onEditCover case final callback?) {
      callback();
      return;
    }
    _showMessage('A capa será ajustada no fluxo de mídia.');
  }

  void _selectContext() {
    if (widget.onSelectContext case final callback?) {
      callback();
      return;
    }
    _showMessage('A seleção de contexto será aberta no fluxo de publicação.');
  }

  void _openSchedule() {
    if (widget.onOpenSchedule case final callback?) {
      callback();
      return;
    }
    _showMessage('O agendamento permanece em “Publicar agora” nesta versão.');
  }

  Future<void> _saveDraft() async {
    await _controller.saveDraft();
    if (!mounted) return;
    _showMessage(_controller.state.message ?? 'Rascunho salvo.');
    if (_controller.state.phase == MomentsPublicationPhase.saved) {
      widget.onDraftSaved?.call(_controller.state.draft);
      widget.onClose?.call();
    }
  }

  Future<void> _publish() async {
    final publication = await _controller.publish();
    if (!mounted) return;
    _showMessage(
      publication == null
          ? (_controller.state.message ?? 'Revise os dados antes de publicar.')
          : 'Momento publicado.',
    );
    if (publication != null) {
      widget.onPublished?.call(publication);
      widget.onClose?.call();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            CoeloSpacing.space4,
            CoeloSpacing.space4,
            CoeloSpacing.space4,
            96,
          ),
        ),
      );
  }

  void _showNotifications() => _showMessage('Você não tem novas notificações.');
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            child,
          ],
        ),
      ),
    );
  }
}

class _MomentAsset extends StatelessWidget {
  const _MomentAsset({required this.media, required this.radius});

  final MomentsMediaDraft media;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stripWidth = constraints.maxWidth * 5;
        return OverflowBox(
          alignment: Alignment(-1 + (media.cropIndex * 0.5), 0),
          minWidth: stripWidth,
          maxWidth: stripWidth,
          minHeight: constraints.maxHeight,
          maxHeight: constraints.maxHeight,
          child: Image.asset(
            media.assetPath,
            width: stripWidth,
            height: constraints.maxHeight,
            fit: BoxFit.fill,
            semanticLabel: 'Capa do momento selecionado',
            errorBuilder: (context, _, _) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        );
      },
    ),
  );
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.scrim.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(CoeloRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space2,
          vertical: CoeloSpacing.space1,
        ),
        child: Text(label, style: TextStyle(color: colors.onPrimary)),
      ),
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  const _AddMediaButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 64,
    child: OutlinedButton(
      key: const Key('moments-publication-add-media'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
      child: const Icon(Icons.add_rounded),
    ),
  );
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    super.key,
    required this.media,
    required this.selected,
    required this.onPressed,
  });

  final MomentsMediaDraft media;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Mídia ${media.cropIndex + 1}, duração ${media.durationLabel}',
      child: SizedBox(
        width: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: selected || states.contains(WidgetState.focused)
                    ? colors.primary
                    : colors.outlineVariant,
                width: selected || states.contains(WidgetState.focused) ? 2 : 1,
              ),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.sm)),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MomentAsset(media: media, radius: CoeloRadius.sm - 1),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: colors.scrim.withValues(alpha: 0.56),
                  padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
                  child: Text(
                    media.durationLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colors.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextTile extends StatelessWidget {
  const _ContextTile({required this.context, required this.onPressed});

  final MomentsPublicationContext context;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      key: const Key('moments-publication-context'),
      onPressed: onPressed,
      style: _discreteActionStyle(context),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.account_balance_outlined, size: CoeloSize.iconSm),
          ),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  this.context.institutionName,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${this.context.unitName} · ${this.context.groupName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
    super.key,
    required this.audience,
    required this.selected,
    required this.onSelected,
  });

  final MomentsAudienceKind audience;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: OutlinedButton.icon(
        onPressed: onSelected,
        icon: Icon(audience.icon, size: CoeloSize.iconSm),
        label: Text(audience.label),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, CoeloSize.touchMin)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                selected ||
                    states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)
                ? colors.primaryContainer
                : colors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                selected ||
                    states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)
                ? colors.primary
                : colors.onSurface,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: selected || states.contains(WidgetState.focused)
                  ? colors.primary
                  : colors.outlineVariant,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.valueColor = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final IconData? trailing;
  final bool valueColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = valueColor ? colors.primary : colors.onSurface;
    return OutlinedButton(
      onPressed: onPressed,
      style: _discreteActionStyle(context),
      child: Row(
        children: [
          Icon(icon, size: CoeloSize.iconSm, color: foreground),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ),
          if (trailing case final icon?) Icon(icon),
        ],
      ),
    );
  }
}

class _MomentToggleField extends StatefulWidget {
  const _MomentToggleField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_MomentToggleField> createState() => _MomentToggleFieldState();
}

class _MomentToggleFieldState extends State<_MomentToggleField> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onChanged != null;
    final highlighted = enabled && (_hovered || _focused);
    return Semantics(
      container: true,
      label: widget.label,
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
          onExit: enabled ? (_) => setState(() => _hovered = false) : null,
          child: FocusableActionDetector(
            enabled: enabled,
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle())},
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? _toggle : null,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : CoeloMotion.fast,
                constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                decoration: BoxDecoration(
                  color: highlighted
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  border: Border.all(
                    color: highlighted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_outlined, size: CoeloSize.iconSm),
                    const SizedBox(width: CoeloSpacing.space2),
                    Expanded(child: Text(widget.label, style: theme.textTheme.labelSmall)),
                    SizedBox(
                      width: 48,
                      height: 28,
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : CoeloMotion.fast,
                        padding: const EdgeInsets.all(CoeloSpacing.space1),
                        decoration: BoxDecoration(
                          color: widget.value
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(CoeloRadius.full),
                        ),
                        child: AnimatedAlign(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : CoeloMotion.fast,
                          alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: widget.value
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggle() => widget.onChanged?.call(!widget.value);
}

ButtonStyle _discreteActionStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return ButtonStyle(
    alignment: Alignment.centerLeft,
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: CoeloSpacing.space3)),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)
          ? colors.primaryContainer
          : colors.surface,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)
          ? colors.primary
          : colors.onSurface,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.focused) ? colors.primary : colors.outlineVariant,
        width: states.contains(WidgetState.focused) ? 2 : 1,
      ),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
    ),
  );
}

ButtonStyle _negativeIconButtonStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
    foregroundColor: WidgetStatePropertyAll(colors.error),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.errorContainer
          : Colors.transparent,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: const WidgetStatePropertyAll(CircleBorder()),
  );
}

class _MomentPreview extends StatelessWidget {
  const _MomentPreview({required this.draft, required this.context});

  final MomentsDraft draft;
  final MomentsPublicationContext context;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = draft.media.isEmpty ? MomentsMediaDraft.demo(0) : draft.media.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.all_inclusive_rounded, size: CoeloSize.iconSm),
            ),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    this.context.institutionName,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(this.context.unitName, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (draft.caption.isNotEmpty)
          Text(draft.caption, maxLines: 6, overflow: TextOverflow.ellipsis),
        const SizedBox(height: CoeloSpacing.space3),
        AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MomentAsset(media: media, radius: CoeloRadius.md),
              Positioned(
                right: CoeloSpacing.space2,
                top: CoeloSpacing.space2,
                child: _MediaBadge(label: '1/${draft.media.isEmpty ? 1 : draft.media.length}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Row(
          children: [
            Icon(Icons.favorite_rounded, color: theme.colorScheme.primary, size: CoeloSize.iconSm),
            const SizedBox(width: CoeloSpacing.space1),
            const Text('128'),
            const SizedBox(width: CoeloSpacing.space4),
            const Icon(Icons.chat_bubble_outline_rounded, size: CoeloSize.iconSm),
            const SizedBox(width: CoeloSpacing.space1),
            const Text('14'),
            const Spacer(),
            const Icon(Icons.bookmark_border_rounded, size: CoeloSize.iconSm),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Container(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
          ),
          child: const Text('A prévia é uma simulação de como seu post aparecerá em Momentos.'),
        ),
      ],
    );
  }
}

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({
    required this.state,
    required this.onSave,
    required this.onPublish,
    this.maxWidth,
  });

  final MomentsPublicationState state;
  final Future<void> Function() onSave;
  final Future<void> Function() onPublish;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy =
        state.phase == MomentsPublicationPhase.saving ||
        state.phase == MomentsPublicationPhase.publishing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('moments-publication-save'),
                      onPressed: busy ? null : onSave,
                      icon: const Icon(Icons.bookmark_border_rounded),
                      label: Text(
                        state.phase == MomentsPublicationPhase.saving
                            ? 'Salvando…'
                            : 'Salvar rascunho',
                      ),
                    ),
                  ),
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('moments-publication-publish'),
                      onPressed: busy ? null : onPublish,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        state.phase == MomentsPublicationPhase.publishing
                            ? 'Publicando…'
                            : 'Publicar agora',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.onNotifications});

  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    ),
    child: Row(
      children: [
        SvgPicture.asset('assets/brand/logo-coelo-orange.svg', width: 72, semanticsLabel: 'Coelo'),
        const Spacer(),
        IconButton(
          tooltip: 'Notificações',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const CircleAvatar(radius: 18, child: Icon(Icons.person_outline_rounded)),
      ],
    ),
  );
}

class _MobilePageHeader extends StatelessWidget {
  const _MobilePageHeader({required this.onClose, required this.onNotifications});

  final VoidCallback? onClose;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Fechar publicação',
          onPressed: onClose ?? () => Navigator.maybePop(context),
          style: _negativeIconButtonStyle(context),
          icon: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: CoeloSpacing.space1),
        Expanded(
          child: Text(
            'Publicar em Momentos',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Notificações',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const CircleAvatar(radius: 18, child: Icon(Icons.person_outline_rounded)),
      ],
    ),
  );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Fechar publicação',
          onPressed: onClose ?? () => Navigator.maybePop(context),
          style: _negativeIconButtonStyle(context),
          icon: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Text(
            'Publicar em Momentos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.onNotifications});

  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/brand/logo-coelo-orange.svg',
            width: 86,
            semanticsLabel: 'Coelo',
          ),
          const Spacer(),
          const _TopNavItem(label: 'Início'),
          const _TopNavItem(label: 'Agenda'),
          const _TopNavItem(label: 'Mensagens'),
          const _TopNavItem(label: 'Momentos', selected: true),
          const _TopNavItem(label: 'Mais'),
          const Spacer(),
          IconButton(
            tooltip: 'Notificações',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: CoeloSpacing.space2),
          const CircleAvatar(radius: 18, child: Icon(Icons.person_outline_rounded)),
          if (!enlargedText) ...[
            const SizedBox(width: CoeloSpacing.space2),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('Camila Rocha'), Text('Mãe do Lucas')],
            ),
          ],
        ],
      ),
    );
  }
}

class _TopNavItem extends StatelessWidget {
  const _TopNavItem({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: selected ? Border(bottom: BorderSide(color: colors.primary, width: 2)) : null,
      ),
      child: Text(label, style: TextStyle(color: selected ? colors.primary : colors.onSurface)),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail();

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    padding: const EdgeInsets.all(CoeloSpacing.space3),
    decoration: BoxDecoration(
      border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    ),
    child: const Column(
      children: [
        _RailItem(icon: Icons.home_outlined, label: 'Início'),
        _RailItem(icon: Icons.calendar_today_outlined, label: 'Agenda'),
        _RailItem(icon: Icons.chat_bubble_outline_rounded, label: 'Mensagens'),
        _RailItem(icon: Icons.video_library_outlined, label: 'Momentos', selected: true),
        _RailItem(icon: Icons.school_outlined, label: 'Aprendizados'),
        Spacer(),
        _RailItem(icon: Icons.account_balance_outlined, label: 'Colégio Coelo'),
      ],
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.icon, required this.label, this.selected = false});

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Icon(icon, size: CoeloSize.iconSm, color: selected ? colors.primary : null),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: selected ? colors.primary : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on MomentsAudienceKind {
  String get keyName => switch (this) {
    MomentsAudienceKind.families => 'families',
    MomentsAudienceKind.students => 'students',
    MomentsAudienceKind.schoolStaff => 'school-staff',
    MomentsAudienceKind.guardiansOnly => 'guardians-only',
  };

  String get label => switch (this) {
    MomentsAudienceKind.families => 'Famílias',
    MomentsAudienceKind.students => 'Alunos',
    MomentsAudienceKind.schoolStaff => 'Equipe escolar',
    MomentsAudienceKind.guardiansOnly => 'Somente responsáveis',
  };

  IconData get icon => switch (this) {
    MomentsAudienceKind.families => Icons.family_restroom_outlined,
    MomentsAudienceKind.students => Icons.person_outline_rounded,
    MomentsAudienceKind.schoolStaff => Icons.badge_outlined,
    MomentsAudienceKind.guardiansOnly => Icons.supervisor_account_outlined,
  };
}
