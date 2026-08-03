import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/fake_plan_catalog_repository.dart';
import '../domain/plan_catalog.dart';

final class PlanFormPage extends StatefulWidget {
  const PlanFormPage({
    required this.repository,
    this.planId,
    this.onSaved,
    this.onCancel,
    super.key,
  });

  final FakePlanCatalogRepository repository;
  final String? planId;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  @override
  State<PlanFormPage> createState() => _PlanFormPageState();
}

final class _PlanFormPageState extends State<PlanFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _code;

  @override
  void initState() {
    super.initState();
    final plan = widget.planId == null ? null : widget.repository.findById(widget.planId!);
    _name = TextEditingController(text: plan?.name ?? 'Novo plano');
    _code = TextEditingController(text: plan?.code ?? 'novo-plano');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _save() {
    final existing = widget.planId == null ? null : widget.repository.findById(widget.planId!);
    if (existing == null) {
      widget.repository.create(
        PlanDraft(
          id: _code.text,
          name: _name.text,
          code: _code.text,
          description: 'Plano operacional fake.',
          status: PlanStatus.active,
          features: const {PlanFeature.communication, PlanFeature.agenda},
          unitLimit: 2,
          userLimit: 500,
          guardiansPerChild: 2,
          storageGb: 25,
          mediaGb: 5,
          manualOperation: false,
          internalNotes: '',
        ),
      );
    } else {
      widget.repository.update(
        PlanCatalog(
          id: existing.id,
          name: _name.text,
          code: _code.text,
          description: existing.description,
          status: existing.status,
          features: existing.features,
          unitLimit: existing.unitLimit,
          userLimit: existing.userLimit,
          guardiansPerChild: existing.guardiansPerChild,
          storageGb: existing.storageGb,
          mediaGb: existing.mediaGb,
          manualOperation: existing.manualOperation,
          internalNotes: existing.internalNotes,
          usedByInstitutionCount: existing.usedByInstitutionCount,
        ),
      );
    }
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(CoeloSpacing.space6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.planId == null ? 'Novo plano' : 'Editar plano',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: CoeloSpacing.space5),
          CoeloFormTextField(
            controller: _name,
            labelText: 'Nome do plano',
            prefixIcon: Icons.loyalty_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(controller: _code, labelText: 'Código', prefixIcon: Icons.tag_rounded),
          const SizedBox(height: CoeloSpacing.space6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: CoeloSpacing.space3,
            children: [
              OutlinedButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
              FilledButton(onPressed: _save, child: const Text('Salvar plano')),
            ],
          ),
        ],
      ),
    ),
  );
}
