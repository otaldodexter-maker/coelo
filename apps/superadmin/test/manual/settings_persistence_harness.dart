// Local browser-only harness. Never use this entrypoint for a deployment.
// Synthetic authorization isolates device preferences from production Auth.
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SuperadminSession()..signInForTesting();
  runApp(SuperadminApp(session: session));
}
