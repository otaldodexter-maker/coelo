import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/entity_lifecycle.dart';
import 'entity_lifecycle_menu.dart';

/// Executa uma ação do [EntityLifecycleMenu] para unidade/turma: pede o motivo
/// quando restritiva, chama o comando, dá feedback e recarrega pela [reload].
/// Conflito de versão também recarrega (o instantâneo local está velho).
Future<void> runEntityLifecycle(
  BuildContext context, {
  required EntityLifecycleCommands commands,
  required String keyPrefix,
  required String entityLabel,
  required String entityId,
  required String entityName,
  required int managementVersion,
  required EntityLifecycleAction action,
  required Future<void> Function() reload,
  ValueChanged<String>? onEdit,
}) async {
  if (action == EntityLifecycleAction.edit) {
    onEdit?.call(entityId);
    return;
  }
  String? reason;
  if (action != EntityLifecycleAction.activate) {
    reason = await showEntityLifecycleReasonDialog(
      context,
      keyPrefix: keyPrefix,
      action: action,
      entityLabel: entityLabel,
      entityName: entityName,
    );
    if (reason == null || !context.mounted) return;
  }
  final messenger = ScaffoldMessenger.of(context);
  void feedback(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  final capitalized = entityLabel[0].toUpperCase() + entityLabel.substring(1);
  try {
    final result = switch (action) {
      EntityLifecycleAction.activate => await commands.changeStatus(
        entityId,
        expectedVersion: managementVersion,
        active: true,
        requestId: entityLifecycleRequestId(),
      ),
      EntityLifecycleAction.inactivate => await commands.changeStatus(
        entityId,
        expectedVersion: managementVersion,
        active: false,
        requestId: entityLifecycleRequestId(),
        reason: reason,
      ),
      EntityLifecycleAction.delete => await commands.delete(
        entityId,
        expectedVersion: managementVersion,
        requestId: entityLifecycleRequestId(),
        reason: reason!,
      ),
      EntityLifecycleAction.edit => throw StateError('unreachable'),
    };
    feedback(switch (action) {
      EntityLifecycleAction.activate => '$capitalized $entityName ativada.',
      EntityLifecycleAction.inactivate => '$capitalized $entityName inativada.',
      EntityLifecycleAction.delete =>
        result.hardDeleted
            ? '$capitalized $entityName excluída.'
            : '$capitalized $entityName arquivada: tinha vínculos, então ficou no histórico.',
      EntityLifecycleAction.edit => '',
    });
  } on EntityLifecycleConflictException {
    feedback('$capitalized alterada por outra pessoa. A lista foi recarregada.');
  } on EntityLifecycleValidationException catch (error) {
    feedback(error.message);
  } on EntityLifecycleUnauthorizedException {
    feedback('Você não tem permissão para alterar esta $entityLabel.');
  } on Object {
    feedback('Não foi possível concluir a operação.');
  }
  await reload();
}

/// UUID v4 para comandos idempotentes disparados pela tela.
String entityLifecycleRequestId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
