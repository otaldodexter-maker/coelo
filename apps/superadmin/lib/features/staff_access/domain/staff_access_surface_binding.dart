import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/staff_access_user_agent.dart';
import 'staff_access_surface_detector.dart';

/// Mantém o header `x-coelo-surface` coerente com a janela: recalcula ao
/// redimensionar (debounce) e grava em `client.rest.headers` — nunca em
/// `Supabase.initialize(headers:)`, que derrubaria o preflight das Edges.
final class StaffAccessSurfaceObserver with WidgetsBindingObserver {
  StaffAccessSurfaceObserver({
    required this.headers,
    this.debounce = const Duration(milliseconds: 300),
    String? userAgent,
    this.isWeb = kIsWeb,
  }) : _userAgent = userAgent ?? staffAccessUserAgent;

  final Map<String, String> headers;
  final Duration debounce;
  final String _userAgent;
  final bool isWeb;
  Timer? _timer;

  /// Calcula agora e passa a observar mudanças de métrica.
  void bind() {
    apply();
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  double get _logicalWidth {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    return view == null ? 1440.0 : view.physicalSize.width / view.devicePixelRatio;
  }

  /// Recalcula e grava o header (idempotente).
  String apply() {
    final surface = detectStaffAccessSurface(logicalWidth: _logicalWidth, userAgent: _userAgent, isWeb: isWeb);
    headers['x-coelo-surface'] = surface;
    return surface;
  }

  @override
  void didChangeMetrics() {
    _timer?.cancel();
    _timer = Timer(debounce, apply);
  }
}
