import 'dart:async';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../application/form_asset_upload_controller.dart';
import '../../data/form_asset_picker.dart';
import '../../data/form_asset_uploader.dart';
import '../../data/form_anonymous_edit_secret_store.dart';

typedef FormRequestIdFactory = String Function();
typedef FormResponseAssetPicker =
    Future<List<FormPickedAsset>> Function(FormItemKind kind, int limit);
typedef FormResponseAssetUploader =
    Future<FormAsset> Function({
      required String itemId,
      required FormPickedAsset picked,
      void Function(double progress)? onProgress,
    });

final class FormResponsePage extends StatefulWidget {
  const FormResponsePage({
    required this.api,
    required this.occurrenceId,
    this.secretStore,
    this.requestIdFactory,
    this.assetPicker,
    this.assetUploader,
    super.key,
  });

  final FormsApi? api;
  final String occurrenceId;
  final FormAnonymousEditSecretStore? secretStore;
  final FormRequestIdFactory? requestIdFactory;
  final FormResponseAssetPicker? assetPicker;
  final FormResponseAssetUploader? assetUploader;

  @override
  State<FormResponsePage> createState() => _FormResponsePageState();
}

enum _ResponseStage { answering, review, submitted }

final class _FormResponsePageState extends State<FormResponsePage> {
  final _visibility = const FormVisibilityEvaluator();
  final _normalizer = const FormAnswerNormalizer();
  final _textControllers = <String, TextEditingController>{};
  final _answers = <String, FormAnswer>{};
  final _uploadProgress = <String, double>{};
  final _uploadingItems = <String>{};

  late final FormAssetPicker _defaultAssetPicker;
  FormAssetUploader? _defaultRawUploader;
  FormAssetUploadController? _defaultAssetController;

  FormOccurrenceForResponse? _projection;
  FormResponseDraft? _draft;
  FormApiException? _failure;
  String? _editSecret;
  String? _inlineMessage;
  var _stage = _ResponseStage.answering;
  var _sectionIndex = 0;
  var _busy = false;
  var _secretLost = false;
  var _editingSubmitted = false;

