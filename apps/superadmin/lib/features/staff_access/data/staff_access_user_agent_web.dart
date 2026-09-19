// Só no Flutter web: user agent para a superfície declarada (x-coelo-surface).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String get staffAccessUserAgent => html.window.navigator.userAgent;
