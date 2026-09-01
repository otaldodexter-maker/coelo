import 'dart:math';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/access_profile.dart';

final class AccessProfileDuplicatePage extends StatefulWidget {
  const AccessProfileDuplicatePage({
    required this.repository,
    required this.duplicator,
    required this.logout,
    required this.domain,
    required this.sourceProfileId,
    required this.onCancel,
    required this.onDuplicated,
    this.onDestinationSelected,
    super.key,
  });

  final AccessProfileRepository repository;
  final AccessProfileDuplicator duplicator;
  final LogoutAction logout;
  final AccessProfileDomain domain;
  final String sourceProfileId;
  final VoidCallback onCancel;
  final ValueChanged<AccessProfile> onDuplicated;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<AccessProfileDuplicatePage> createState() => _AccessProfileDuplicatePageState();
}

final class _AccessProfileDuplicatePageState extends State<AccessProfileDuplicatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _reason = TextEditingController();
  AccessProfile? _source;
  Object? _error;
  bool _saving = false;
  double _footerHeight = 0;
  String? _requestId;
  String? _fingerprint;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final source = await widget.repository.fetchDetail(widget.domain, widget.sourceProfileId);
      if (!mounted) return;
      _name.text = '${source.name} (cópia)';
      setState(() => _source = source);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _duplicate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final fingerprint = '${widget.sourceProfileId}|${_name.text.trim()}|${_reason.text.trim()}';
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _requestId = _newRequestId();
    }
    setState(() => _saving = true);
    try {
      final duplicate = await widget.duplicator.duplicate(
        requestId: _requestId!,
        sourceProfileId: widget.sourceProfileId,
        domain: widget.domain,
        name: _name.text.trim(),
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      _requestId = null;
      _fingerprint = null;
      widget.onDuplicated(duplicate);
    } on AccessProfileException catch (error) {
      if (mounted) {
        showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Duplicar modelo de perfil',
    subtitle: 'Crie uma base independente e inativa para revisar antes do uso.',
    currentDestination: 'profiles',
    chatLauncherBottomInset: _footerHeight,
    onDestinationSelected: widget.onDestinationSelected,
    child: _source == null
        ? Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: _error == null
                ? const CoeloStatePanel(
                    title: 'Carregando modelo',
                    message: 'Aguarde enquanto consultamos a base original.',
                    loading: true,
                  )
                : CoeloStatePanel(
                    title: 'Não foi possível abrir o modelo',
                    message: 'Recarregue a lista e tente novamente.',
                    icon: Icons.error_outline_rounded,
                    actionLabel: 'Voltar',
                    onAction: widget.onCancel,
                  ),
          )
        : Form(
            key: _formKey,
            child: SuperadminFormFrame(
              viewportWidth: MediaQuery.sizeOf(context).width,
              scrollKey: const Key('access-profile-duplicate-scroll'),
              navigation: SuperadminFormStepNavigation(
                steps: const [
                  SuperadminFormStep(
                    label: 'Modelo original',
                    status: SuperadminFormStepStatus.complete,
                    enabled: false,
                  ),
                  SuperadminFormStep(
                    label: 'Nova cópia e auditoria',
                    status: SuperadminFormStepStatus.current,
                  ),
                ],
                currentIndex: 1,
                onStepSelected: (_) {},
              ),
              body: _body(),
              footer: _footer(),
            ),
          ),
  );

  Widget _body() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Container(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nova cópia', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              'Permissões e teto de alcance serão copiados de “${_source!.name}”. '
              'Vínculos e estado ativo nunca são herdados.',
            ),
            const SizedBox(height: CoeloSpacing.space5),
            CoeloFormTextField(
              controller: _name,
              labelText: 'Nome do novo modelo',
              prefixIcon: Icons.copy_all_outlined,
              maxLength: 120,
              enabled: !_saving,
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.length < 2) return 'Informe o nome do novo modelo.';
                return null;
              },
            ),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloFormTextField(
              controller: _reason,
              labelText: 'Motivo da duplicação',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
              maxLength: 500,
              enabled: !_saving,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe o motivo para a auditoria.'
                  : null,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _footer() => SuperadminFormActionFooter(
    onHeightChanged: (height) {
      if ((_footerHeight - height).abs() < .5) return;
      setState(() => _footerHeight = height);
    },
    tertiaryAction: TextButton(
      key: const Key('access-profile-duplicate-cancel'),
      onPressed: _saving ? null : widget.onCancel,
      child: const Text('Cancelar'),
    ),
    continuationActions: [
      FilledButton.icon(
        key: const Key('access-profile-duplicate-submit'),
        onPressed: _saving ? null : _duplicate,
        icon: _saving
            ? const SizedBox.square(
                dimension: CoeloSize.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.copy_all_outlined),
        label: const Text('Duplicar modelo'),
      ),
    ],
  );
}

String _newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String part(int start, int end) =>
      bytes.sublist(start, end).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${part(0, 4)}-${part(4, 6)}-${part(6, 8)}-${part(8, 10)}-${part(10, 16)}';
}
