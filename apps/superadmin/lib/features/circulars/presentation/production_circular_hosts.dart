import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../institutions/domain/institution_directory_item.dart';
import '../../institutions/domain/institution_directory_query.dart';
import '../../institutions/domain/institution_directory_repository.dart';
import '../../principal_circulars/application/circular_composer_controller.dart';
import '../../principal_circulars/domain/circular.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../domain/superadmin_circular_repository.dart';
import 'circular_directory_page.dart';
import 'superadmin_circular_composer_page.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _state = CircularDirectoryViewState.loading);
    try {
      final page = await widget.repository.fetchDirectory(
        const SuperadminCircularDirectoryQuery(limit: 100),
      );
      if (!mounted) return;
      setState(() {
        _items = page.items
            .map(
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
            )
            .toList(growable: false);
        _state = CircularDirectoryViewState.content;
      });
    } on CircularUnauthorized {
      if (mounted) setState(() => _state = CircularDirectoryViewState.forbidden);
    } on Object {
      if (mounted) setState(() => _state = CircularDirectoryViewState.error);
    }
  }

  @override
  Widget build(BuildContext context) => CircularDirectoryPage(
    items: _items,
    viewState: _state,
    onRetry: _load,
    onCreate: _state == CircularDirectoryViewState.content ? widget.onCreate : null,
    onOpen: widget.onOpen,
  );
}

final class ProductionCircularComposerHost extends StatefulWidget {
  const ProductionCircularComposerHost({
    required this.repository,
    required this.institutionRepository,
    required this.onCancel,
    required this.onDone,
    this.circularId,
    super.key,
  });

  final SuperadminCircularRepository repository;
  final InstitutionDirectoryRepository institutionRepository;
  final String? circularId;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<ProductionCircularComposerHost> createState() => _ProductionCircularComposerHostState();
}

final class _ProductionCircularComposerHostState extends State<ProductionCircularComposerHost> {
  CircularComposerController? _controller;
  List<InstitutionDirectoryItem> _institutions = const [];
  InstitutionDirectoryItem? _selectedInstitution;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final circularId = widget.circularId;
      if (circularId != null) {
        final editable = await widget.repository.loadDraftById(circularId);
        _controller = CircularComposerController(
          repository: widget.repository,
          scope: editable.scope,
          initialDraft: editable.draft,
        );
      } else {
        final page = await widget.institutionRepository.fetchPage(
          InstitutionDirectoryQuery(
            statuses: const {InstitutionStatus.active, InstitutionStatus.onboarding},
            pageSize: 100,
          ),
        );
        _institutions = page.items;
        if (_institutions.isNotEmpty) _selectedInstitution = _institutions.first;
      }
    } on Object catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continueWithInstitution() {
    final selected = _selectedInstitution;
    if (selected == null) return;
    setState(() {
      _controller = CircularComposerController(
        repository: widget.repository,
        scope: CircularScope(institutionId: selected.id),
      );
    });
  }

  @override
  void dispose() {
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
    return SuperadminCircularComposerPage(
      controller: controller,
      onCancel: widget.onCancel,
      onPublished: widget.onDone,
      onPickFiles: () async {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Envio de anexos será habilitado após a seleção segura.')),
        );
      },
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