  @override
  void initState() {
    super.initState();
    _defaultAssetPicker = FormAssetPicker();
    if (widget.api case final api?) {
      final uploader = FormAssetUploader();
      _defaultRawUploader = uploader;
      _defaultAssetController = FormAssetUploadController(
        api: api,
        uploadBytes: uploader.upload,
        requestIdFactory: _requestId,
      );
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _defaultRawUploader?.close();
    super.dispose();
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(
        () => _failure = const FormApiException(
          FormApiFailureKind.unavailable,
          'O serviço de Formulários não está disponível.',
        ),
      );
      return;
    }
    try {
      final projection = await api.getOccurrenceForResponse(widget.occurrenceId);
      var draft = projection.draft;
      String? editSecret;
      String? mappedResponseId;
      if (projection.identityMode == FormIdentityMode.anonymous && draft != null) {
        editSecret = await widget.secretStore?.read(draft.id);
        if (editSecret == null) {
          if (mounted) {
            setState(() {
              _projection = projection;
              _draft = draft;
              _secretLost = true;
            });
          }
          return;
        }
      }
      if (draft == null) {
        if (projection.identityMode == FormIdentityMode.anonymous) {
          final store = widget.secretStore;
          if (store == null) {
            throw const FormApiException(
              FormApiFailureKind.unavailable,
              'Este dispositivo não pode guardar o segredo da resposta anônima.',
            );
          }
          mappedResponseId = await store.responseIdForOccurrence(projection.occurrence.id);
          if (mappedResponseId != null) {
            editSecret = await store.read(mappedResponseId);
            if (editSecret == null) {
              if (mounted) {
                setState(() {
                  _projection = projection;
                  _secretLost = true;
                });
              }
              return;
            }
          } else {
            editSecret = store.generate();
          }
        }
        draft = await api.openResponseDraft(
          FormCommand(
            requestId: _requestId(),
            expectedVersion: 0,
            payload: FormOpenResponseDraftPayload(
              occurrenceId: projection.occurrence.id,
              participationId: projection.participationId,
              identityMode: projection.identityMode,
              editSecret: editSecret,
            ),
          ),
        );
        if (editSecret != null) {
          if (mappedResponseId != null && mappedResponseId != draft.id) {
            throw const FormApiException(
              FormApiFailureKind.unauthorized,
              'A resposta anônima local não corresponde ao servidor.',
            );
          }
          await widget.secretStore!.save(responseId: draft.id, secret: editSecret);
          await widget.secretStore!.bindOccurrence(
            occurrenceId: projection.occurrence.id,
            responseId: draft.id,
          );
        }
      }
      _answers.addAll(draft.answers);
      if (mounted) {
        setState(() {
          _projection = projection;
          _draft = draft;
          _editSecret = editSecret;
          _editingSubmitted = draft!.status == FormResponseDraftStatus.submitted;
        });
      }
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure = const FormApiException(
            FormApiFailureKind.unavailable,
            'Não foi possível abrir esta resposta.',
          ),
        );
      }
    }
  }

  String _requestId() => widget.requestIdFactory?.call() ?? _secureUuid();

  String _secureUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  List<FormItem> get _visibleItems {
    final projection = _projection;
    if (projection == null) return const [];
    return [
      for (final section in projection.version.sections)
        for (final item in section.items)
          if (_visibility.isVisible(conditions: item.conditions, answers: _answers)) item,
    ];
  }

  Map<String, FormAnswer> _normalizedAnswers() {
    for (final item in _visibleItems) {
      final controller = _textControllers[item.id];
      if (controller == null) continue;
      final value = controller.text;
      switch (item.kind) {
        case FormItemKind.shortText:
          if (value.trim().isNotEmpty) {
            _answers[item.id] = FormAnswer.shortText(itemId: item.id, value: value);
          } else {
            _answers.remove(item.id);
          }
          continue;
        case FormItemKind.integer:
          final parsed = int.tryParse(value);
          if (parsed == null) {
            _answers.remove(item.id);
          } else {
            _answers[item.id] = FormAnswer.integer(itemId: item.id, value: parsed);
          }
          continue;
        case FormItemKind.decimal:
          final parsed = double.tryParse(value.replaceAll(',', '.'));
          if (parsed == null) {
            _answers.remove(item.id);
          } else {
            _answers[item.id] = FormAnswer.decimal(itemId: item.id, value: parsed);
          }
          continue;
        case FormItemKind.money:
          final parsed = double.tryParse(value.replaceAll(',', '.'));
          if (parsed == null) {
            _answers.remove(item.id);
          } else {
            _answers[item.id] = FormAnswer.money(
              itemId: item.id,
              minorUnits: (parsed * 100).round(),
            );
          }
          continue;
        default:
          continue;
      }
    }
    return _normalizer.normalize(
      answers: _answers,
      visibleItemIds: _visibleItems.map((item) => item.id).toSet(),
    );
  }

  bool _sectionIsValid(FormSection section) {
    final answers = _normalizedAnswers();
    return section.items
        .where(
          (item) =>
              _visibility.isVisible(conditions: item.conditions, answers: answers) &&
              item.isRequired,
        )
        .every((item) => answers.containsKey(item.id));
  }

  Future<void> _advance() async {
    final projection = _projection!;
    final section = projection.version.sections[_sectionIndex];
    if (!_sectionIsValid(section)) {
      setState(() => _inlineMessage = 'Responda aos campos obrigatórios visíveis para continuar.');
      return;
    }
    final api = widget.api!;
    final draft = _draft!;
    if (_editingSubmitted) {
      setState(() {
        _inlineMessage = null;
        if (_sectionIndex + 1 < projection.version.sections.length) {
          _sectionIndex++;
        } else {
          _stage = _ResponseStage.review;
        }
      });
      return;
    }
    setState(() {
      _busy = true;
      _inlineMessage = null;
    });
    try {
      _draft = await api.saveResponseDraft(
        FormCommand(
          requestId: _requestId(),
          expectedVersion: draft.managementVersion,
          payload: FormResponseDraftPayload(
            occurrenceId: projection.occurrence.id,
            responseId: draft.id,
            participationId: projection.participationId,
            answers: _normalizedAnswers(),
            editSecret: _editSecret,
          ),
        ),
      );
    } on FormApiException catch (error) {
      if (mounted) {
        setState(() {
          _inlineMessage = error.message;
          _busy = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _inlineMessage = null;
      if (_sectionIndex + 1 < projection.version.sections.length) {
        _sectionIndex++;
      } else {
        _stage = _ResponseStage.review;
      }
    });
  }

  Future<void> _submit() async {
    final api = widget.api!;
    final projection = _projection!;
    final draft = _draft!;
    setState(() {
      _busy = true;
      _inlineMessage = null;
    });
    try {
      final command = FormCommand(
        requestId: _requestId(),
        expectedVersion: draft.managementVersion,
        payload: FormResponseDraftPayload(
          occurrenceId: projection.occurrence.id,
          responseId: draft.id,
          participationId: projection.participationId,
          answers: _normalizedAnswers(),
          editSecret: _editSecret,
        ),
      );
      final result = _editingSubmitted
          ? await api.editResponse(command)
          : await api.submitResponse(command);
      if (mounted) {
        setState(() {
          _draft = result;
          _stage = _ResponseStage.submitted;
        });
      }
    } on FormApiException catch (error) {
      if (mounted) setState(() => _inlineMessage = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<FormPickedAsset>> _pickAssets(FormItemKind kind, int limit) {
    final override = widget.assetPicker;
    if (override != null) return override(kind, limit);
    return kind == FormItemKind.photo
        ? _defaultAssetPicker.capturePhoto()
        : _defaultAssetPicker.pickGallery(limit: limit);
  }

  Future<FormAsset> _uploadPickedAsset({
    required String itemId,
    required FormPickedAsset picked,
    void Function(double progress)? onProgress,
  }) {
    final override = widget.assetUploader;
    if (override != null) {
      return override(itemId: itemId, picked: picked, onProgress: onProgress);
    }
    final controller = _defaultAssetController;
    if (controller == null) {
      throw const FormAssetUploadFlowException('O envio de imagens não está disponível.');
    }
    return controller.upload(
      occurrenceId: _projection!.occurrence.id,
      itemId: itemId,
      bytes: picked.bytes,
      mimeType: picked.mimeType,
      editSecret: _editSecret,
      onProgress: onProgress,
    );
  }

  Future<void> _selectAndUploadAssets(FormItem item) async {
    final existing = (_answers[item.id]?.value as FormAssetValue?)?.assetIds ?? const <String>[];
    final maximum = item.kind == FormItemKind.photo ? 1 : 5;
    final remaining = maximum - existing.length;
    if (remaining <= 0) {
      setState(() => _inlineMessage = 'O limite de imagens desta pergunta foi atingido.');
      return;
    }
    setState(() {
      _uploadingItems.add(item.id);
      _uploadProgress[item.id] = 0;
      _inlineMessage = null;
    });
    try {
      final picked = await _pickAssets(item.kind, remaining);
      if (picked.length > remaining) {
        throw const FormAssetUploadFlowException('Selecione no máximo cinco imagens.');
      }
      final assetIds = [...existing];
      for (final image in picked) {
        final asset = await _uploadPickedAsset(
          itemId: item.id,
          picked: image,
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress[item.id] = progress);
          },
        );
        assetIds.add(asset.id);
      }
      if (!mounted) return;
      setState(() {
        if (assetIds.isNotEmpty) {
          _answers[item.id] = item.kind == FormItemKind.photo
              ? FormAnswer.photo(itemId: item.id, assetIds: assetIds)
              : FormAnswer.gallery(itemId: item.id, assetIds: assetIds);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _inlineMessage = 'Não foi possível enviar a imagem. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingItems.remove(item.id);
          _uploadProgress.remove(item.id);
        });
      }
    }
  }

  Future<void> _discardAsset(FormItem item, String assetId) async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _uploadingItems.add(item.id));
    try {
      await api.discardAsset(
        FormCommand(
          requestId: _requestId(),
          expectedVersion: 0,
          payload: FormAssetIdPayload(assetId, editSecret: _editSecret),
        ),
      );
      if (!mounted) return;
      final current = (_answers[item.id]?.value as FormAssetValue?)?.assetIds ?? const <String>[];
      final remaining = current.where((id) => id != assetId).toList(growable: false);
      setState(() {
        if (remaining.isEmpty) {
          _answers.remove(item.id);
        } else {
          _answers[item.id] = item.kind == FormItemKind.photo
              ? FormAnswer.photo(itemId: item.id, assetIds: remaining)
              : FormAnswer.gallery(itemId: item.id, assetIds: remaining);
        }
      });
    } on FormApiException catch (error) {
      if (mounted) setState(() => _inlineMessage = error.message);
    } finally {
      if (mounted) setState(() => _uploadingItems.remove(item.id));
    }
  }

  Future<void> _selectDate(FormItem item) async {
    final existing = (_answers[item.id]?.value as FormDateValue?)?.value;
    final normalized = existing == null ? null : DateUtils.dateOnly(existing);
    final selected = await showCoeloDateRangePicker(
      context: context,
      value: normalized == null ? null : DateTimeRange(start: normalized, end: normalized),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      currentDate: DateTime.now(),
      showQuickRanges: true,
    );
    if (!mounted) return;
    setState(() {
      if (selected == null) {
        _answers.remove(item.id);
      } else {
        _answers[item.id] = FormAnswer.date(itemId: item.id, value: selected.start);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return CoeloStatePanel(
        title: failure.kind == FormApiFailureKind.unauthorized
            ? 'Acesso não autorizado'
            : 'Resposta indisponível',
        message: failure.message,
        icon: Icons.lock_outline_rounded,
      );
    }
    final projection = _projection;
    if (projection == null) {
      return const CoeloStatePanel(
        title: 'Abrindo formulário',
        message: 'Aguarde enquanto sua participação é validada.',
        loading: true,
      );
    }
    if (_secretLost) {
      return const CoeloStatePanel(
        title: 'Edição anônima indisponível',
        message: 'Não é possível editar esta resposta anônima neste dispositivo.',
        icon: Icons.key_off_outlined,
      );
    }
    if (!projection.canEdit && _stage != _ResponseStage.submitted) {
      return const CoeloStatePanel(
        title: 'Formulário encerrado',
        message: 'Esta ocorrência não aceita mais respostas.',
        icon: Icons.event_busy_outlined,
      );
    }
    if (_stage == _ResponseStage.submitted) {
      return CoeloStatePanel(
        title: _editingSubmitted ? 'Resposta atualizada' : 'Resposta enviada',
        message: _editingSubmitted
            ? 'Suas alterações foram salvas com sucesso.'
            : 'Seu envio foi concluído com sucesso.',
        icon: Icons.check_circle_outline_rounded,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(CoeloSpacing.space5),
              children: [
                if (projection.identityMode == FormIdentityMode.anonymous)
                  Semantics(
                    liveRegion: true,
                    child: const Card(
                      child: Padding(
                        padding: EdgeInsets.all(CoeloSpacing.space4),
                        child: Text(
                          'Suas respostas são anônimas e ninguém saberá que foi você que respondeu',
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: CoeloSpacing.space3),
                if (_stage == _ResponseStage.review)
                  _buildReview(context)
                else
                  _buildSection(context),
                if (_inlineMessage != null) ...[
                  const SizedBox(height: CoeloSpacing.space3),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _inlineMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context) {
    final sections = _projection!.version.sections;
    final section = sections[_sectionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Seção ${_sectionIndex + 1} de ${sections.length}',
          child: LinearProgressIndicator(value: (_sectionIndex + 1) / sections.length),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Text(section.title, style: Theme.of(context).textTheme.headlineSmall),
        if (section.description != null) Text(section.description!),
        const SizedBox(height: CoeloSpacing.space4),
        for (final item in section.items)
          if (_visibility.isVisible(conditions: item.conditions, answers: _answers)) ...[
            _itemField(item),
            const SizedBox(height: CoeloSpacing.space4),
          ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space3,
          children: [
            if (_sectionIndex > 0)
              OutlinedButton(
                onPressed: () => setState(() => _sectionIndex--),
                child: const Text('Voltar'),
              ),
            FilledButton(
              onPressed: _busy ? null : _advance,
              child: Text(_sectionIndex + 1 == sections.length ? 'Revisar' : 'Continuar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _itemField(FormItem item) {
    final label = '${item.label}${item.isRequired ? ' *' : ''}';
    switch (item.kind) {
      case FormItemKind.information:
        return Semantics(header: true, child: Text(item.label));
      case FormItemKind.shortText:
      case FormItemKind.integer:
      case FormItemKind.decimal:
      case FormItemKind.money:
        final existing = _answers[item.id]?.value;
        final initial = switch (existing) {
          FormShortTextValue value => value.value,
          FormIntegerValue value => value.value.toString(),
          FormDecimalValue value => value.value.toString(),
          FormMoneyValue value => (value.minorUnits / 100).toStringAsFixed(2),
          _ => '',
        };
        final controller = _textControllers.putIfAbsent(
          item.id,
          () => TextEditingController(text: initial),
        );
        return TextField(
          key: ValueKey(item.id),
          controller: controller,
          minLines: item.kind == FormItemKind.shortText ? 1 : null,
          maxLines: item.kind == FormItemKind.shortText ? 4 : 1,
          keyboardType: item.kind == FormItemKind.shortText
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, helperText: item.helpText),
        );
      case FormItemKind.yesNo:
        final current = (_answers[item.id]?.value as FormYesNoValue?)?.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: CoeloSpacing.space2),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Sim')),
                ButtonSegment(value: false, label: Text('Não')),
              ],
              selected: current == null ? const {} : {current},
              emptySelectionAllowed: true,
              onSelectionChanged: (values) => setState(() {
                if (values.isEmpty) {
                  _answers.remove(item.id);
                } else {
                  _answers[item.id] = FormAnswer.yesNo(itemId: item.id, value: values.first);
                }
              }),
            ),
          ],
        );
      case FormItemKind.singleChoice:
      case FormItemKind.multipleChoice:
        final selected =
            (_answers[item.id]?.value as FormChoiceValue?)?.optionIds ?? const <String>{};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: CoeloSpacing.space2),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                for (final option in item.options)
                  FilterChip(
                    label: Text(option.label),
                    selected: selected.contains(option.id),
                    onSelected: (value) => setState(() {
                      final next = {...selected};
                      if (item.kind == FormItemKind.singleChoice) next.clear();
                      if (value) {
                        next.add(option.id);
                      } else {
                        next.remove(option.id);
                      }
                      if (next.isEmpty) {
                        _answers.remove(item.id);
                      } else if (item.kind == FormItemKind.singleChoice) {
                        _answers[item.id] = FormAnswer.singleChoice(
                          itemId: item.id,
                          optionId: next.first,
                        );
                      } else {
                        _answers[item.id] = FormAnswer.multipleChoice(
                          itemId: item.id,
                          optionIds: next,
                        );
                      }
                    }),
                  ),
              ],
            ),
          ],
        );
      case FormItemKind.scale:
        final minimum = item.config.scaleMin ?? 0;
        final maximum = item.config.scaleMax ?? 10;
        final current = (_answers[item.id]?.value as FormScaleValue?)?.value ?? minimum;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: $current'),
            Slider(
              value: current.toDouble(),
              min: minimum.toDouble(),
              max: maximum.toDouble(),
              divisions: maximum - minimum,
              label: '$current',
              onChanged: (value) => setState(() {
                _answers[item.id] = FormAnswer.scale(itemId: item.id, value: value.round());
              }),
            ),
          ],
        );
      case FormItemKind.date:
        final date = (_answers[item.id]?.value as FormDateValue?)?.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            if (item.helpText case final helpText?) Text(helpText),
            const SizedBox(height: CoeloSpacing.space2),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _selectDate(item),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                date == null
                    ? 'Selecionar data'
                    : MaterialLocalizations.of(context).formatShortDate(date),
              ),
            ),
          ],
        );
      case FormItemKind.photo:
      case FormItemKind.gallery:
        final assetIds =
            (_answers[item.id]?.value as FormAssetValue?)?.assetIds ?? const <String>[];
        final uploading = _uploadingItems.contains(item.id);
        final progress = _uploadProgress[item.id];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: CoeloSpacing.space2),
            if (assetIds.isNotEmpty)
              Wrap(
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space2,
                children: [
                  for (var index = 0; index < assetIds.length; index++)
                    InputChip(
                      label: Text('Imagem ${index + 1}'),
                      onDeleted: uploading ? null : () => _discardAsset(item, assetIds[index]),
                      deleteButtonTooltipMessage: 'Remover imagem ${index + 1}',
                    ),
                ],
              ),
            if (assetIds.isNotEmpty) const SizedBox(height: CoeloSpacing.space2),
            Semantics(
              label: item.kind == FormItemKind.photo
                  ? 'Tirar foto para $label'
                  : 'Escolher imagens para $label',
              child: OutlinedButton.icon(
                onPressed: uploading ? null : () => _selectAndUploadAssets(item),
                icon: Icon(
                  item.kind == FormItemKind.photo
                      ? Icons.photo_camera_outlined
                      : Icons.add_photo_alternate_outlined,
                ),
                label: Text(item.kind == FormItemKind.photo ? 'Tirar foto' : 'Escolher imagens'),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Semantics(
                liveRegion: true,
                label: 'Upload ${(progress * 100).round()} por cento',
                child: LinearProgressIndicator(value: progress),
              ),
            ],
          ],
        );
    }
  }

  Widget _buildReview(BuildContext context) {
    final answers = _normalizedAnswers();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Revise suas respostas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space4),
        for (final item in _visibleItems)
          if (answers[item.id] case final answer?)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.label),
              subtitle: Text(_answerLabel(answer, item)),
            ),
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space3,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => setState(() => _stage = _ResponseStage.answering),
              child: const Text('Editar respostas'),
            ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Salvando…'
                    : _editingSubmitted
                    ? 'Confirmar alteração'
                    : 'Confirmar envio',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _answerLabel(FormAnswer answer, FormItem item) => switch (answer.value) {
    FormShortTextValue value => value.value,
    FormIntegerValue value => '${value.value}',
    FormDecimalValue value => '${value.value}',
    FormMoneyValue value => 'R\$ ${(value.minorUnits / 100).toStringAsFixed(2)}',
    FormDateValue value =>
      '${value.value.day.toString().padLeft(2, '0')}/'
          '${value.value.month.toString().padLeft(2, '0')}/${value.value.year}',
    FormYesNoValue value => value.value ? 'Sim' : 'Não',
    FormChoiceValue value =>
      item.options
          .where((option) => value.optionIds.contains(option.id))
          .map((option) => option.label)
          .join(', '),
    FormScaleValue value => '${value.value}',
    FormAssetValue value => '${value.assetIds.length} arquivo(s)',
  };
}

