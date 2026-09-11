import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PrincipalPublicationStepStatus { current, complete, error, incomplete }

final class PrincipalPublicationStep {
  const PrincipalPublicationStep({
    required this.label,
    required this.status,
    this.enabled = true,
    this.key,
  });

  final String label;
  final PrincipalPublicationStepStatus status;
  final bool enabled;
  final Key? key;
}

/// Domain-neutral Principal composer frame. It mirrors the approved form
/// geometry without importing administrative components into Principal.
final class PrincipalPublicationFrame extends StatelessWidget {
  const PrincipalPublicationFrame({
    required this.navigation,
    required this.body,
    required this.footer,
    this.bodyMaxWidth = 880,
    this.scrollKey,
    super.key,
  });

  final Widget navigation;
  final Widget body;
  final Widget footer;
  final double bodyMaxWidth;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showRail = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
      final inset = showRail && constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth
          ? CoeloSpacing.space10
          : showRail
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      final content = Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: scrollKey,
                padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: bodyMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!showRail) ...[navigation, const SizedBox(height: CoeloSpacing.space4)],
                        body,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            footer,
          ],
        ),
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showRail) ...[navigation, const SizedBox(width: CoeloSpacing.space6)],
            content,
          ],
        ),
      );
    },
  );
}

final class PrincipalPublicationStepNavigation extends StatelessWidget {
  const PrincipalPublicationStepNavigation({
    required this.steps,
    required this.currentIndex,
    required this.onStepSelected,
    super.key,
  }) : assert(steps.length > 1),
       assert(currentIndex >= 0 && currentIndex < steps.length);

  final List<PrincipalPublicationStep> steps;
  final int currentIndex;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
        ? SizedBox(
            width: 248,
            child: SingleChildScrollView(
              key: const Key('principal-publication-steps-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < steps.length; index++) _button(context, index),
                ],
              ),
            ),
          )
        : _compactSummary(context),
  );

  Widget _compactSummary(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = steps[currentIndex];
    return Semantics(
      key: const Key('principal-publication-step-summary'),
      container: true,
      selected: true,
      label:
          'Etapa ${currentIndex + 1} de ${steps.length}. ${step.label}, ${_statusLabel(step.status)}',
      child: Container(
        constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space3,
          vertical: CoeloSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.radio_button_checked_rounded, color: colors.primary),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etapa ${currentIndex + 1} de ${steps.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  Text(step.label, style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(BuildContext context, int index) {
    final step = steps[index];
    final colors = Theme.of(context).colorScheme;
    final current = step.status == PrincipalPublicationStepStatus.current;
    final icon = switch (step.status) {
      PrincipalPublicationStepStatus.current => Icons.radio_button_checked_rounded,
      PrincipalPublicationStepStatus.complete => Icons.check_circle_outline_rounded,
      PrincipalPublicationStepStatus.error => Icons.error_outline_rounded,
      PrincipalPublicationStepStatus.incomplete => Icons.radio_button_unchecked_rounded,
    };
    return Semantics(
      button: true,
      selected: current,
      enabled: step.enabled,
      label: '${step.label}, ${_statusLabel(step.status)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
        child: TextButton.icon(
          key: step.key,
          onPressed: step.enabled ? () => onStepSelected(index) : null,
          style:
              TextButton.styleFrom(
                minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
              ).copyWith(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      current ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primary
                      : step.status == PrincipalPublicationStepStatus.error
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      current ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primaryContainer
                      : Colors.transparent,
                ),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          icon: Icon(icon),
          label: Text(step.label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  String _statusLabel(PrincipalPublicationStepStatus status) => switch (status) {
    PrincipalPublicationStepStatus.current => 'selecionada',
    PrincipalPublicationStepStatus.complete => 'completa',
    PrincipalPublicationStepStatus.error => 'com erro',
    PrincipalPublicationStepStatus.incomplete => 'incompleta',
  };
}

final class PrincipalPublicationActionFooter extends StatelessWidget {
  const PrincipalPublicationActionFooter({
    required this.tertiaryAction,
    required this.continuationActions,
    this.surfaceKey,
    super.key,
  }) : assert(continuationActions.length > 0);

  final Widget tertiaryAction;
  final List<Widget> continuationActions;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Familia Publicacao (Owner, 11/09/2026 17:19): rodape em card contornado
    // dentro do conteiner, sem desfoque.
    return Container(
      key: surfaceKey,
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < CoeloBreakpoints.medium.minWidth + CoeloSpacing.space16 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            if (compact) {
              final actions = [...continuationActions.reversed, tertiaryAction];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    SizedBox(width: double.infinity, child: actions[index]),
                    if (index < actions.length - 1) const SizedBox(height: CoeloSpacing.space2),
                  ],
                ],
              );
            }
            // Cancelar a esquerda, rascunho e primaria a direita; se nao
            // couber numa linha, o grupo da direita desce sem estourar.
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: CoeloSpacing.space2,
              children: [
                tertiaryAction,
                Wrap(
                  spacing: CoeloSpacing.space2,
                  runSpacing: CoeloSpacing.space2,
                  children: continuationActions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Familia Publicacao (decisao do Owner, 11/09/2026 17:19): titulo
/// "Sua publicacao", subtitulo "Publicar no/em ...", corpo em uma coluna
/// (midia primeiro, depois blocos em cards), previa a direita no desktop e
/// rodape em card. Sem etapas, sem wizard, sem fundo cinza.
final class PrincipalPublicationSheet extends StatelessWidget {
  const PrincipalPublicationSheet({
    required this.subtitle,
    required this.body,
    required this.footer,
    this.title = 'Sua publicação',
    this.aside,
    this.asideKey,
    this.asideWidth = 360,
    this.scrollKey,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget? aside;
  final Key? asideKey;
  final double asideWidth;
  final Widget footer;
  final Key? scrollKey;

  static const double asideBreakpoint = 1024;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textTheme = Theme.of(context).textTheme;
      final wide = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
      final showAside =
          aside != null &&
          constraints.maxWidth >= asideBreakpoint &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.5;
      final inset = wide ? CoeloSpacing.space6 : CoeloSpacing.space4;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            key: const Key('principal-publication-title'),
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            subtitle,
            key: const Key('principal-publication-subtitle'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          if (showAside)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: body),
                const SizedBox(width: CoeloSpacing.space6),
                SizedBox(key: asideKey, width: asideWidth, child: aside),
              ],
            )
          else
            body,
        ],
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: scrollKey,
                padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                child: content,
              ),
            ),
            footer,
          ],
        ),
      );
    },
  );
}

