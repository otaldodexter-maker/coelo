import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'superadmin_form_action_footer.dart';

/// Família visual Publicação (decisão do Owner de 11/09/2026, telas aprovadas
/// às 17:19 no canvas "Publicar no Coelo"; referência em
/// `docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/`
/// e anatomia em `coelo-ui/references/principal-visual-surfaces.md`).
///
/// Vale para Circulares, Eventos da Agenda, Agora, Acontece, Momentos e
/// Lançar chamada. O conceito vive uma vez aqui: título "Sua publicação" com
/// o subtítulo da ação, conteúdo em uma coluna (prévia à direita a partir de
/// 1200 px), rodapé em card com Cancelar à esquerda e as ações à direita
/// (empilhadas no mobile, primária primeiro). Sem wizard, sem fundo cinza,
/// sem balão de chat (o hospedeiro desliga o launcher).
final class PublicationSurface extends StatelessWidget {
  const PublicationSurface({
    required this.subtitle,
    required this.form,
    required this.tertiaryAction,
    required this.continuationActions,
    this.preview,
    this.feedback,
    this.scrollKey,
    this.footerKey,
    this.previewMinimumWidth = 1200,
    this.padding = const EdgeInsets.symmetric(horizontal: CoeloSpacing.space6),
    super.key,
  });

  /// "Publicar Circular", "Publicar Evento"…
  final String subtitle;
  final Widget form;
  final Widget? preview;
  final Widget? feedback;
  final Widget tertiaryAction;
  final List<Widget> continuationActions;
  final Key? scrollKey;
  final Key? footerKey;
  final double previewMinimumWidth;

  /// Respiro lateral dentro do conteiner do hospedeiro.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePreview = preview != null && constraints.maxWidth >= previewMinimumWidth;
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sua publicação',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                subtitle,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: CoeloSpacing.space5),
            ],
          );
          final content = SingleChildScrollView(
            key: scrollKey,
            padding: padding.add(const EdgeInsets.only(bottom: CoeloSpacing.space10)),
            child: sidePreview
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: form),
                          const SizedBox(width: CoeloSpacing.space6),
                          SizedBox(width: 388, child: preview),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header, form],
                  ),
          );
          return Column(
            children: [
              Expanded(child: content),
              ?feedback,
              Padding(
                padding: padding.add(const EdgeInsets.only(top: CoeloSpacing.space3)),
                child: SuperadminFormActionFooter(
                  surfaceKey: footerKey,
                  inlineMinimumWidth: 840,
                  tertiaryAction: tertiaryAction,
                  continuationActions: continuationActions,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rótulo de bloco ("Título", "Anexos até 4 · PDF ou imagem").
final class PublicationLabel extends StatelessWidget {
  const PublicationLabel(this.text, {this.hint, super.key});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space2, top: CoeloSpacing.space4),
      child: Text.rich(
        TextSpan(
          text: text,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          children: [
            if (hint != null)
              TextSpan(
                text: '  $hint',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto da família: rótulo acima ([PublicationLabel]), sem ícone de
/// prefixo, contador `n/limite` no canto inferior direito.
final class PublicationTextField extends StatelessWidget {
  const PublicationTextField({
    required this.controller,
    this.fieldKey,
    this.hintText,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
    super.key,
  });
  final TextEditingController controller;
  final Key? fieldKey;
  final String? hintText;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.all(CoeloSpacing.space3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
      ),
    );
  }
}

/// Card contornado (`neutral200`, raio 12) que envolve um bloco.
final class PublicationCard extends StatelessWidget {
  const PublicationCard({
    required this.child,
    this.padding = const EdgeInsets.all(CoeloSpacing.space4),
    this.onTap,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    );
    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    // Container por fora (a borda precisa pintar acima do fundo da superficie)
    // e Material transparente por dentro para o ripple do InkWell.
    return Container(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Linha "ícone · rótulo/linhas · trailing" dentro de um [PublicationCard]
/// (Público e contexto, Local, Agendamento).
final class PublicationRow extends StatelessWidget {
  const PublicationRow({
    required this.icon,
    required this.title,
    this.lines = const [],
    this.trailing,
    this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final List<String> lines;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return PublicationCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: CoeloSize.iconMd),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                for (final line in lines)
                  Text(
                    line,
                    style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          ?trailing,
          if (trailing == null && onTap != null)
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Chip selecionável da família (ativo em `orange50` com borda laranja).
final class PublicationChip extends StatelessWidget {
  const PublicationChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon = Icons.group_outlined,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space3,
              vertical: CoeloSpacing.space2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: CoeloSize.iconSm, color: foreground),
                const SizedBox(width: CoeloSpacing.space1),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha "ícone · rótulo · Switch" (Salvar como rascunho, Lembrar 1 dia antes).
final class PublicationToggleRow extends StatelessWidget {
  const PublicationToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurfaceVariant, size: CoeloSize.iconMd),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(child: Text(label)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Nota em `orange50` (regra da publicação, "A prévia é uma simulação…").
final class PublicationNote extends StatelessWidget {
  const PublicationNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: CoeloSize.iconSm, color: colors.primary),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coluna "Prévia …" do web (título + card do conteúdo como aparecerá).
final class PublicationPreviewPanel extends StatelessWidget {
  const PublicationPreviewPanel({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => PublicationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(
              Icons.info_outline_rounded,
              size: CoeloSize.iconSm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        child,
      ],
    ),
  );
}
