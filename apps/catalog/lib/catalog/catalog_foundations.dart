import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';
import 'chat_catalog_foundations.dart';
import 'error_page_catalog_foundation.dart';
import 'surface_interaction_catalog_foundations.dart';

const showroomContentDestinations = <String, String>{
  'actions': 'pattern.action-hierarchy',
  'forms': 'pattern.form-controls',
  'selection': 'pattern.selection-controls',
  'status': 'pattern.status-feedback',
  'colors': 'foundation.semantic-colors',
  'typography': 'foundation.typography',
  'themes': 'foundation.themes',
};

Map<String, CatalogFoundation> buildCatalogFoundationRegistry() {
  return {
    'pattern.action-hierarchy': CatalogFoundation(
      id: 'pattern.action-hierarchy',
      referencedComponentIds: const ['admin.create-action'],
      builder: (_) => const _ActionHierarchyFoundation(),
    ),
    'pattern.form-controls': CatalogFoundation(
      id: 'pattern.form-controls',
      referencedComponentIds: const ['core.form-text-field', 'core.search-field'],
      builder: (_) => const _FormControlsFoundation(),
    ),
    'pattern.selection-controls': CatalogFoundation(
      id: 'pattern.selection-controls',
      referencedComponentIds: const ['admin.single-select-field', 'admin.multi-select-filter'],
      builder: (_) => const _SelectionControlsFoundation(),
    ),
    'pattern.status-feedback': CatalogFoundation(
      id: 'pattern.status-feedback',
      referencedComponentIds: const ['core.status-chip', 'core.state-panel'],
      builder: (_) => const _StatusFeedbackFoundation(),
    ),
    'foundation.semantic-colors': CatalogFoundation(
      id: 'foundation.semantic-colors',
      builder: (_) => const _SemanticColorsFoundation(),
    ),
    'foundation.typography': CatalogFoundation(
      id: 'foundation.typography',
      builder: (_) => const _TypographyFoundation(),
    ),
    'foundation.themes': CatalogFoundation(
      id: 'foundation.themes',
      builder: (_) => const _ThemesFoundation(),
    ),
    ...buildErrorPageFoundationRegistry(),
    ...buildChatFoundationRegistry(),
    ...buildSurfaceInteractionFoundationRegistry(),
  };
}

final class _ActionHierarchyFoundation extends StatefulWidget {
  const _ActionHierarchyFoundation();

  @override
  State<_ActionHierarchyFoundation> createState() => _ActionHierarchyFoundationState();
}

final class _ActionHierarchyFoundationState extends State<_ActionHierarchyFoundation> {
  var _activations = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Use uma ação primária por contexto. Ações secundárias e links devem '
          'preservar sua hierarquia sem competir visualmente.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        SizedBox(
          width: double.infinity,
          child: CoeloAdminCreateAction(
            key: const Key('foundation-real-admin-create-action'),
            label: 'Criar instituição',
            onPressed: () => setState(() => _activations++),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text('Ativações no exemplo: $_activations'),
      ],
    );
  }
}

final class _FormControlsFoundation extends StatefulWidget {
  const _FormControlsFoundation();

  @override
  State<_FormControlsFoundation> createState() => _FormControlsFoundationState();
}

final class _FormControlsFoundationState extends State<_FormControlsFoundation> {
  final _controller = TextEditingController();
  final _secondaryController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cadastro, edição e autenticação usam o mesmo campo-base com label '
          'persistente, ícone, hint, hover, foco, erro e autofill.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        DecoratedBox(
          key: const Key('foundation-form-neutral-surface'),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Instituição', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space2),
                const Text(
                  'Instituições é a referência canônica; autenticação define o campo-base.',
                ),
                const SizedBox(height: CoeloSpacing.space5),
                LayoutBuilder(
                  key: const Key('foundation-form-responsive-grid'),
                  builder: (context, constraints) {
                    final fields = [
                      CoeloFormTextField(
                        key: const Key('foundation-real-core-form-text-field'),
                        controller: _controller,
                        labelText: 'Nome público',
                        hintText: 'Como a instituição aparece no Coelo',
                        prefixIcon: Icons.apartment_rounded,
                      ),
                      CoeloFormTextField(
                        controller: _secondaryController,
                        labelText: '@ da instituição',
                        hintText: 'instituicao',
                        prefixIcon: Icons.alternate_email_rounded,
                      ),
                    ];
                    if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
                      return Column(
                        children: [
                          fields.first,
                          const SizedBox(height: CoeloSpacing.space4),
                          fields.last,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fields.first),
                        const SizedBox(width: CoeloSpacing.space3),
                        Expanded(child: fields.last),
                      ],
                    );
                  },
                ),
                const SizedBox(height: CoeloSpacing.space5),
                const Text('Verificar 375, 768, 1024 e 1440 px, light/dark e texto a 200%.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        DecoratedBox(
          key: const Key('foundation-form-action-footer'),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () {}, child: const Text('Sair sem salvar')),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: FilledButton(onPressed: () {}, child: const Text('Continuar editando')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _SelectionControlsFoundation extends StatefulWidget {
  const _SelectionControlsFoundation();

  @override
  State<_SelectionControlsFoundation> createState() => _SelectionControlsFoundationState();
}

final class _SelectionControlsFoundationState extends State<_SelectionControlsFoundation> {
  Set<String> _selected = const {'Ativa'};
  var _single = 'Rascunho';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleção precisa declarar se é única ou múltipla, quando aplica a '
          'mudança e como representa selecionado, indisponível e vazio.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<String>(
          label: 'Status operacional',
          value: _single,
          options: const ['Rascunho', 'Em implantação', 'Ativa'],
          optionLabel: (value) => value,
          onChanged: (value) => setState(() => _single = value),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        SizedBox(
          width: double.infinity,
          child: CoeloAdminMultiSelectFilter<String>(
            key: const Key('foundation-real-admin-multi-select-filter'),
            label: 'Status',
            options: const ['Ativa', 'Em análise', 'Inativa'],
            selectedValues: _selected,
            optionLabel: (value) => value,
            onChanged: (value) => setState(() => _selected = value),
            searchHintText: 'Buscar status',
          ),
        ),
      ],
    );
  }
}

