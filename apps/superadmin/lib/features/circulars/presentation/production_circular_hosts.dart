import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../app/shell/superadmin_shell.dart';
import '../../institutions/domain/institution_directory_item.dart';
import '../../institutions/domain/institution_directory_query.dart';
import '../../institutions/domain/institution_directory_repository.dart';
import '../../principal_circulars/application/circular_composer_controller.dart';
import '../../principal_circulars/application/circular_media_upload_coordinator.dart';
import '../../principal_circulars/domain/circular.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../domain/superadmin_circular_repository.dart';
import 'circular_directory_page.dart';
import 'superadmin_circular_composer_page.dart';

/// Returns the files chosen by the operator. Selection is a convenience: the
/// server re-validates identity, scope, MIME, signature, bytes and quota.
typedef CircularAttachmentPicker = Future<List<CircularSelectedFile>> Function();

final class ProductionCircularDirectoryHost extends StatefulWidget {
  const ProductionCircularDirectoryHost({
    required this.repository,
    required this.onOpen,
    required this.onCreate,
    super.key,
  });

  final SuperadminCircularRepository repository;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;

  @override
  State<ProductionCircularDirectoryHost> createState() => _ProductionCircularDirectoryHostState();
}

final class _ProductionCircularDirectoryHostState extends State<ProductionCircularDirectoryHost> {
  var _state = CircularDirectoryViewState.loading;
  List<CircularDirectoryItem> _items = const [];
  var _loadGeneration = 0;
  var _truncated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductionCircularDirectoryHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) _load();
  }

  /// Paginas seguidas por rodada de leitura.
  ///
  /// O diretorio filtra, busca e pagina na propria pagina, sobre a lista que
  /// recebe. Ler uma unica pagina fazia o restante do acervo sumir em silencio:
  /// uma busca por uma Circular antiga simplesmente nao encontrava nada. O host
  /// passa a seguir o cursor do servidor ate acabar, com um teto para nao
  /// prender a tela, e diz a verdade quando o teto e alcancado. A lista aparece
  /// na primeira pagina e cresce nas seguintes, para que seguir o cursor nao
  /// custe uma tela parada ate a ultima resposta.
  static const _maxPages = 10;
  static const _pageSize = 100;

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _items = const [];
      _truncated = false;
      _state = CircularDirectoryViewState.loading;
    });
    try {
      final collected = <CircularDirectoryItem>[];
      DateTime? cursorUpdatedAt;
      String? cursorId;
      var truncated = false;
      for (var page = 0; page < _maxPages; page++) {
        final fetched = await widget.repository.fetchDirectory(
          SuperadminCircularDirectoryQuery(
            limit: _pageSize,
            cursorUpdatedAt: cursorUpdatedAt,
            cursorId: cursorId,
          ),
        );
        if (!mounted || generation != _loadGeneration) return;
        collected.addAll(
          fetched.items.map(
            (item) => CircularDirectoryItem(
              id: item.id,
              title: item.title,
              excerpt: item.excerpt,
              authorName: item.authorName,
              contextLabel: item.contextLabel,
              status: item.status,
              effectiveAt: item.effectiveAt,
              attachmentCount: item.attachmentCount,
              questionCount: item.questionCount,
              responseCount: item.responseCount,
            ),
          ),
        );
        cursorUpdatedAt = fetched.nextCursorUpdatedAt;
        cursorId = fetched.nextCursorId;
        final finished = cursorUpdatedAt == null || cursorId == null;
        if (!finished && page == _maxPages - 1) truncated = true;
        // A lista aparece assim que a PRIMEIRA pagina chega e cresce com as
        // seguintes. Esperar todas antes de mostrar qualquer coisa trocaria o
        // acervo escondido por uma tela parada: numa instituicao grande sao ate
        // dez idas ao servidor antes do primeiro item.
        setState(() {
          _items = List.unmodifiable(collected);
          _truncated = truncated;
          _state = CircularDirectoryViewState.content;
        });
        if (finished) break;
      }
    } on CircularUnauthorized {
      if (mounted && generation == _loadGeneration) {
        setState(() => _state = CircularDirectoryViewState.forbidden);
      }
    } on Object {
      if (mounted && generation == _loadGeneration) {
        setState(() => _state = CircularDirectoryViewState.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = CircularDirectoryPage(
      items: _items,
      viewState: _state,
      onRetry: _load,
      onCreate: _state == CircularDirectoryViewState.content ? widget.onCreate : null,
      onOpen: widget.onOpen,
    );
    if (!_truncated) return directory;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            key: const Key('circular-directory-truncated'),
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            color: colors.secondaryContainer,
            child: Text(
              'Mostrando as ${_maxPages * _pageSize} Circulares mais recentes. '
              'Use a busca da instituição para encontrar as anteriores.',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ),
        Expanded(child: directory),
      ],
    );
  }
}

