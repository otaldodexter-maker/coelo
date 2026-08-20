import 'dart:async';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

final class FormsMonitorPage extends StatefulWidget {
  const FormsMonitorPage({
    required this.api,
    required this.formId,
    this.canListPeople = false,
    this.canReadAnonymousParticipation = false,
    this.canExportAnonymousParticipation = false,
    super.key,
  });

  final FormsApi? api;
  final String formId;
  final bool canListPeople;
  final bool canReadAnonymousParticipation;
  final bool canExportAnonymousParticipation;

  @override
  State<FormsMonitorPage> createState() => _FormsMonitorPageState();
}

final class _FormsMonitorPageState extends State<FormsMonitorPage> {
  final _cursors = <String?>[null];
  FormMonitorProjection? _monitor;
  FormCursorPage<FormMonitorPerson>? _people;
  FormCursorPage<FormMonitorScope>? _hierarchy;
  FormCursorPage<FormMonitorPerson>? _anonymousPeople;
  FormApiException? _failure;
  DateTimeRange? _period;
  String? _scopeId;
  String? _selectedScopeLabel;
  var _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  FormMonitorQuery _query({String? cursor}) => FormMonitorQuery(
    formId: widget.formId,
    startsOnOrAfter: _period?.start,
    endsOnOrBefore: _period?.end,
    scopeId: _scopeId,
    cursor: cursor,
  );

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(
        () => _failure = const FormApiException(
          FormApiFailureKind.unavailable,
          'O serviço de monitoramento não está disponível.',
        ),
      );
      return;
    }
    setState(() {
      _failure = null;
      _monitor = null;
      _people = null;
      _hierarchy = null;
      _anonymousPeople = null;
    });
    try {
      final monitor = await api.getMonitor(_query(cursor: _cursors[_pageIndex]));
      FormCursorPage<FormMonitorPerson>? people;
      final hierarchy = await api.listMonitorHierarchy(_query(cursor: _cursors[_pageIndex]));
      if (widget.canListPeople && !monitor.isAnonymous) {
        people = await api.listMonitorPeople(_query(cursor: _cursors[_pageIndex]));
      }
      if (mounted) {
        setState(() {
          _monitor = monitor;
          _people = people;
          _hierarchy = hierarchy;
        });
      }
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  Future<void> _next() async {
    final cursor = _people?.nextCursor;
    if (cursor == null) return;
    if (_cursors.length == _pageIndex + 1) _cursors.add(cursor);
    _pageIndex++;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return CoeloStatePanel(
        title: failure.kind == FormApiFailureKind.unauthorized
            ? 'Acesso não autorizado'
            : 'Monitoramento indisponível',
        message: failure.message,
        icon: Icons.error_outline_rounded,
        actionLabel: failure.kind == FormApiFailureKind.unauthorized ? null : 'Tentar novamente',
        onAction: failure.kind == FormApiFailureKind.unauthorized ? null : _load,
      );
    }
    final monitor = _monitor;
    if (monitor == null) {
      return const CoeloStatePanel(
        title: 'Carregando monitoramento',
        message: 'Aguarde enquanto os dados autorizados são atualizados.',
        loading: true,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        Text('Monitoramento', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloDateRangeField(
          value: _period,
          onChanged: (value) {
            setState(() {
              _period = value;
              _scopeId = null;
              _selectedScopeLabel = null;
              _pageIndex = 0;
              _cursors
                ..clear()
                ..add(null);
            });
            unawaited(_load());
          },
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 366)),
          selectableDayPredicate: (_) => true,
          currentDate: DateTime.now(),
          enabled: true,
          showQuickRanges: true,
          labelText: 'Período',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 900
                ? (constraints.maxWidth - CoeloSpacing.space4 * 2) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: CoeloSpacing.space4,
              runSpacing: CoeloSpacing.space4,
              children: [
                _metric(context, width, 'Elegíveis', monitor.eligibleCount),
                _metric(context, width, 'Responderam', monitor.respondedCount),
                _metric(context, width, 'Pendentes', monitor.pendingCount),
              ],
            );
          },
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _hierarchyTable(context),
        const SizedBox(height: CoeloSpacing.space5),
        if (monitor.isAnonymous &&
            (widget.canReadAnonymousParticipation || widget.canExportAnonymousParticipation))
          _anonymousOperations(context),
        if (monitor.isAnonymous)
          const CoeloStatePanel(
            title: 'Participação anônima',
            message: 'Este acompanhamento exibe somente dados agregados.',
            icon: Icons.visibility_off_outlined,
          )
        else if (!widget.canListPeople)
          const CoeloStatePanel(
            title: 'Pessoas protegidas',
            message: 'Sua capacidade permite métricas, mas não a lista nominal.',
            icon: Icons.lock_outline_rounded,
          )
        else
          _peopleTable(context),
      ],
    );
  }

  Widget _metric(BuildContext context, double width, String label, int value) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    ),
  );

  Widget _peopleTable(BuildContext context) {
    final people = _people;
    if (people == null || people.items.isEmpty) {
      return const CoeloStatePanel(
        title: 'Nenhuma pessoa neste recorte',
        message: 'Altere o período ou o contexto para consultar outros participantes.',
        icon: Icons.people_outline_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pessoas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space3),
        for (final person in people.items)
          Card(
            child: ListTile(
              title: Text(person.displayName),
              subtitle: Text('${person.profileLabel} · ${person.contextLabel}'),
              trailing: Semantics(
                label: person.responded ? 'Respondeu' : 'Não respondeu',
                child: Chip(label: Text(person.responded ? 'Respondeu' : 'Pendente')),
              ),
            ),
          ),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: CoeloSpacing.space2,
          children: [
            OutlinedButton(
              onPressed: _pageIndex == 0
                  ? null
                  : () {
                      _pageIndex--;
                      unawaited(_load());
                    },
              child: const Text('Página anterior'),
            ),
            FilledButton(
              onPressed: people.nextCursor == null ? null : _next,
              child: const Text('Próxima página'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hierarchyTable(BuildContext context) {
    final hierarchy = _hierarchy;
    if (hierarchy == null || hierarchy.items.isEmpty) {
      return const CoeloStatePanel(
        title: 'Hierarquia',
        message: 'Não há recortes hierárquicos para este período.',
        icon: Icons.account_tree_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Hierarquia', style: Theme.of(context).textTheme.titleLarge)),
            if (_scopeId != null)
              TextButton.icon(
                onPressed: _clearScope,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar ao todo'),
              ),
          ],
        ),
        if (_selectedScopeLabel case final selected?) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Text('Recorte: $selected'),
        ],
        const SizedBox(height: CoeloSpacing.space3),
        for (final scope in hierarchy.items)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
            child: CoeloAdminInteractiveCard(
              onPressed: () => _selectScope(scope),
              semanticLabel: 'Abrir ${_scopeKindLabel(scope.scopeKind)} ${scope.label}',
              child: ListTile(
                title: Text(scope.label),
                subtitle: Text(
                  '${_scopeLabel(scope.scopeKind)} · ${scope.respondedCount}/${scope.eligibleCount} responderam',
                ),
                trailing: Text('${scope.pendingCount} pendentes'),
              ),
            ),
          ),
      ],
    );
  }

  void _selectScope(FormMonitorScope scope) {
    setState(() {
      _scopeId = scope.scopeId;
      _selectedScopeLabel = scope.label;
      _pageIndex = 0;
      _cursors
        ..clear()
        ..add(null);
    });
    unawaited(_load());
  }

  void _clearScope() {
    setState(() {
      _scopeId = null;
      _selectedScopeLabel = null;
      _pageIndex = 0;
      _cursors
        ..clear()
        ..add(null);
    });
    unawaited(_load());
  }

  Widget _anonymousOperations(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          if (widget.canReadAnonymousParticipation)
            OutlinedButton(
              onPressed: () => _requestAnonymousOperation(export: false),
              child: const Text('Consultar participação anônima'),
            ),
          if (widget.canExportAnonymousParticipation)
            FilledButton(
              onPressed: () => _requestAnonymousOperation(export: true),
              child: const Text('Exportar participação anônima'),
            ),
        ],
      ),
      if (_anonymousPeople != null) ...[
        const SizedBox(height: CoeloSpacing.space3),
        for (final person in _anonymousPeople!.items)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
            child: CoeloAdminInteractiveCard(
              semanticLabel:
                  '${person.displayName}, ${person.responded ? 'respondeu' : 'não respondeu'}',
              child: ListTile(
                title: Text(person.displayName),
                subtitle: Text('${person.profileLabel} · ${person.contextLabel}'),
                trailing: Text(person.responded ? 'Respondeu' : 'Não respondeu'),
              ),
            ),
          ),
      ],
    ],
  );

  Future<void> _requestAnonymousOperation({required bool export}) async {
    final controller = TextEditingController();
    String justification = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CoeloAdminDialogShell(
          title: export ? 'Exportar participação anônima' : 'Consultar participação anônima',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Esta operação excepcional será auditada. Informe um motivo para continuar.',
              ),
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                controller: controller,
                labelText: 'Motivo obrigatório',
                prefixIcon: Icons.note_alt_outlined,
                maxLines: 3,
                maxLength: 500,
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          primaryAction: FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () {
                    justification = controller.text.trim();
                    Navigator.pop(dialogContext, true);
                  },
            child: const Text('Continuar'),
          ),
        ),
      ),
    );
    unawaited(Future<void>.delayed(kThemeAnimationDuration, controller.dispose));
    if (confirmed != true || justification.isEmpty || widget.api == null) return;
    try {
      if (export) {
        await widget.api!.requestAnonymousParticipationExport(
          FormCommand(
            requestId: _requestId(),
            expectedVersion: 0,
            payload: FormExportPayload(
              formId: widget.formId,
              kind: FormExportKind.anonymousParticipation,
              justification: justification,
            ),
          ),
        );
      } else {
        final people = await widget.api!.anonymousParticipationLookup(
          FormAnonymousParticipationQuery(formId: widget.formId, justification: justification),
        );
        if (mounted) setState(() => _anonymousPeople = people);
      }
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }
}

String _scopeLabel(FormMonitorScopeKind kind) => _scopeKindLabel(kind);

String _scopeKindLabel(FormMonitorScopeKind kind) => switch (kind) {
  FormMonitorScopeKind.institution => 'Instituição',
  FormMonitorScopeKind.unit => 'Unidade',
  FormMonitorScopeKind.group => 'Turma',
  FormMonitorScopeKind.activity => 'Atividade',
  FormMonitorScopeKind.profile => 'Perfil',
};

String _requestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
