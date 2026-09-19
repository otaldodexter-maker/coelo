import 'package:flutter/material.dart';

import 'coelo_status_colors.dart';
import 'coelo_theme.dart';

/// Atalhos para as extensões de tema do Coelo.
///
/// `context.coeloScrim` no lugar de
/// `Theme.of(context).extension<CoeloOverlayColors>()!.scrim`.
extension CoeloThemeContext on BuildContext {
  ThemeData get _theme => Theme.of(this);

  /// Véu dos diálogos e flyouts (`CoeloOverlayColors.scrim`); fora do tema
  /// Coelo (testes) cai no véu padrão do Material.
  Color get coeloScrim =>
      _theme.extension<CoeloOverlayColors>()?.scrim ??
      _theme.dialogTheme.barrierColor ??
      Colors.black54;

  /// Cores de status; cai no conjunto claro/escuro quando o tema não registra a extensão.
  CoeloStatusColors get coeloStatusColors =>
      _theme.extension<CoeloStatusColors>() ??
      (_theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);

  CoeloActionColors get coeloActionColors => _theme.extension<CoeloActionColors>()!;

  CoeloVisualColors get coeloVisualColors => _theme.extension<CoeloVisualColors>()!;
}
