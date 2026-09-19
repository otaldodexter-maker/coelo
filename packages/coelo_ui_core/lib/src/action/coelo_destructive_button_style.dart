import 'package:flutter/material.dart';

/// Ação destrutiva confirmada (excluir, revogar, suspender, sair sem salvar):
/// `FilledButton` no vermelho do tema. Ações positivas ficam no `primary`.
ButtonStyle coeloDestructiveFilledButtonStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError);
}
