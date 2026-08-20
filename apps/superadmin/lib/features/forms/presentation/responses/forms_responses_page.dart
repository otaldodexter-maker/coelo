import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

final class FormsResponsesPage extends StatefulWidget {
  const FormsResponsesPage({required this.api, required this.formId, this.onOpenDetail, super.key});

  final FormsApi? api;
  final String formId;
  final ValueChanged<FormResponseSummary>? onOpenDetail;

  @override
  State<FormsResponsesPage> createState() => _FormsResponsesPageState();
}

final class _FormsResponsesPageState extends State<FormsResponsesPage> {
  final _cursors = <String?>[null];
  FormCursorPage<FormResponseSummary>? _page;
  FormApiException? _failure;
  var _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(
        () => _failure = const FormApiException(
          FormApiFailureKind.unavailable,
          'O serviço de respostas não está disponível.',
        ),
      );
      return;
    }
    setState(() {
      _page = null;
      _failure = null;
    });
    try {
      final page = await api.listResponses(
        FormResponsesQuery(formId: widget.formId, cursor: _cursors[_pageIndex]),
      );
      if (mounted) setState(() => _page = page);
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  Future<void> _showDetail(FormResponseSummary summary) async {
    final onOpenDetail = widget.onOpenDetail;
    if (onOpenDetail != null) {
      onOpenDetail(summary);
      return;
    }
    final api = widget.api!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => FutureBuilder<FormResponseDetail>(
        future: api.getResponseDetail(summary.id),
        builder: (context, snapshot) => AlertDialog(
          title: Text(summary.respondentLabel ?? 'Resposta anônima'),
          content: SizedBox(
            width: 560,
            child: snapshot.hasError
                ? const CoeloStatePanel(
                    title: 'Detalhe indisponível',
                    message: 'Não foi possível carregar esta resposta.',
                    icon: Icons.error_outline_rounded,
                  )
                : snapshot.data == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final answer in snapshot.data!.answers.values)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Item ${answer.itemId}'),
                          subtitle: Text(_answerText(answer)),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return CoeloStatePanel(
        title: failure.kind == FormApiFailureKind.unauthorized
            ? 'Acesso não autorizado'
            : 'Respostas indisponíveis',
        message: failure.message,
        icon: Icons.error_outline_rounded,
        actionLabel: failure.kind == FormApiFailureKind.unauthorized ? null : 'Tentar novamente',
        onAction: failure.kind == FormApiFailureKind.unauthorized ? null : _load,
      );
    }
    final page = _page;
    if (page == null) {
      return const CoeloStatePanel(
        title: 'Carregando respostas',
        message: 'Aguarde enquanto as submissões autorizadas são carregadas.',
        loading: true,
      );
    }
    if (page.items.isEmpty) {
      return const CoeloStatePanel(
        title: 'Nenhuma resposta',
        message: 'Ainda não há submissões neste recorte.',
        icon: Icons.inbox_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        Text('Respostas', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: CoeloSpacing.space4),
        for (final summary in page.items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.respondentLabel ?? 'Resposta anônima',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: CoeloSpacing.space1),
                      summary.submittedAt == null
                          ? const Text('Identidade e horário protegidos')
                          : Text(_dateTime(summary.submittedAt!)),
                    ],
                  );
                  final action = TextButton(
                    onPressed: () => _showDetail(summary),
                    child: const Text('Ver resposta'),
                  );
                  final stacked =
                      constraints.maxWidth < 480 || MediaQuery.textScalerOf(context).scale(1) >= 2;
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        const SizedBox(height: CoeloSpacing.space2),
                        Align(alignment: Alignment.centerRight, child: action),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: CoeloSpacing.space3),
                      action,
                    ],
                  );
                },
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
              onPressed: page.nextCursor == null
                  ? null
                  : () {
                      if (_cursors.length == _pageIndex + 1) _cursors.add(page.nextCursor);
                      _pageIndex++;
                      unawaited(_load());
                    },
              child: const Text('Próxima página'),
            ),
          ],
        ),
      ],
    );
  }

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/'
      '${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static String _answerText(FormAnswer answer) => switch (answer.value) {
    FormShortTextValue value => value.value,
    FormIntegerValue value => '${value.value}',
    FormDecimalValue value => '${value.value}',
    FormMoneyValue value => 'R\$ ${(value.minorUnits / 100).toStringAsFixed(2)}',
    FormDateValue value => _dateTime(value.value),
    FormYesNoValue value => value.value ? 'Sim' : 'Não',
    FormChoiceValue value => value.optionIds.join(', '),
    FormScaleValue value => '${value.value}',
    FormAssetValue value => '${value.assetIds.length} mídia(s) protegida(s)',
  };
}