final class _StatusFeedbackFoundation extends StatelessWidget {
  const _StatusFeedbackFoundation();

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<CoeloStatusColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status compacto identifica um estado. Painéis comunicam vazio, '
          'loading, bloqueio ou erro da superfície. Feedback local e transitório '
          'continua pertencendo à composição consumidora.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloStatusChip(
          key: const Key('foundation-real-core-status-chip'),
          label: 'Ativa',
          backgroundColor: status.successContainer,
          foregroundColor: status.onSuccessContainer,
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        const CoeloStatePanel(
          key: Key('foundation-real-core-state-panel'),
          title: 'Sem resultados',
          message: 'Ajuste os filtros para tentar novamente.',
          icon: Icons.search_off_outlined,
        ),
      ],
    );
  }
}

final class _SemanticColorsFoundation extends StatelessWidget {
  const _SemanticColorsFoundation();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<CoeloStatusColors>()!;
    final samples = [
      (name: 'Primary', token: 'color.action.primary', color: colors.primary, on: colors.onPrimary),
      (name: 'Surface', token: 'color.surface', color: colors.surface, on: colors.onSurface),
      (
        name: 'Subtle',
        token: 'color.surface.subtle',
        color: colors.surfaceContainer,
        on: colors.onSurface,
      ),
      (
        name: 'Success',
        token: 'success.container',
        color: status.successContainer,
        on: status.onSuccessContainer,
      ),
      (
        name: 'Warning',
        token: 'warning.container',
        color: status.warningContainer,
        on: status.onWarningContainer,
      ),
      (
        name: 'Info',
        token: 'info.container',
        color: status.infoContainer,
        on: status.onInfoContainer,
      ),
    ];
    return Wrap(
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space3,
      children: [
        for (final sample in samples)
          _TokenSwatch(
            name: sample.name,
            token: sample.token,
            color: sample.color,
            foreground: sample.on,
          ),
      ],
    );
  }
}

final class _TokenSwatch extends StatelessWidget {
  const _TokenSwatch({
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: CoeloSize.touchMin * 3,
        maxWidth: CoeloBreakpoints.compact.maxWidth,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: Key('foundation-color-$token'),
                height: CoeloSpacing.space12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(CoeloRadius.xs),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground),
                ),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(token),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TypographyFoundation extends StatelessWidget {
  const _TypographyFoundation();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final samples = [
      (name: 'headlineLarge', text: 'Cuidado com clareza', style: textTheme.headlineLarge),
      (
        name: 'titleMedium',
        text: 'Contexto ativo e permissão visível',
        style: textTheme.titleMedium,
      ),
      (
        name: 'bodyLarge',
        text: 'Texto principal com leitura confortável em rotinas operacionais.',
        style: textTheme.bodyLarge,
      ),
      (name: 'labelLarge', text: 'Publicar comunicado', style: textTheme.labelLarge),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nunito Sans usa uma hierarquia curta e sem estilos locais concorrentes.'),
        const SizedBox(height: CoeloSpacing.space4),
        for (final sample in samples) ...[
          Text(sample.name, style: textTheme.labelMedium),
          const SizedBox(height: CoeloSpacing.space1),
          Text(sample.text, style: sample.style),
          const Divider(height: CoeloSpacing.space8),
        ],
      ],
    );
  }
}

final class _ThemesFoundation extends StatefulWidget {
  const _ThemesFoundation();

  @override
  State<_ThemesFoundation> createState() => _ThemesFoundationState();
}

final class _ThemesFoundationState extends State<_ThemesFoundation> {
  var _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    final previewTheme = _mode == ThemeMode.light ? CoeloTheme.light : CoeloTheme.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Light e dark compartilham papéis semânticos. Troque o tema para '
          'validar contraste e hierarquia; não copie cores físicas entre modos.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        SegmentedButton<ThemeMode>(
          key: const Key('foundation-theme-toggle'),
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.single),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Theme(
          data: previewTheme,
          child: Builder(
            builder: (context) => Card(
              key: const Key('foundation-theme-preview'),
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mode == ThemeMode.light ? 'Tema claro' : 'Tema escuro',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: CoeloSpacing.space2),
                    Text(
                      'Superfície e texto vêm do tema Coelo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
