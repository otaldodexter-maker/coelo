import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/fake_import_repository.dart';
import '../domain/import_job.dart';

final class ImportDirectoryPage extends StatefulWidget {
  const ImportDirectoryPage({required this.repository, required this.onNewImport, super.key});
  final FakeImportRepository repository;
  final VoidCallback onNewImport;
  @override
  State<ImportDirectoryPage> createState() => _ImportDirectoryPageState();
}

final class _ImportDirectoryPageState extends State<ImportDirectoryPage> {
  final _search = TextEditingController();
  bool _table = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final jobs = widget.repository.jobs
          .where(
            (job) =>
                job.entity.label.toLowerCase().contains(_search.text.toLowerCase()) ||
                job.file.fileName.contains(_search.text.toLowerCase()),
          )
          .toList();
      return Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Importações', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              'Histórico local de arquivos demonstrativos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloAdminListingToolbar(
              search: SizedBox(
                width: 280,
                child: CoeloSearchField(
                  controller: _search,
                  semanticLabel: 'Buscar importações',
                  hintText: 'Buscar importação',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              filters: const [],
              actions: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.grid_view_rounded),
                      label: Text('Cards'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.table_rows_rounded),
                      label: Text('Tabela'),
                    ),
                  ],
                  selected: {_table},
                  onSelectionChanged: (value) => setState(() => _table = value.first),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Expanded(
              child: jobs.isEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CoeloAdminCreateAction(
                          label: 'Nova importação',
                          description: 'Escolha entidade e arquivo',
                          onPressed: widget.onNewImport,
                        ),
                        const SizedBox(height: CoeloSpacing.space4),
                        const Expanded(
                          child: CoeloStatePanel(
                            title: 'Sem importações',
                            message: 'Inicie uma nova importação local.',
                            icon: Icons.upload_file_outlined,
                          ),
                        ),
                      ],
                    )
                  : _table
                  ? _ImportTable(jobs: jobs, onNew: widget.onNewImport)
                  : _ImportCards(
                      jobs: jobs,
                      onNew: widget.onNewImport,
                      compact: constraints.maxWidth < CoeloBreakpoints.medium.minWidth,
                    ),
            ),
          ],
        ),
      );
    },
  );
}

final class _ImportCards extends StatelessWidget {
  const _ImportCards({required this.jobs, required this.onNew, required this.compact});
  final List<ImportJob> jobs;
  final VoidCallback onNew;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      if (!compact)
        Wrap(
          spacing: CoeloSpacing.space6,
          runSpacing: CoeloSpacing.space6,
          children: [
            SizedBox(
              width: 340,
              height: 216,
              child: CoeloAdminCreateAction(
                label: 'Nova importação',
                description: 'Escolha entidade e arquivo',
                onPressed: onNew,
              ),
            ),
            ...jobs.map((job) => SizedBox(width: 340, child: _JobCard(job: job))),
          ],
        )
      else ...[
        CoeloAdminCreateAction(
          label: 'Nova importação',
          description: 'Escolha entidade e arquivo',
          onPressed: onNew,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        ...jobs.map(
          (job) => Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
            child: _JobCard(job: job),
          ),
        ),
      ],
    ],
  );
}

final class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});
  final ImportJob job;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CoeloAdminInteractiveCard(
      minHeight: 160,
      semanticLabel: 'Importação ${job.entity.label}',
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.entity.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space2),
            Text(job.file.fileName),
            Text('Destino: ${job.context}'),
            const Spacer(),
            LinearProgressIndicator(value: job.progress / 100),
            const SizedBox(height: CoeloSpacing.space2),
            CoeloStatusChip(
              label:
                  '${job.progress}% · ${job.status == ImportJobStatus.completed ? 'Concluída' : 'Em andamento'}',
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

final class _ImportTable extends StatelessWidget {
  const _ImportTable({required this.jobs, required this.onNew});
  final List<ImportJob> jobs;
  final VoidCallback onNew;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      CoeloAdminCreateAction(
        label: 'Iniciar nova importação',
        description: 'Escolha entidade e arquivo',
        variant: CoeloAdminCreateActionVariant.banner,
        onPressed: onNew,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      ...jobs.map(
        (job) => ListTile(
          title: Text(job.entity.label),
          subtitle: Text('${job.file.fileName} · ${job.context}'),
          trailing: Text('${job.progress}%'),
        ),
      ),
    ],
  );
}
