part of 'principal_moments_publication_page.dart';

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
            LayoutBuilder(
              builder: (context, constraints) {
                final stackHeader =
                    MediaQuery.textScalerOf(context).scale(1) > 1.3 || constraints.maxWidth < 320;
                final title = Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                );
                if (trailing == null) return title;
                if (stackHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: CoeloSpacing.space1),
                      trailing!,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    trailing!,
                  ],
                );
              },
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
    required this.currentStep,
    required this.onCancel,
    required this.onPrevious,
    required this.onContinue,
    required this.onSave,
    required this.onPublish,
  });

  final MomentsPublicationState state;
  final int currentStep;
  final VoidCallback onCancel;
  final VoidCallback onPrevious;
  final VoidCallback onContinue;
  final Future<void> Function() onSave;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    final busy =
        state.phase == MomentsPublicationPhase.saving ||
        state.phase == MomentsPublicationPhase.publishing;
    return SuperadminFormActionFooter(
      surfaceKey: const Key('moments-publication-footer-surface'),
      tertiaryAction: TextButton(
        key: const Key('moments-publication-cancel'),
        onPressed: busy ? null : onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (currentStep > 0)
          OutlinedButton(
            key: const Key('moments-publication-previous'),
            onPressed: busy ? null : onPrevious,
            child: const Text('Anterior'),
          ),
        OutlinedButton.icon(
          key: const Key('moments-publication-save'),
          onPressed: busy ? null : onSave,
          icon: const Icon(Icons.bookmark_border_rounded),
          label: Text(
            state.phase == MomentsPublicationPhase.saving ? 'Salvando…' : 'Salvar rascunho',
          ),
        ),
        if (currentStep == 2)
          FilledButton.icon(
            key: const Key('moments-publication-publish'),
            onPressed: busy ? null : onPublish,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              state.phase == MomentsPublicationPhase.publishing ? 'Publicando…' : 'Publicar agora',
            ),
          )
        else
          FilledButton(
            key: const Key('moments-publication-continue'),
            onPressed: busy ? null : onContinue,
            child: const Text('Continuar'),
          ),
      ],
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