/// Bloco da familia Publicacao: rotulo acima e conteudo em card contornado
/// (`neutral200`, raio 12).
final class PrincipalPublicationBlock extends StatelessWidget {
  const PrincipalPublicationBlock({
    required this.child,
    this.label,
    this.trailing,
    this.padding = const EdgeInsets.all(CoeloSpacing.space4),
    this.blockKey,
    super.key,
  });

  final String? label;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Key? blockKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Expanded(child: Text(label!, style: Theme.of(context).textTheme.labelLarge)),
              ?trailing,
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
        ],
        Container(
          key: blockKey,
          padding: padding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Nota em `orange50` com icone (regra da tela: 24 horas do Agora, contexto de
/// Momentos, simulacao da previa).
final class PrincipalPublicationNote extends StatelessWidget {
  const PrincipalPublicationNote({
    required this.text,
    this.icon = Icons.info_outline_rounded,
    super.key,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space3,
        vertical: CoeloSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: CoeloSize.iconSm, color: colors.primary),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

final class PrincipalPublicationToggleField extends StatefulWidget {
  const PrincipalPublicationToggleField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<PrincipalPublicationToggleField> createState() => _PrincipalPublicationToggleFieldState();
}

final class _PrincipalPublicationToggleFieldState extends State<PrincipalPublicationToggleField> {
  bool highlighted = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null;
    return Semantics(
      container: true,
      label: widget.label,
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: enabled ? (_) => setState(() => highlighted = true) : null,
          onExit: enabled ? (_) => setState(() => highlighted = false) : null,
          child: FocusableActionDetector(
            enabled: enabled,
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onChanged?.call(!widget.value);
                  return null;
                },
              ),
            },
            onShowFocusHighlight: (value) => setState(() => highlighted = value),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : CoeloMotion.fast,
                constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space3,
                  vertical: CoeloSpacing.space2,
                ),
                decoration: BoxDecoration(
                  color: highlighted ? colors.primaryContainer : colors.surface,
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.label),
                          if (widget.description case final description?) ...[
                            const SizedBox(height: CoeloSpacing.space1),
                            Text(
                              description,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                    // The row is one control: the detector above carries the
                    // semantics, the shortcuts and the activation. Left
                    // focusable, the Switch adds a second Tab stop under
                    // ExcludeSemantics — it toggles, but with no semantic node,
                    // so the keyboard reads as intermittent: one Tab highlights
                    // and does nothing, two Tabs work.
                    ExcludeFocus(
                      child: Switch(
                        value: widget.value,
                        onChanged: widget.onChanged,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
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
}
