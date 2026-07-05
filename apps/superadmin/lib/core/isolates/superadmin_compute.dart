import 'package:flutter/foundation.dart';

Future<R> runSuperadminComputation<Q, R>({
  required String debugLabel,
  required ComputeCallback<Q, R> task,
  required Q message,
}) {
  assert(debugLabel.trim().isNotEmpty, 'debugLabel must describe the computation.');

  return compute<Q, R>(task, message, debugLabel: debugLabel);
}
