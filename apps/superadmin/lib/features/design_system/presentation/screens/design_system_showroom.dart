import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/superadmin_app_config.dart';

class DesignSystemShowroom extends StatelessWidget {
  const DesignSystemShowroom({super.key, required this.themeModeController});

  final ValueNotifier<ThemeMode> themeModeController;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isWide = width >= CoeloBreakpoints.expanded.minWidth;
          final horizontalPadding = _horizontalPaddingFor(width);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              CoeloSpacing.space6,
              horizontalPadding,
              CoeloSpacing.space10,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShowroomHeader(isWide: isWide, themeModeController: themeModeController),
                    const SizedBox(height: CoeloSpacing.space10),
                    const _SectionHeading(
                      title: 'Componentes basicos',
                      subtitle: 'Acoes, campos, selecao e estados com tokens Coelo.',
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _ResponsiveGrid(
                      minItemWidth: 320,
                      spacing: CoeloSpacing.space4,
                      children: [
                        _ShowroomPanel(
                          title: 'Acoes',
                          icon: Icons.touch_app_outlined,
                          child: const _ActionSamples(),
                        ),
                        _ShowroomPanel(
                          title: 'Formulario',
                          icon: Icons.edit_note_outlined,
                          child: const _FormSamples(),
                        ),
                        _ShowroomPanel(
                          title: 'Selecao',
                          icon: Icons.segment_outlined,
                          child: const _SelectionSamples(),
                        ),
                        _ShowroomPanel(
                          title: 'Estados',
                          icon: Icons.verified_outlined,
                          child: _StatusSamples(),
                        ),
                      ],
                    ),
                    const SizedBox(height: CoeloSpacing.space10),
                    const _SectionHeading(
                      title: 'Cores semanticas',
                      subtitle: 'Papeis de tema, superficies e status sem depender de HEX local.',
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _ColorSamples(),
                    const SizedBox(height: CoeloSpacing.space10),
                    const _SectionHeading(
                      title: 'Tipografia',
                      subtitle: 'Nunito Sans com hierarquia curta para telas operacionais.',
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    const _TypographySamples(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _horizontalPaddingFor(double width) {
    if (width >= CoeloBreakpoints.large.minWidth) {
      return CoeloBreakpoints.large.margin;
    }
    if (width >= CoeloBreakpoints.expanded.minWidth) {
      return CoeloBreakpoints.expanded.margin;
    }
    if (width >= CoeloBreakpoints.medium.minWidth) {
      return CoeloBreakpoints.medium.margin;
    }
    return CoeloBreakpoints.compact.margin;
  }
}

class _ShowroomHeader extends StatelessWidget {
  const _ShowroomHeader({required this.isWide, required this.themeModeController});

  final bool isWide;
  final ValueNotifier<ThemeMode> themeModeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SuperadminAppConfig.appSubtitle,
          style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          SuperadminAppConfig.appName,
          style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text('Showroom do Design System', style: theme.textTheme.headlineLarge),
        const SizedBox(height: CoeloSpacing.space3),
        Text(
          'Uma tela generica para sentir cores, tipografia, superficies, estados e controles.',
          style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: CoeloSpacing.space6),
          _ThemeModeButton(themeModeController: themeModeController),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleBlock,
        const SizedBox(height: CoeloSpacing.space5),
        _ThemeModeButton(themeModeController: themeModeController),
      ],
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton({required this.themeModeController});

  final ValueNotifier<ThemeMode> themeModeController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeController,
      builder: (context, mode, child) {
        final isDark = mode == ThemeMode.dark;

        return FilledButton.icon(
          key: const ValueKey('theme-mode-toggle'),
          onPressed: () {
            themeModeController.value = isDark ? ThemeMode.light : ThemeMode.dark;
          },
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          label: Text(isDark ? 'Usar light mode' : 'Usar dark mode'),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space1),
        Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    required this.minItemWidth,
    required this.spacing,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth).floor().clamp(1, 3);
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: itemWidth, child: child)],
        );
      },
    );
  }
}

class _ShowroomPanel extends StatelessWidget {
  const _ShowroomPanel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space5),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActionSamples extends StatelessWidget {
  const _ActionSamples();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Salvar'),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Convidar'),
        ),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.open_in_new_outlined),
          label: const Text('Ver detalhes'),
        ),
        Tooltip(
          message: 'Notificacoes',
          child: IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ),
      ],
    );
  }
}

