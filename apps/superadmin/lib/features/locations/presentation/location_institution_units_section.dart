import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../units/domain/unit_directory.dart';
import '../../units/presentation/widgets/unit_card.dart';
import '../domain/location_catalog_reader.dart';
import 'location_read_widgets.dart';

/// Grupo "Unidades" do catalogo de Locais de uma instituicao.
///
/// Pendencia aprovada pelo Owner na R03: depois dos locais internos e externos
/// da instituicao, a tela lista as unidades dela em cards, e cada card leva ao
/// catalogo de Locais daquela unidade. O grupo reaproveita o
/// [UnitDirectoryRepository] de Unidades filtrado pela instituicao e o
/// [UnitCard] do diretorio; nao existe conceito novo aqui.
///
/// A sessao e a validade do id sao apenas portao de renderizacao: o servidor
/// reautoriza a leitura das unidades e, depois, a do catalogo da unidade.
final class LocationInstitutionUnitsSection extends StatefulWidget {
  const LocationInstitutionUnitsSection({
    required this.institutionId,
    required this.repository,
    this.onOpen,
    this.sessionAvailable = false,
    this.contextRevision = 0,
    super.key,
  });

  final String institutionId;
  final UnitDirectoryRepository repository;

  /// Recebe o id da unidade cujo catalogo de Locais deve abrir. Nulo deixa os
  /// cards visiveis e inertes, em vez de fingir um destino.
  final ValueChanged<String>? onOpen;
  final bool sessionAvailable;
  final int contextRevision;

  /// Maior pagina que o diretorio de Unidades aceita; a secao nao pagina, e
  /// quando a instituicao passa disso o texto diz o que ficou de fora.
  static const pageSize = 100;

  @override
  State<LocationInstitutionUnitsSection> createState() => _LocationInstitutionUnitsSectionState();
}

/// O grupo mora dentro da `ListView` do diretorio, que descarta filhos fora da
/// janela de rolagem. Sem o keep-alive, cada rolagem ate aqui refaria a
/// consulta e mostraria o carregando de novo.
final class _LocationInstitutionUnitsSectionState extends State<LocationInstitutionUnitsSection>
    with AutomaticKeepAliveClientMixin {
  LocationReadState _state = LocationReadState.unavailable;
  UnitDirectoryPage? _page;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant LocationInstitutionUnitsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.institutionId != widget.institutionId ||
        !identical(oldWidget.repository, widget.repository) ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.contextRevision != widget.contextRevision) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    ++_epoch;
    super.dispose();
  }

  bool _current(int epoch) => mounted && epoch == _epoch;

  Future<void> _load() async {
    final epoch = ++_epoch;
    final repository = widget.repository;
    final institutionId = widget.institutionId;
    setState(() {
      _page = null;
      _state = widget.sessionAvailable && validLocationId(institutionId)
          ? LocationReadState.loading
          : LocationReadState.denied;
    });
    if (_state != LocationReadState.loading) return;
    try {
      final page = await repository.fetchPage(
        UnitDirectoryQuery(
          institutionIds: {institutionId},
          pageSize: LocationInstitutionUnitsSection.pageSize,
        ),
      );
      if (!_current(epoch)) return;
      // Uma unidade de outra instituicao nunca vira card aqui, mesmo que o
      // repositorio ignore o filtro.
      if (page.items.any((item) => item.institutionId != institutionId)) {
        throw const FormatException('Unit outside the institution');
      }
      setState(() {
        _page = page;
        _state = page.items.isEmpty ? LocationReadState.empty : LocationReadState.ready;
      });
    } on UnitDirectoryUnauthorizedException {
      if (!_current(epoch)) return;
      setState(() => _state = LocationReadState.denied);
    } on Object {
      if (!_current(epoch)) return;
      setState(() => _state = LocationReadState.unavailable);
    }
  }

  void _open(UnitDirectoryItem item, int epoch) {
    final onOpen = widget.onOpen;
    if (onOpen == null ||
        !_current(epoch) ||
        !widget.sessionAvailable ||
        _page?.items.contains(item) != true) {
      return;
    }
    onOpen(item.id);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final page = _page;
    final epoch = _epoch;
    return Column(
      key: const Key('location-units-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LocationGroupHeading(
          titleKey: Key('location-group-units'),
          title: 'Unidades',
          description: 'Cada unidade tem o próprio catálogo de locais.',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (_state == LocationReadState.ready && page != null) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              // Mesma grade dos grupos de locais acima, para os tres grupos
              // alinharem coluna a coluna.
              final columns = (constraints.maxWidth / 340).floor().clamp(1, 4);
              final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) / columns;
              return Wrap(
                spacing: CoeloSpacing.space4,
                runSpacing: CoeloSpacing.space4,
                children: [
                  for (final item in page.items)
                    SizedBox(
                      width: width,
                      child: UnitCard(
                        item: item,
                        onPressed: widget.onOpen == null ? null : () => _open(item, epoch),
                      ),
                    ),
                ],
              );
            },
          ),
          if (page.hasNext) ...[
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              'Mostrando ${page.items.length} de ${page.totalCount} unidades. '
              'As demais estão em Unidades.',
              key: const Key('location-units-window'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ] else
          Semantics(
            liveRegion: true,
            label: _state == LocationReadState.loading ? 'Carregando unidades' : null,
            child: CoeloStatePanel(
              key: Key('location-units-${_state.name}'),
              loading: _state == LocationReadState.loading,
              title: switch (_state) {
                LocationReadState.loading => 'Carregando unidades',
                LocationReadState.denied => 'Acesso não autorizado',
                LocationReadState.empty => 'Nenhuma unidade cadastrada',
                _ => 'Não foi possível carregar as unidades',
              },
              message: switch (_state) {
                LocationReadState.loading => 'Aguarde a consulta dos dados autorizados.',
                LocationReadState.denied => 'Você não tem permissão para consultar estes dados.',
                LocationReadState.empty => 'Esta instituição ainda não tem unidades.',
                _ => 'Tente recarregar os dados.',
              },
            ),
          ),
        // Mesmo botao do diretorio de locais acima, para a falha dos dois
        // grupos ter a mesma cara.
        if (_state == LocationReadState.unavailable) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('location-units-reload'),
              onPressed: () => unawaited(_load()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recarregar'),
            ),
          ),
        ],
      ],
    );
  }
}
