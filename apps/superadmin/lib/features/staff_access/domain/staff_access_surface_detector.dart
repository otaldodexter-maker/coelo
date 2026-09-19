import 'package:flutter/foundation.dart';

/// Superfície declarada ao servidor no header `x-coelo-surface` (ADR 0035,
/// decisão 4). O servidor não consegue verificar a superfície real: aplica a
/// regra à superfície declarada e usa `web` quando nada é declarado. Largura
/// e user agent são a melhor pista disponível no web; o app instalado
/// (Etapa 4) declarará `installed_app` por conta própria.
String detectStaffAccessSurface({
  required double logicalWidth,
  required String userAgent,
  bool isWeb = kIsWeb,
}) {
  if (!isWeb) return 'installed_app';
  final agent = userAgent.toLowerCase();
  final mobileAgent = agent.contains('mobile') || agent.contains('android') || agent.contains('iphone');
  final tabletAgent = agent.contains('ipad') || agent.contains('tablet');
  if (tabletAgent || (logicalWidth >= 600 && logicalWidth < 1024 && mobileAgent)) return 'tablet_web';
  if (mobileAgent || logicalWidth < 600) return 'mobile_web';
  return 'web';
}