final class ProductionCircularComposerHost extends StatefulWidget {
  const ProductionCircularComposerHost({
    required this.repository,
    required this.institutionRepository,
    required this.onCancel,
    required this.onDone,
    this.circularId,
    this.mediaRepository,
    this.filePicker,
    this.mediaHttpClient,
    super.key,
  });

  final SuperadminCircularRepository repository;
  final InstitutionDirectoryRepository institutionRepository;
  final String? circularId;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  /// Media capability of the Circular domain. When it is absent the composer
  /// stays fail-closed for attachments instead of faking a local selection.
  final CircularMediaRepository? mediaRepository;

  /// Injected only by tests; production uses the platform file picker.
  final CircularAttachmentPicker? filePicker;

  /// Injected only by tests; the coordinator owns the real transfer otherwise.
  final http.Client? mediaHttpClient;

  @override
  State<ProductionCircularComposerHost> createState() => _ProductionCircularComposerHostState();
}

final class _ProductionCircularComposerHostState extends State<ProductionCircularComposerHost> {
  CircularComposerController? _controller;
  CircularMediaUploadCoordinator? _uploader;
  List<InstitutionDirectoryItem> _institutions = const [];
  InstitutionDirectoryItem? _selectedInstitution;
  Object? _error;
  var _loading = true;
  var _prepareGeneration = 0;
  var _pickGeneration = 0;
  var _uploading = false;
  String? _attachmentStatus;
  var _attachmentFailed = false;
  VoidCallback? _releaseChatLauncher;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  // Decisao 7 (sem balao de chat em criar/editar/publicar): o frame do
  // compositor so entra depois de escolher a instituicao; enquanto carrega ou
  // mostra o seletor, o host suprime o balao por conta propria (achado R05,
  // ui-22).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _releaseChatLauncher ??= SuperadminShell.suppressChatLauncher(context);
  }

  @override
  void didUpdateWidget(covariant ProductionCircularComposerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circularId != widget.circularId ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.institutionRepository, widget.institutionRepository)) {
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final generation = ++_prepareGeneration;
    final repository = widget.repository;
    final institutionRepository = widget.institutionRepository;
    final circularId = widget.circularId;
    _controller?.dispose();
    _pickGeneration++;
    setState(() {
      _controller = null;
      _uploader = null;
      _institutions = const [];
      _selectedInstitution = null;
      _error = null;
      _loading = true;
      _uploading = false;
      _attachmentStatus = null;
      _attachmentFailed = false;
    });
    try {
      if (circularId != null) {
        final editable = await repository.loadDraftById(circularId);
        if (!mounted || generation != _prepareGeneration) return;
        _adopt(
          CircularComposerController(
            repository: repository,
            scope: editable.scope,
            initialDraft: editable.draft,
          ),
        );
      } else {
        final page = await institutionRepository.fetchPage(
          InstitutionDirectoryQuery(
            statuses: const {InstitutionStatus.active, InstitutionStatus.onboarding},
            pageSize: 100,
          ),
        );
        if (!mounted || generation != _prepareGeneration) return;
        _institutions = page.items;
        if (_institutions.isNotEmpty) _selectedInstitution = _institutions.first;
      }
    } on Object catch (error) {
      if (!mounted || generation != _prepareGeneration) return;
      _error = error;
    } finally {
      if (mounted && generation == _prepareGeneration) setState(() => _loading = false);
    }
  }

  void _continueWithInstitution() {
    final selected = _selectedInstitution;
    if (selected == null) return;
    setState(() {
      _adopt(
        CircularComposerController(
          repository: widget.repository,
          scope: CircularScope(institutionId: selected.id),
        ),
      );
    });
  }

  void _adopt(CircularComposerController controller) {
    _controller = controller;
    final mediaRepository = widget.mediaRepository;
    _uploader = mediaRepository == null
        ? null
        : CircularMediaUploadCoordinator(
            controller: controller,
            repository: mediaRepository,
            httpClient: widget.mediaHttpClient,
          );
  }

  /// Picks and uploads attachments. Local checks only give fast feedback; the
  /// asset only exists after the backend authorizes prepare and finalize.
  Future<void> _pickAttachments(CircularComposerController controller) async {
    if (_uploading) return;
    final uploader = _uploader;
    if (uploader == null) {
      _report('Envio de anexos indisponível nesta composição.', failed: true);
      return;
    }
    final used = controller.draft.blocks
        .whereType<CircularMediaBlock>()
        .expand((block) => block.assetIds)
        .length;
    final remaining = CircularLimits.files - used;
    if (remaining <= 0) {
      _report(
        'Limite de ${CircularLimits.files} arquivos por Circular já alcançado.',
        failed: true,
      );
      return;
    }
    final generation = ++_pickGeneration;
    setState(() {
      _uploading = true;
      _attachmentFailed = false;
      _attachmentStatus = 'Selecionando arquivos…';
    });
    try {
      final picked = await (widget.filePicker ?? _defaultPicker)();
      if (!mounted || generation != _pickGeneration) return;
      if (picked.isEmpty) {
        _report('Nenhum arquivo selecionado.');
        return;
      }
      final withinQuota = picked.take(remaining).toList(growable: false);
      final overQuota = picked.length - withinQuota.length;
      final accepted = withinQuota.where((file) => file.acceptedLocally).toList(growable: false);
      final rejected = withinQuota.length - accepted.length;
      if (accepted.isEmpty) {
        _report(_rejectionMessage(rejected, overQuota), failed: true);
        return;
      }
      var sent = 0;
      String? failure;
      for (final file in accepted) {
        setState(() => _attachmentStatus = 'Enviando ${sent + 1} de ${accepted.length}…');
        try {
          await uploader.upload(file);
        } on CircularUnauthorized {
          failure = 'Você não tem permissão para enviar anexos nesta Circular.';
        } on CircularVersionConflict {
          failure = 'A Circular mudou em outro lugar. Recarregue antes de anexar.';
        } on CircularInvalid catch (error) {
          failure = error.code == 'media_upload_expired'
              ? 'A janela autorizada de envio expirou. Tente novamente.'
              : 'O servidor recusou o arquivo. Verifique tipo, tamanho e conteúdo.';
        } on Object {
          failure = 'Não foi possível concluir o envio. Tente novamente.';
        }
        if (!mounted || generation != _pickGeneration) return;
        if (failure != null) break;
        sent++;
      }
      _report(
        _outcomeMessage(
          sent: sent,
          total: accepted.length,
          rejected: rejected,
          overQuota: overQuota,
          failure: failure,
        ),
        failed: failure != null || rejected > 0 || overQuota > 0,
      );
    } on Object {
      if (!mounted || generation != _pickGeneration) return;
      _report('Não foi possível abrir a seleção de arquivos.', failed: true);
    } finally {
      if (mounted && generation == _pickGeneration) setState(() => _uploading = false);
    }
  }

  String _rejectionMessage(int rejected, int overQuota) {
    if (rejected > 0) {
      return 'Arquivo não aceito. Use imagem JPEG/PNG/WebP até 10 MB, vídeo MP4 até 25 MB '
          'ou PDF até 5 MB.';
    }
    return overQuota > 0
        ? 'Limite de ${CircularLimits.files} arquivos por Circular já alcançado.'
        : 'Nenhum arquivo selecionado.';
  }

  String _outcomeMessage({
    required int sent,
    required int total,
    required int rejected,
    required int overQuota,
    required String? failure,
  }) {
    final extra = [
      if (rejected > 0) '$rejected recusado(s) localmente',
      if (overQuota > 0) '$overQuota acima do limite de ${CircularLimits.files}',
    ].join(' · ');
    final suffix = extra.isEmpty ? '' : ' ($extra)';
    if (failure != null) {
      return sent == 0 ? '$failure$suffix' : '$sent de $total enviado(s). $failure$suffix';
    }
    return sent == 1 ? 'Anexo enviado.$suffix' : '$sent anexos enviados.$suffix';
  }

  void _report(String message, {bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _attachmentStatus = message;
      _attachmentFailed = failed;
    });
  }

  Future<List<CircularSelectedFile>> _defaultPicker() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: CircularMediaLimits.acceptedExtensions.keys.toList(growable: false),
    );
    return [
      for (final file in result?.files ?? const <PlatformFile>[])
        if (file.bytes case final bytes?)
          CircularSelectedFile(
            uploadRequestId: CircularMediaLimits.newRequestId(),
            name: file.name,
            mimeType: CircularMediaLimits.mimeForFileName(file.name) ?? 'application/octet-stream',
            bytes: bytes,
          ),
    ];
  }

  @override
  void dispose() {
    _pickGeneration++;
    _releaseChatLauncher?.call();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CoeloStatePanel(
        title: 'Carregando Circular',
        message: 'Preparando o contexto autorizado.',
        loading: true,
      );
    }
    if (_error != null) {
      return CoeloStatePanel(
        title: 'Não foi possível abrir a Circular',
        message: 'Revise seu acesso e tente novamente.',
        actionLabel: 'Voltar',
        onAction: widget.onCancel,
      );
    }
    final controller = _controller;
    if (controller == null) return _institutionPicker(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_attachmentStatus case final status?) _attachmentBanner(context, status),
        Expanded(
          child: SuperadminCircularComposerPage(
            controller: controller,
            onCancel: widget.onCancel,
            onPublished: widget.onDone,
            onPickFiles: () => _pickAttachments(controller),
            onChooseSchedule: _chooseSchedule,
          ),
        ),
      ],
    );
  }

  /// Agendamento pela tela (circulars.schedule, R05): o host produtivo nao
  /// passava `onChooseSchedule`, entao o botao "Escolher data e hora" ficava
  /// desabilitado e so o agendamento por RPC existia. Mesmos seletores Coelo
  /// de Avisos (data unica + horario); a validacao continua no servidor.
  Future<DateTime?> _chooseSchedule() async {
    final now = DateTime.now();
    final day = await showCoeloDateRangePicker(
      context: context,
      value: DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day),
      ),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      selectionMode: CoeloDateSelectionMode.single,
      showQuickRanges: false,
    );
    if (!mounted || day == null) return null;
    final time = await showCoeloTimePicker(
      context: context,
      initialValue: TimeOfDay(hour: now.hour, minute: 0),
      title: 'Horário — publicação da Circular',
    );
    if (!mounted || time == null) return null;
    return DateTime(day.start.year, day.start.month, day.start.day, time.hour, time.minute);
  }

  Widget _attachmentBanner(BuildContext context, String status) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('circular-attachment-status'),
        margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          color: _attachmentFailed ? colors.errorContainer : colors.primaryContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
        ),
        child: Row(
          children: [
            if (_uploading)
              const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(
                _attachmentFailed
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: _attachmentFailed ? colors.error : colors.primary,
              ),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(child: Text(status)),
            if (!_uploading)
              SizedBox(
                width: CoeloSize.touchMin,
                height: CoeloSize.touchMin,
                child: IconButton(
                  tooltip: 'Dispensar aviso',
                  onPressed: () => setState(() => _attachmentStatus = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _institutionPicker(BuildContext context) {
    if (_institutions.isEmpty) {
      return CoeloStatePanel(
        title: 'Nenhuma instituição disponível',
        message: 'Não há instituição ativa no seu escopo para publicar esta Circular.',
        actionLabel: 'Voltar',
        onAction: widget.onCancel,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Onde publicar?',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                'Escolha a instituição. O servidor validará novamente este escopo ao salvar.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: CoeloSpacing.space5),
              CoeloAdminSingleSelectField<InstitutionDirectoryItem>(
                value: _selectedInstitution!,
                label: 'Instituição',
                options: _institutions,
                optionLabel: (item) => item.publicName,
                prefixIcon: Icons.apartment_outlined,
                onChanged: (value) => setState(() => _selectedInstitution = value),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              FilledButton(
                onPressed: _selectedInstitution == null ? null : _continueWithInstitution,
                child: const Text('Continuar'),
              ),
              TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
  }
}
