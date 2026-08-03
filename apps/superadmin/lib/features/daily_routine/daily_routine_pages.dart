import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_notice.dart';
import '../../app/shell/superadmin_shell.dart';
import '../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../auth/domain/logout_action.dart';
import 'daily_routine.dart';
import 'daily_routine_feeling_dialogs.dart';
import 'daily_routine_feeling_picker.dart';
import 'daily_routine_feeling_style.dart';

enum _RoutineDisplay { cards, table }

enum _RoutineTableView { grouped }

class DailyRoutineDirectoryPage extends StatefulWidget {
  const DailyRoutineDirectoryPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    this.onCreate,
    this.onEdit,
    this.activityController,
    super.key,
  });

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final SuperadminActivityController? activityController;

  @override
  State<DailyRoutineDirectoryPage> createState() => _DailyRoutineDirectoryPageState();
}

class _DailyRoutineDirectoryPageState extends State<DailyRoutineDirectoryPage> {
  final _search = TextEditingController();
  var _display = _RoutineDisplay.cards;
  var _origin = 'Todas';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final models = widget.repository.models
        .where((model) {
          final matchesSearch = model.name.toLowerCase().contains(query);
          final matchesOrigin =
              _origin == 'Todas' ||
              (_origin == 'Instituição' && model.origin == DailyRoutineOrigin.institution) ||
              (_origin == 'Unidade' && model.origin == DailyRoutineOrigin.unit);
          return matchesSearch && matchesOrigin;
        })
        .toList(growable: false);
    return SuperadminShell(
      logout: widget.logout,
      currentDestination: 'daily-routine',
      title: 'Rotina diária',
      subtitle: 'Modelos, versões e alcances do registro cotidiano.',
      activityController: widget.activityController,
      child: ListView(
        padding: const EdgeInsets.all(CoeloSpacing.space5),
        children: [
          Text('Rotina diária', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            widget.permissions.canManage
                ? 'Crie modelos, versões e alcances para o registro cotidiano.'
                : 'Modo somente leitura',
          ),
          const SizedBox(height: CoeloSpacing.space5),
          CoeloAdminListingToolbar(
            search: SizedBox(
              width: 280,
              child: TextField(
                key: const Key('daily-routine-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar modelos',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            filters: [
              SizedBox(
                width: 168,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _origin,
                  decoration: const InputDecoration(labelText: 'Origem'),
                  items: const ['Todas', 'Instituição', 'Unidade']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _origin = value ?? 'Todas'),
                ),
              ),
            ],
            actions: [
              SuperadminDirectoryViewToggle<_RoutineTableView>(
                cardsSelected: _display == _RoutineDisplay.cards,
                groupedView: _RoutineTableView.grouped,
                selectedTableView: _RoutineTableView.grouped,
                tableViews: const [
                  SuperadminDirectoryTableViewOption(
                    value: _RoutineTableView.grouped,
                    label: 'Tabela',
                  ),
                ],
                cardsKey: const Key('daily-routine-view-cards'),
                tableKey: const Key('daily-routine-view-table'),
                onCardsSelected: () => setState(() => _display = _RoutineDisplay.cards),
                onTableViewSelected: (_) => setState(() => _display = _RoutineDisplay.table),
              ),
              if (widget.permissions.canManage)
                FilledButton.icon(
                  onPressed: widget.onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar modelo de rotina diária'),
                ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space5),
          if (_display == _RoutineDisplay.cards)
            Wrap(
              key: const Key('daily-routine-cards'),
              spacing: CoeloSpacing.space4,
              runSpacing: CoeloSpacing.space4,
              children: models
                  .map(
                    (model) => SizedBox(
                      width: 320,
                      child: Card(
                        child: InkWell(
                          onTap: () => widget.onEdit?.call(model.id),
                          child: Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space4),
                            child: _RoutineSummary(model: model),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            )
          else
            CoeloAdminResizableTable<DailyRoutineModel>(
              key: const Key('daily-routine-table'),
              items: models,
              rowKey: (model) => 'daily-routine-row-${model.id}',
              pinnedColumn: CoeloAdminTableColumn(
                id: 'name',
                label: 'Modelo',
                initialWidth: 260,
                minWidth: 180,
                maxWidth: 420,
                cellBuilder: (_, model) => Text(model.name),
              ),
              columns: [
                CoeloAdminTableColumn(
                  id: 'origin',
                  label: 'Origem',
                  initialWidth: 160,
                  minWidth: 120,
                  maxWidth: 240,
                  cellBuilder: (_, model) => Text(model.origin.label),
                ),
                CoeloAdminTableColumn(
                  id: 'version',
                  label: 'Versão',
                  initialWidth: 120,
                  minWidth: 100,
                  maxWidth: 180,
                  cellBuilder: (_, model) => Text('v${model.version}'),
                ),
              ],
              headerHeight: 56,
              rowHeight: 64,
              onRowPressed: (model) => widget.onEdit?.call(model.id),
            ),
        ],
      ),
    );
  }
}

class _RoutineSummary extends StatelessWidget {
  const _RoutineSummary({required this.model});
  final DailyRoutineModel model;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(model.name, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space2),
      Text(model.description),
      const SizedBox(height: CoeloSpacing.space3),
      Text('${model.origin.label} • v${model.version} • ${model.status.label}'),
      if (model.updateAvailable) const Text('Atualização opcional disponível'),
    ],
  );
}

class DailyRoutineEditorPage extends StatefulWidget {
  const DailyRoutineEditorPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    this.modelId,
    this.activityController,
    super.key,
  });

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;
  final LogoutAction logout;
  final String? modelId;
  final SuperadminActivityController? activityController;

  @override
  State<DailyRoutineEditorPage> createState() => _DailyRoutineEditorPageState();
}

class _DailyRoutineEditorPageState extends State<DailyRoutineEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  final Set<String> _selected = {'participant-1', 'participant-2'};
  var _status = DailyRoutineStatus.draft;
  var _origin = DailyRoutineOrigin.institution;
  var _required = false;
  DailyRoutineFeeling? _bulkFeeling;

