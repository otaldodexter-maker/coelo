import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../domain/location_catalog_reader.dart';

String locationKindLabel(LocationKind kind) => switch (kind) {
  LocationKind.internal => 'Interno',
  LocationKind.external => 'Externo',
};
String locationVisibilityLabel(LocationVisibility value) => switch (value) {
  LocationVisibility.team => 'Equipe',
  LocationVisibility.guardians => 'Responsáveis',
  LocationVisibility.students => 'Alunos',
  LocationVisibility.all => 'Todos',
};
String locationStatusLabel(LocationCatalogStatus status) => switch (status) {
  LocationCatalogStatus.active => 'Ativo',
  LocationCatalogStatus.inactive => 'Inativo',
  LocationCatalogStatus.draft => 'Rascunho',
  LocationCatalogStatus.suspended => 'Suspenso',
  LocationCatalogStatus.archived => 'Arquivado',
};
String locationScopeLabel(LocationScope scope) =>
    scope is UnitLocationScope ? 'Catálogo da unidade' : 'Catálogo da instituição';
String locationOptionalText(String? text) => text == null || text.isEmpty ? 'Não informado' : text;

Widget locationStatusIndicator(BuildContext context, LocationCatalogEntry item) {
  final theme = Theme.of(context);
  final colors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  final (background, foreground) = switch (item.status) {
    LocationCatalogStatus.active => (colors.successContainer, colors.onSuccessContainer),
    LocationCatalogStatus.draft => (colors.warningContainer, colors.onWarningContainer),
    LocationCatalogStatus.suspended => (colors.errorContainer, colors.onErrorContainer),
    _ => (theme.colorScheme.surfaceContainer, theme.colorScheme.onSurfaceVariant),
  };
  return CoeloAdminExpandableStatusIndicator(
    key: Key('location-status-${item.id}'),
    label: locationStatusLabel(item.status),
    semanticLabel: 'Status: ${locationStatusLabel(item.status)}',
    backgroundColor: background,
    foregroundColor: foreground,
  );
}

/// Titulo de grupo do diretorio de Locais: "Locais internos da instituicao",
/// "Locais externos" e, na instituicao, "Unidades". Vive aqui para os tres
/// grupos terem a mesma anatomia (titulo `titleMedium` w700 e descricao
/// `bodySmall` em `onSurfaceVariant`), como o Owner pediu em 10/09/2026.
class LocationGroupHeading extends StatelessWidget {
  const LocationGroupHeading({
    required this.title,
    required this.description,
    this.titleKey,
    super.key,
  });

  final String title;
  final String description;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: titleKey,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class LocationReadStatePanel extends StatelessWidget {
  const LocationReadStatePanel({required this.state, required this.prefix, super.key});
  final LocationReadState state;
  final String prefix;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: state == LocationReadState.loading ? 'Carregando locais' : null,
    child: CoeloStatePanel(
      key: Key('$prefix-${state.name}'),
      loading: state == LocationReadState.loading,
      title: switch (state) {
        LocationReadState.loading => 'Carregando locais',
        LocationReadState.denied => 'Acesso não autorizado',
        LocationReadState.empty => 'Nenhum local encontrado',
        LocationReadState.noResults => 'Nenhum resultado para a busca',
        _ => 'Não foi possível carregar os locais',
      },
      message: switch (state) {
        LocationReadState.loading => 'Aguarde a consulta dos dados autorizados.',
        LocationReadState.denied => 'Você não tem permissão para consultar estes dados.',
        LocationReadState.empty => 'Nenhum local foi retornado para este catálogo.',
        LocationReadState.noResults => 'Revise o termo informado para buscar novamente.',
        _ => 'Tente recarregar os dados.',
      },
    ),
  );
}

Widget locationTextSection(BuildContext context, String title, Map<String, String> fields) => Card(
  margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
  child: Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: CoeloSpacing.space4),
        for (final entry in fields.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: CoeloSpacing.space1),
                SelectableText(entry.value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
      ],
    ),
  ),
);