@Preview(name: 'Formulários · resposta identificada · desktop', size: Size(1024, 800))
Widget formResponseDesktopPreview() => MaterialApp(
  theme: ThemeData(useMaterial3: true),
  home: FormResponsePage(
    api: _FormResponsePreviewApi(FormIdentityMode.identified),
    occurrenceId: 'preview-occurrence',
  ),
);

@Preview(name: 'Formulários · resposta anônima · compacto dark', size: Size(375, 800))
Widget formResponseAnonymousCompactPreview() => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: FormResponsePage(
    api: _FormResponsePreviewApi(FormIdentityMode.anonymous),
    occurrenceId: 'preview-occurrence',
    secretStore: _PreviewSecretStore(),
  ),
);

final class _PreviewSecretStore implements FormAnonymousEditSecretStore {
  final _secrets = <String, String>{};
  final _responses = <String, String>{};

  @override
  String generate() => List.filled(43, 's').join();
  @override
  Future<void> save({required String responseId, required String secret}) async {
    _secrets[responseId] = secret;
  }

  @override
  Future<String?> read(String responseId) async => _secrets[responseId];
  @override
  Future<void> bindOccurrence({required String occurrenceId, required String responseId}) async {
    _responses[occurrenceId] = responseId;
  }

  @override
  Future<String?> responseIdForOccurrence(String occurrenceId) async => _responses[occurrenceId];
  @override
  Future<void> remove(String responseId) async {
    _secrets.remove(responseId);
  }
}