  @override
  void initState() {
    super.initState();
    final matches = widget.repository.models.where((model) => model.id == widget.modelId);
    final model = matches.isEmpty ? null : matches.first;
    _name = TextEditingController(text: model?.name ?? 'Nova rotina diária');
    _description = TextEditingController(text: model?.description ?? '');
    _status = model?.status ?? DailyRoutineStatus.draft;
    _origin = model?.origin ?? DailyRoutineOrigin.institution;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _applyBulk() async {
    final bulkFeeling = _bulkFeeling;
    if (!widget.permissions.canManage || _selected.isEmpty || bulkFeeling == null) return;
    final hasExisting = _selected.any(
      (id) => widget.repository.participantValues[id]?.containsKey('mood') ?? false,
    );
    var overwrite = false;
    if (hasExisting && mounted) {
      overwrite =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => CoeloAdminDialogShell(
              title: 'Sobrescrever valores existentes?',
              body: const Text('Exceções serão preservadas se você escolher não sobrescrever.'),
              secondaryAction: OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Preservar'),
              ),
              primaryAction: FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sobrescrever'),
              ),
            ),
          ) ??
          false;
    }
    widget.repository.applyToParticipants(
      _selected,
      fieldId: 'mood',
      value: bulkFeeling.id,
      overwrite: overwrite,
    );
    setState(() {});
  }

  Future<void> _suggestFeeling() async {
    if (!widget.permissions.canManage) return;
    final suggestion = await showDailyRoutineFeelingSuggestionDialog(context);
    if (suggestion == null || !mounted) return;
    widget.repository.suggestFeeling(suggestion);
    showSuperadminNotice(context, 'Sugestão enviada para avaliação.');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'daily-routine',
    title: 'Editor de rotina diária',
    subtitle: 'Configure alcance, seções, campos e a prévia operacional.',
    activityController: widget.activityController,
    child: ListView(
      key: const Key('daily-routine-editor-scroll'),
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        Text('Editor de rotina diária', style: Theme.of(context).textTheme.headlineMedium),
        if (!widget.permissions.canManage) const Text('Modo somente leitura'),
        const SizedBox(height: CoeloSpacing.space4),
        TextField(
          controller: _name,
          enabled: widget.permissions.canManage,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        TextField(
          controller: _description,
          enabled: widget.permissions.canManage,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descrição'),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          spacing: CoeloSpacing.space3,
          children: [
            DropdownButton<DailyRoutineOrigin>(
              value: _origin,
              items: DailyRoutineOrigin.values
                  .map((value) => DropdownMenuItem(value: value, child: Text(value.label)))
                  .toList(growable: false),
              onChanged: widget.permissions.canManage
                  ? (value) => setState(() => _origin = value ?? _origin)
                  : null,
            ),
            DropdownButton<DailyRoutineStatus>(
              value: _status,
              items: DailyRoutineStatus.values
                  .map((value) => DropdownMenuItem(value: value, child: Text(value.label)))
                  .toList(growable: false),
              onChanged: widget.permissions.canManage
                  ? (value) => setState(() => _status = value ?? _status)
                  : null,
            ),
            FilterChip(
              label: const Text('Obrigatório'),
              selected: _required,
              onSelected: widget.permissions.canManage
                  ? (value) => setState(() => _required = value)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Text('Seções e campos', style: Theme.of(context).textTheme.titleLarge),
        const Text('Alcance: Instituição → Unidade → Grupos selecionados → atividade contextual'),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: DailyRoutineFieldType.values
              .map((type) => Chip(label: Text(type.label)))
              .toList(growable: false),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Prévia operacional', style: Theme.of(context).textTheme.titleLarge),
        const Text('Valores iniciais são aplicados apenas a campos ainda não preenchidos.'),
        ...const {
          'participant-1': 'Ana Lima',
          'participant-2': 'Bento Luz',
          'participant-3': 'Clara Sol',
        }.entries.map((entry) {
          final feeling = widget.repository.participantFeeling(entry.key);
          return Card(
            key: Key('daily-routine-participant-${entry.key}-feeling'),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    key: Key('daily-routine-participant-${entry.key}-select'),
                    contentPadding: EdgeInsets.zero,
                    value: _selected.contains(entry.key),
                    onChanged: widget.permissions.canManage
                        ? (value) => setState(
                            () => value == true
                                ? _selected.add(entry.key)
                                : _selected.remove(entry.key),
                          )
                        : null,
                    title: Text(entry.value),
                    subtitle: Text(
                      feeling == null ? 'Não informado' : '${feeling.emoji} ${feeling.label}',
                      style: const TextStyle(fontFamilyFallback: dailyRoutineEmojiFontFallback),
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  Text('Como chegou? (opcional)', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: CoeloSpacing.space2),
                  DailyRoutineFeelingPicker(
                    keyPrefix: 'daily-routine-participant-${entry.key}-feeling',
                    value: feeling,
                    enabled: widget.permissions.canManage,
                    onChanged: (value) {
                      if (value == null) {
                        widget.repository.clearParticipantFeeling(entry.key);
                      } else {
                        widget.repository.setParticipantFeeling(entry.key, value);
                      }
                      setState(() {});
                    },
                    onSuggestFeeling: _suggestFeeling,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: CoeloSpacing.space4),
        Text('Sentimento para o lote', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        DailyRoutineFeelingPicker(
          keyPrefix: 'daily-routine-bulk-feeling',
          value: _bulkFeeling,
          enabled: widget.permissions.canManage,
          onChanged: (value) => setState(() => _bulkFeeling = value),
          onSuggestFeeling: _suggestFeeling,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            OutlinedButton(
              onPressed: widget.permissions.canManage && _selected.isNotEmpty
                  ? () {
                      widget.repository.applyInitialValues('institution-model', _selected);
                      setState(() {});
                    }
                  : null,
              child: const Text('Aplicar valores iniciais'),
            ),
            FilledButton(
              key: const Key('daily-routine-apply-feeling-bulk'),
              onPressed:
                  widget.permissions.canManage && _selected.isNotEmpty && _bulkFeeling != null
                  ? _applyBulk
                  : null,
              child: const Text('Aplicar em lote'),
            ),
            if (widget.permissions.canManage)
              FilledButton.tonal(
                onPressed: () {},
                child: Text(
                  _status == DailyRoutineStatus.draft ? 'Salvar rascunho' : 'Salvar e ativar',
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

extension on DailyRoutineOrigin {
  String get label => switch (this) {
    DailyRoutineOrigin.institution => 'Instituição',
    DailyRoutineOrigin.unit => 'Unidade',
  };
}

extension on DailyRoutineStatus {
  String get label => switch (this) {
    DailyRoutineStatus.draft => 'Rascunho',
    DailyRoutineStatus.active => 'Ativo',
  };
}

extension on DailyRoutineFieldType {
  String get label => switch (this) {
    DailyRoutineFieldType.shortText => 'Texto curto',
    DailyRoutineFieldType.longText => 'Texto longo',
    DailyRoutineFieldType.singleChoice => 'Escolha única',
    DailyRoutineFieldType.multipleChoice => 'Escolha múltipla',
    DailyRoutineFieldType.number => 'Número',
    DailyRoutineFieldType.boolean => 'Sim/Não',
  };
}
