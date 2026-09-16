import 'package:flutter/material.dart';

import 'coelo_admin_directory.dart';

/// Grade de cards administrativos com **linhas de altura uniforme**, como na
/// referência de Instituições: cada linha é uma `Table` com alinhamento
/// `intrinsicHeight`, então o card mais alto da linha define a altura dos
/// irmãos, inclusive do tile Criar (`leading`).
///
/// `CoeloAdminDirectory` usa esta grade internamente; diretórios que ainda
/// montam a própria toolbar (Rotina diária) a consomem diretamente em vez de
/// reimplementar a grade com `Wrap`, que deixa alturas desiguais.
final class CoeloAdminCardGrid extends StatelessWidget {
  const CoeloAdminCardGrid({
    required this.cards,
    this.leading,
    this.gridKey,
    this.cardMinHeight = CoeloAdminDirectoryMetrics.cardMinHeight,
    super.key,
  });

  /// Tile que antecede os cards (normalmente o Criar). Participa da mesma
  /// linha e recebe a mesma altura.
  final Widget? leading;
  final List<Widget> cards;
  final Key? gridKey;
  final double cardMinHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = CoeloAdminDirectoryMetrics.columns(constraints.maxWidth);
      final children = <Widget>[
        if (leading case final leading?)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: cardMinHeight),
            child: leading,
          ),
        for (final card in cards)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: cardMinHeight),
            child: card,
          ),
      ];
      // Table com alinhamento intrinsicHeight mede os filhos por layout real,
      // o que funciona com cards que usam LayoutBuilder (IntrinsicHeight não
      // suporta esses filhos).
      final width = CoeloAdminDirectoryMetrics.cardWidth(constraints.maxWidth);
      return Column(
        key: gridKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: CoeloAdminDirectoryMetrics.cardGap),
            Table(
              defaultColumnWidth: FixedColumnWidth(width),
              defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
              columnWidths: {
                for (var gap = 1; gap < columns * 2 - 1; gap += 2)
                  gap: const FixedColumnWidth(CoeloAdminDirectoryMetrics.cardGap),
              },
              children: [
                TableRow(
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox.shrink(),
                      start + column < children.length
                          ? _RowStretch(child: children[start + column])
                          : const SizedBox.shrink(),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

/// Estica o card até a altura da linha sem impor altura máxima: o conteúdo
/// que cresce um fio (hover do indicador de status) não estoura o layout.
final class _RowStretch extends StatelessWidget {
  const _RowStretch({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.hasBoundedHeight
        ? OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: constraints.maxHeight,
            maxHeight: double.infinity,
            child: child,
          )
        : child,
  );
}
