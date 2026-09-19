import 'package:flutter/material.dart';

/// Razão de contraste WCAG entre duas cores (1 a 21).
double coeloContrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final high = a > b ? a : b;
  final low = a > b ? b : a;
  return (high + 0.05) / (low + 0.05);
}

/// Texto/ícone sobre uma cor livre (escolhida pelo usuário, marca, avatar):
/// branco ou preto, o que contrastar mais. Cor de tema usa `onPrimary` etc.;
/// este helper é só para cor que o tema não conhece.
Color coeloOnColor(Color background) =>
    coeloContrastRatio(background, Colors.white) >= coeloContrastRatio(background, Colors.black)
    ? Colors.white
    : Colors.black;