class _FormSamples extends StatelessWidget {
  const _FormSamples();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      decoration: InputDecoration(
        labelText: 'Campo de exemplo',
        hintText: 'Nome da instituicao',
        helperText: 'Texto de apoio',
        prefixIcon: const Icon(Icons.school_outlined),
        filled: true,
        fillColor: colors.surfaceContainer,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(CoeloRadius.sm)),
      ),
    );
  }
}

class _SelectionSamples extends StatelessWidget {
  const _SelectionSamples();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        ChoiceChip(
          selected: true,
          avatar: const Icon(Icons.check, size: CoeloSize.iconSm),
          label: const Text('Ativo'),
          onSelected: (_) {},
        ),
        FilterChip(
          selected: false,
          avatar: const Icon(Icons.schedule_outlined, size: CoeloSize.iconSm),
          label: const Text('Pendente'),
          onSelected: (_) {},
        ),
        InputChip(
          avatar: const Icon(Icons.lock_outline, size: CoeloSize.iconSm),
          label: const Text('Restrito'),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _StatusSamples extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<CoeloStatusColors>() ?? CoeloStatusColors.light;

    return Column(
      children: [
        _StatusBanner(
          title: 'Sucesso',
          body: 'Rotina publicada para 4 turmas.',
          icon: Icons.check_circle_outline,
          background: status.successContainer,
          foreground: status.onSuccessContainer,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _StatusBanner(
          title: 'Aviso',
          body: '3 responsaveis ainda nao confirmaram.',
          icon: Icons.warning_amber_outlined,
          background: status.warningContainer,
          foreground: status.onWarningContainer,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _StatusBanner(
          title: 'Informacao',
          body: 'A leitura ficara registrada no historico.',
          icon: Icons.info_outline,
          background: status.infoContainer,
          foreground: status.onInfoContainer,
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.title,
    required this.body,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CoeloRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.labelLarge?.copyWith(color: foreground)),
                  const SizedBox(height: CoeloSpacing.spaceHalf),
                  Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSamples extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<CoeloStatusColors>() ?? CoeloStatusColors.light;

    return _ResponsiveGrid(
      minItemWidth: 176,
      spacing: CoeloSpacing.space3,
      children: [
        _ColorSwatch(
          name: 'Primary',
          token: 'color.action.primary',
          color: colors.primary,
          foreground: colors.onPrimary,
        ),
        _ColorSwatch(
          name: 'Surface',
          token: 'color.surface',
          color: colors.surface,
          foreground: colors.onSurface,
        ),
        _ColorSwatch(
          name: 'Subtle',
          token: 'color.surface.subtle',
          color: colors.surfaceContainer,
          foreground: colors.onSurface,
        ),
        _ColorSwatch(
          name: 'Success',
          token: 'success.container',
          color: status.successContainer,
          foreground: status.onSuccessContainer,
        ),
        _ColorSwatch(
          name: 'Warning',
          token: 'warning.container',
          color: status.warningContainer,
          foreground: status.onWarningContainer,
        ),
        _ColorSwatch(
          name: 'Info',
          token: 'info.container',
          color: status.infoContainer,
          foreground: status.onInfoContainer,
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.name,
    required this.token,
    required this.color,
    required this.foreground,
  });

  final String name;
  final String token;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: CoeloSpacing.space12,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(CoeloRadius.xs),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                    child: Text(
                      name,
                      style: theme.textTheme.labelLarge?.copyWith(color: foreground),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(token, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TypographySamples extends StatelessWidget {
  const _TypographySamples();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeSample(
              name: 'Headline large',
              sample: 'Cuidado com clareza',
              style: theme.textTheme.headlineLarge,
            ),
            const Divider(height: CoeloSpacing.space8),
            _TypeSample(
              name: 'Title medium',
              sample: 'Contexto ativo e permissao visivel',
              style: theme.textTheme.titleMedium,
            ),
            const Divider(height: CoeloSpacing.space8),
            _TypeSample(
              name: 'Body large',
              sample: 'Texto principal com leitura confortavel em rotinas operacionais.',
              style: theme.textTheme.bodyLarge,
            ),
            const Divider(height: CoeloSpacing.space8),
            _TypeSample(
              name: 'Label large',
              sample: 'Publicar comunicado',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSample extends StatelessWidget {
  const _TypeSample({required this.name, required this.sample, required this.style});

  final String name;
  final String sample;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: CoeloSpacing.space2),
        Text(sample, style: style),
      ],
    );
  }
}
