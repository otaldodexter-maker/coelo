import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every useful showroom section to indexed catalog guidance', () {
    const expected = <String, String>{
      'actions': 'pattern.action-hierarchy',
      'forms': 'pattern.form-controls',
      'selection': 'pattern.selection-controls',
      'status': 'pattern.status-feedback',
      'colors': 'foundation.semantic-colors',
      'typography': 'foundation.typography',
      'themes': 'foundation.themes',
    };
    final entries = File('assets/coelo-ui.index.jsonl')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .toList(growable: false);
    final entriesById = {for (final entry in entries) entry.id: entry};
    final foundations = buildCatalogFoundationRegistry();

    expect(showroomContentDestinations, expected);
    for (final destination in expected.values) {
      expect(entriesById, contains(destination), reason: '$destination deve estar no índice.');
      expect(
        foundations,
        contains(destination),
        reason: '$destination deve possuir conteúdo real.',
      );
      expect(
        entriesById[destination]!.category,
        anyOf('foundation', 'pattern'),
        reason: '$destination não deve ser registrado como componente público.',
      );
    }
  });

  test('keeps Astro planned on neutral token foundations only', () {
    final entries = File('assets/coelo-ui.index.jsonl')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .where((entry) => entry.consumers.contains('astro-planned'))
        .toList(growable: false);

    expect(entries.map((entry) => entry.id).toSet(), {
      'foundation.semantic-colors',
      'foundation.typography',
      'foundation.themes',
    });
    expect(entries.every((entry) => entry.category == 'foundation'), isTrue);
    expect(entries.every((entry) => entry.ownerPackage == 'coelo_tokens'), isTrue);
  });

  test('does not advertise disabled for the multiselect public API', () {
    final entries = _entriesById();

    expect(entries['admin.multi-select-filter']!.states, ['closed', 'open', 'focused', 'selected']);
  });

  test('does not advertise an unapproved pressed presentation for create action', () {
    final entries = _entriesById();

    expect(entries['admin.create-action']!.states, ['enabled', 'hovered', 'focused', 'disabled']);
  });

  test('locates public action and overlay tokens by their semantic names', () {
    final entries = _entriesById();

    expect(
      entries['foundation.semantic-colors']!.tokens,
      containsAll(<String>[
        'CoeloActionColors.primaryPressed',
        'CoeloActionColors.actionLink',
        'CoeloActionColors.focusRing',
        'CoeloOverlayColors.scrim',
      ]),
    );
  });
}

Map<String, CatalogEntry> _entriesById() {
  final entries = File('assets/coelo-ui.index.jsonl')
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
  return {for (final entry in entries) entry.id: entry};
}
