import 'dart:convert';
import 'dart:io';
Future<void> main(List<String> a) async { final ws = await WebSocket.connect(a[0]); ws.add(jsonEncode({'id': 1, 'method': 'Browser.close'})); await Future<void>.delayed(const Duration(seconds: 1)); await ws.close(); print('Browser.close enviado'); }
