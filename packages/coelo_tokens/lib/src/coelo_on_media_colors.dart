import 'package:flutter/material.dart';

/// Cores de texto, ícone e véu desenhados SOBRE mídia (foto, vídeo, capa).
///
/// A mídia não segue o tema: o contraste vem sempre de claro sobre um véu
/// escuro, por isso o mesmo conjunto vale no claro e no escuro.
@immutable
final class CoeloOnMediaColors extends ThemeExtension<CoeloOnMediaColors> {
  const CoeloOnMediaColors({
    required this.foreground,
    required this.foregroundMuted,
    required this.foregroundSubtle,
    required this.scrim,
    required this.scrimStrong,
    required this.scrimSoft,
    required this.backdrop,
  });

  /// Texto e ícone principais sobre mídia.
  final Color foreground;

  /// Carimbos, metadados e dicas.
  final Color foregroundMuted;

  /// Bordas e separadores discretos.
  final Color foregroundSubtle;

  /// Véu médio (fundo de chips e rodapés de card).
  final Color scrim;

  /// Véu forte (fim de gradiente, sombra de texto).
  final Color scrimStrong;

  /// Véu leve (campo de comentário, fundo de botão translúcido).
  final Color scrimSoft;

  /// Fundo atrás da mídia enquanto carrega ou em modo imersivo.
  final Color backdrop;

  static const CoeloOnMediaColors standard = CoeloOnMediaColors(
    foreground: Color(0xFFFFFFFF),
    foregroundMuted: Color(0xB3FFFFFF),
    foregroundSubtle: Color(0x61FFFFFF),
    scrim: Color(0xA3000000),
    scrimStrong: Color(0xDD000000),
    scrimSoft: Color(0x42000000),
    backdrop: Color(0xFF000000),
  );

  @override
  CoeloOnMediaColors copyWith({
    Color? foreground,
    Color? foregroundMuted,
    Color? foregroundSubtle,
    Color? scrim,
    Color? scrimStrong,
    Color? scrimSoft,
    Color? backdrop,
  }) {
    return CoeloOnMediaColors(
      foreground: foreground ?? this.foreground,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      foregroundSubtle: foregroundSubtle ?? this.foregroundSubtle,
      scrim: scrim ?? this.scrim,
      scrimStrong: scrimStrong ?? this.scrimStrong,
      scrimSoft: scrimSoft ?? this.scrimSoft,
      backdrop: backdrop ?? this.backdrop,
    );
  }

  @override
  CoeloOnMediaColors lerp(ThemeExtension<CoeloOnMediaColors>? other, double t) {
    if (other is! CoeloOnMediaColors) return this;
    return CoeloOnMediaColors(
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      foregroundSubtle: Color.lerp(foregroundSubtle, other.foregroundSubtle, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      scrimStrong: Color.lerp(scrimStrong, other.scrimStrong, t)!,
      scrimSoft: Color.lerp(scrimSoft, other.scrimSoft, t)!,
      backdrop: Color.lerp(backdrop, other.backdrop, t)!,
    );
  }
}
