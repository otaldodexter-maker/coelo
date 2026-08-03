import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/fake_plan_catalog_repository.dart';
import '../domain/plan_catalog.dart';

final class PlanDirectoryPage extends StatefulWidget {
  const PlanDirectoryPage({required this.repository, this.onCreate, this.onEdit, super.key});

  final FakePlanCatalogRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;

  @override
  State<PlanDirectoryPage> createState() => _PlanDirectoryPageState();
}

final class _PlanDirectoryPageState extends State<PlanDirectoryPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = widget.repository.query(search: _search.text);
    return Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloAdminListingToolbar(
            search: CoeloSearchField(
              controller: _search,
              semanticLabel: 'Buscar planos',
              hintText: 'Buscar por nome ou código',
              onChanged: (_) => setState(() {}),
            ),
            filters: const [],
            actions: [
              FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Novo plano'),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space5),
          Expanded(
            child: plans.isEmpty
                ? const Center(child: Text('Nenhum plano encontrado. Ajuste a busca.'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 700
                          ? 2
                          : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: CoeloSpacing.space4,
                          mainAxisSpacing: CoeloSpacing.space4,
                          childAspectRatio: columns == 1 ? 2.4 : 1.45,
                        ),
                        itemCount: plans.length,
                        itemBuilder: (context, index) {
                          final plan = plans[index];
                          return CoeloAdminInteractiveCard(
                            semanticLabel: 'Editar plano ${plan.name}',
                            onPressed: () => widget.onEdit?.call(plan.id),
                            child: Padding(
                              padding: const EdgeInsets.all(CoeloSpacing.space4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
                                  Text(plan.code),
                                  const Spacer(),
                                  Text(
                                    '${plan.features.length} módulos · ${plan.userLimit} usuários',
                                  ),
                                  Text(plan.status == PlanStatus.active ? 'Ativo' : 'Arquivado'),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