final class _FormResponsePreviewApi implements FormsApi {
  _FormResponsePreviewApi(this.identityMode);

  final FormIdentityMode identityMode;

  FormResponseDraft get _draft => FormResponseDraft(
    id: 'preview-response',
    occurrenceId: 'preview-occurrence',
    status: FormResponseDraftStatus.draft,
    answers: {},
    managementVersion: 1,
  );

  @override
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId) async =>
      FormOccurrenceForResponse(
        occurrence: FormOccurrence(
          id: occurrenceId,
          applicationId: 'preview-application',
          formVersionId: 'preview-version',
          opensAt: DateTime.now().subtract(const Duration(hours: 1)),
          closesAt: DateTime.now().add(const Duration(days: 1)),
          status: FormOccurrenceStatus.open,
          managementVersion: 1,
        ),
        version: FormVersion(
          id: 'preview-version',
          formId: 'preview-form',
          number: 1,
          isPublished: true,
          sections: [
            FormSection(
              id: 'preview-section',
              title: 'Sua experiência',
              description: 'Responda somente o que estiver visível.',
              position: 0,
              items: [
                FormItem(
                  id: 'preview-text',
                  kind: FormItemKind.shortText,
                  label: 'O que podemos melhorar?',
                  position: 0,
                  isRequired: true,
                ),
                FormItem(
                  id: 'preview-photo',
                  kind: FormItemKind.photo,
                  label: 'Envie uma foto',
                  position: 1,
                ),
              ],
            ),
          ],
        ),
        participationId: 'preview-participation',
        identityMode: identityMode,
        canEdit: true,
      );

  @override
  Future<FormResponseDraft> openResponseDraft(
    FormCommand<FormOpenResponseDraftPayload> command,
  ) async => _draft;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
