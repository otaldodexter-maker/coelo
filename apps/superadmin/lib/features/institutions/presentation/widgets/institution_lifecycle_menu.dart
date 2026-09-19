import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/entity_lifecycle_menu.dart';
import '../../domain/institution_directory_item.dart';

export '../../../../shared/presentation/widgets/entity_lifecycle_menu.dart'
    show EntityLifecycleAction;

typedef InstitutionLifecycleAction = EntityLifecycleAction;

/// Ações de ciclo de vida da instituição (spec 066): ⋯ no card e na tabela.
/// Só oferece o que o status atual permite; a decisão final é do servidor.
final class InstitutionLifecycleMenu extends StatelessWidget {
  const InstitutionLifecycleMenu({
    super.key,
    required this.item,
    required this.onSelected,
    this.canEdit = false,
  });

  final InstitutionDirectoryItem item;
  final bool canEdit;
  final ValueChanged<EntityLifecycleAction> onSelected;

  @override
  Widget build(BuildContext context) => EntityLifecycleMenu(
    keyPrefix: 'institution',
    entityId: item.id,
    entityLabel: 'instituição',
    state: switch (item.status) {
      InstitutionStatus.active => EntityLifecycleState.active,
      InstitutionStatus.inactive => EntityLifecycleState.inactive,
      InstitutionStatus.archived => EntityLifecycleState.archived,
      _ => EntityLifecycleState.other,
    },
    canEdit: canEdit,
    onSelected: onSelected,
  );
}

/// Motivo obrigatório para transições restritivas (spec 066 §4).
Future<String?> showInstitutionLifecycleReasonDialog(
  BuildContext context, {
  required EntityLifecycleAction action,
  required InstitutionDirectoryItem item,
}) => showEntityLifecycleReasonDialog(
  context,
  keyPrefix: 'institution',
  action: action,
  entityLabel: 'instituição',
  entityName: item.publicName,
);
