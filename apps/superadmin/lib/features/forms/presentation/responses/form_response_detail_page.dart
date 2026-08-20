import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

final class FormResponseDetailPage extends StatefulWidget {
  const FormResponseDetailPage({
    required this.api,
    required this.responseId,
    this.onOpenAsset,
    super.key,
  });

  final FormsApi? api;
  final String responseId;
  final ValueChanged<String>? onOpenAsset;

  @override
  State<FormResponseDetailPage> createState() => _FormResponseDetailPageState();
}

final class _FormResponseDetailPageState extends State<FormResponseDetailPage> {
  FormResponseDetail? _detail;
  FormApiException? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(() {
        _failure = const FormApiException(
          FormApiFailureKind.unavailable,
          'O serviço de respostas não está disponível.',
        );
      });
      return;
    }
    try {
      final detail = await api.getResponseDetail(widget.responseId);
      if (mounted) setState(() => _detail = detail);
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return CoeloStatePanel(
        title: failure.kind == FormApiFailureKind.unauthorized
            ? 'Acesso não autorizado'
            : 'Detalhe indisponível',
        message: failure.message,
        icon: Icons.lock_outline_rounded,
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const CoeloStatePanel(
        title: 'Carregando resposta',
        message: 'Buscando somente os dados que você pode consultar.',
        loading: true,
      );
    }
    final anonymous = detail.summary.respondentLabel == null;
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        Text(
          anonymous ? 'Resposta anônima' : detail.summary.respondentLabel!,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          anonymous
              ? 'Identidade, horário e ordem correlacionável permanecem protegidos.'
              : 'Resposta ${detail.summary.id}',
        ),
        const SizedBox(height: CoeloSpacing.space5),
        for (final answer in detail.answers.values) ...[
          Semantics(
            container: true,
            label: 'Resposta do item ${answer.itemId}',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Item ${answer.itemId}'),
              subtitle: _answerValue(answer),
            ),
          ),
          const Divider(),
        ],
      ],
    );
  }

  Widget _answerValue(FormAnswer answer) => switch (answer.value) {
    FormAssetValue value => Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${value.assetIds.length} mídia(s) protegida(s)'),
        for (var index = 0; index < value.assetIds.length; index++)
          TextButton(
            onPressed: widget.onOpenAsset == null
                ? null
                : () => widget.onOpenAsset!(value.assetIds[index]),
            child: Text('Ver foto ${index + 1}'),
          ),
      ],
    ),
    _ => Text(_answerText(answer)),
  };

  static String _answerText(FormAnswer answer) => switch (answer.value) {
    FormShortTextValue value => value.value,
    FormIntegerValue value => '${value.value}',
    FormDecimalValue value => '${value.value}',
    FormMoneyValue value => 'R\$ ${(value.minorUnits / 100).toStringAsFixed(2)}',
    FormDateValue value =>
      '${value.value.day.toString().padLeft(2, '0')}/'
          '${value.value.month.toString().padLeft(2, '0')}/${value.value.year}',
    FormYesNoValue value => value.value ? 'Sim' : 'Não',
    FormChoiceValue value => value.optionIds.join(', '),
    FormScaleValue value => '${value.value}',
    FormAssetValue value => '${value.assetIds.length} mídia(s) protegida(s)',
  };
}
