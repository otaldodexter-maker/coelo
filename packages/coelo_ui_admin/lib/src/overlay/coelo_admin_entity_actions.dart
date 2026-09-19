import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'coelo_admin_flyout.dart';

/// Ícones canônicos das ações de ciclo de vida nos ⋯ de cards e tabelas.
/// Toda tela usa estes (via [CoeloAdminEntityActions]) para o mesmo verbo
/// ter sempre o mesmo ícone e tom.
abstract final class CoeloAdminActionIcons {
  static const view = Icons.visibility_outlined;
  static const edit = Icons.edit_outlined;
  static const duplicate = Icons.content_copy_rounded;
  static const publish = Icons.publish_outlined;
  static const activate = Icons.play_circle_outline_rounded;
  static const inactivate = Icons.pause_circle_outline_rounded;
  static const restore = Icons.restore_rounded;
  static const archive = Icons.archive_outlined;
  static const cancel = Icons.block_rounded;
  static const delete = Icons.delete_outline_rounded;
}

/// Itens prontos para o ⋯ de uma entidade. Ordem canônica do menu:
/// ver → editar → duplicar → transições (publicar, ativar/inativar, restaurar)
/// → grupo negativo (arquivar, cancelar/revogar, excluir), que abre com
/// `startsGroup` no primeiro item negativo.
abstract final class CoeloAdminEntityActions {
  static CoeloAdminFlyoutItem<T> view<T>(T value, {String label = 'Ver detalhes'}) =>
      CoeloAdminFlyoutItem(value: value, label: label, icon: CoeloAdminActionIcons.view);

  static CoeloAdminFlyoutItem<T> edit<T>(T value, {String label = 'Editar'}) =>
      CoeloAdminFlyoutItem(value: value, label: label, icon: CoeloAdminActionIcons.edit);

  static CoeloAdminFlyoutItem<T> duplicate<T>(T value, {String label = 'Duplicar'}) =>
      CoeloAdminFlyoutItem(value: value, label: label, icon: CoeloAdminActionIcons.duplicate);

  static CoeloAdminFlyoutItem<T> publish<T>(T value, {String label = 'Publicar'}) =>
      CoeloAdminFlyoutItem(value: value, label: label, icon: CoeloAdminActionIcons.publish);

  static CoeloAdminFlyoutItem<T> activate<T>(T value, {String label = 'Ativar'}) =>
      CoeloAdminFlyoutItem(value: value, label: label, icon: CoeloAdminActionIcons.activate);

  static CoeloAdminFlyoutItem<T> inactivate<T>(T value, {String label = 'Inativar'}) =>
      CoeloAdminFlyoutItem(value: value, label: label, icon: CoeloAdminActionIcons.inactivate);

  static CoeloAdminFlyoutItem<T> restore<T>(
    T value, {
    String label = 'Restaurar',
    bool startsGroup = false,
  }) => CoeloAdminFlyoutItem(
    value: value,
    label: label,
    icon: CoeloAdminActionIcons.restore,
    startsGroup: startsGroup,
  );

  static CoeloAdminFlyoutItem<T> archive<T>(
    T value, {
    String label = 'Arquivar',
    bool startsGroup = true,
  }) => CoeloAdminFlyoutItem(
    value: value,
    label: label,
    icon: CoeloAdminActionIcons.archive,
    startsGroup: startsGroup,
    tone: CoeloAdminFlyoutTone.negative,
  );

  static CoeloAdminFlyoutItem<T> cancel<T>(
    T value, {
    String label = 'Cancelar',
    bool startsGroup = true,
  }) => CoeloAdminFlyoutItem(
    value: value,
    label: label,
    icon: CoeloAdminActionIcons.cancel,
    startsGroup: startsGroup,
    tone: CoeloAdminFlyoutTone.negative,
  );

  static CoeloAdminFlyoutItem<T> delete<T>(
    T value, {
    String label = 'Excluir',
    bool startsGroup = false,
  }) => CoeloAdminFlyoutItem(
    value: value,
    label: label,
    icon: CoeloAdminActionIcons.delete,
    startsGroup: startsGroup,
    tone: CoeloAdminFlyoutTone.negative,
  );
}

/// Botão ⋯ que abre o [CoeloAdminFlyout] de uma entidade (card ou linha):
/// `more_horiz`, ícone pequeno, alvo de toque de 48 px, spinner quando ocupado.
final class CoeloAdminEntityActionsTrigger extends StatelessWidget {
  const CoeloAdminEntityActionsTrigger({
    super.key,
    required this.controller,
    required this.tooltip,
    this.busy = false,
    this.enabled = true,
  });

  final MenuController controller;
  final String tooltip;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: !enabled || busy
        ? null
        : () => controller.isOpen ? controller.close() : controller.open(),
    iconSize: CoeloSize.iconSm,
    style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.square(CoeloSize.touchMin))),
    icon: busy
        ? const SizedBox.square(
            dimension: CoeloSize.iconSm,
            child: Padding(
              padding: EdgeInsets.all(CoeloSpacing.space1),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : const Icon(Icons.more_horiz_rounded),
  );
}
