import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../principal_shared/domain/principal_runtime_context.dart';
import '../../profile_about/domain/profile_about_repository.dart';
import '../../profile_about/presentation/profile_about_editor.dart';

/// Production composition root for `principal.profile-edit`.
///
/// Editing is the authorized About page of the current Principal context. The
/// subject is derived from the server-authorized context, never from the URL.
/// Success is only shown after the server accepts the command, and the page is
/// re-read from the server afterwards so the UI reflects persisted state.
final class PrincipalProfileEditPage extends StatefulWidget {
  const PrincipalProfileEditPage({
    required this.runtimeContext,
    required this.repository,
    this.onClose,
    this.onSaved,
    super.key,
  });

  final PrincipalRuntimeContext runtimeContext;
  final ProfileAboutRepository repository;
  final VoidCallback? onClose;
  final VoidCallback? onSaved;

  @override
  State<PrincipalProfileEditPage> createState() => _PrincipalProfileEditPageState();
}

sealed class _EditState {
  const _EditState();
}

final class _Loading extends _EditState {
  const _Loading();
}

final class _Editing extends _EditState {
  const _Editing(this.controller);
  final ProfileAboutEditorController controller;
}

final class _Failed extends _EditState {
  const _Failed();
}

final class _Denied extends _EditState {
  const _Denied();
}

final class _PrincipalProfileEditPageState extends State<PrincipalProfileEditPage> {
  _EditState _state = const _Loading();
  var _generation = 0;
  var _reloading = false;
  String? _conflictMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrincipalProfileEditPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        oldWidget.runtimeContext.membershipId == widget.runtimeContext.membershipId &&
        oldWidget.runtimeContext.personId == widget.runtimeContext.personId &&
        oldWidget.runtimeContext.institutionId == widget.runtimeContext.institutionId &&
        oldWidget.runtimeContext.unitId == widget.runtimeContext.unitId &&
        oldWidget.runtimeContext.groupId == widget.runtimeContext.groupId) {
      return;
    }
    // A changed or revoked context must not keep editing the previous subject's
    // draft: the page reloads and the stale controller goes away.
    //
    // Membership and person are compared as well as the scope. Two contexts can
    // name the same institution, unit and group and still be a different actor
    // or a different role, and the authorization to manage this About belongs
    // to the membership, not to the scope. Reloading is the fail-closed side:
    // the server answers again for whoever is now in context.
    _replace(const _Loading());
    _load();
  }

  @override
  void dispose() {
    _generation += 1;
    if (_state case _Editing(:final controller)) controller.dispose();
    super.dispose();
  }

  ProfileAboutSubjectRef get _subject {
    final context = widget.runtimeContext;
    final unitId = context.unitId;
    final groupId = context.groupId;
    if (unitId != null && groupId != null) {
      return ProfileAboutSubjectRef(
        type: ProfileAboutSubjectType.group,
        institutionId: context.institutionId,
        unitId: unitId,
        groupId: groupId,
      );
    }
    if (unitId != null) {
      return ProfileAboutSubjectRef(
        type: ProfileAboutSubjectType.unit,
        institutionId: context.institutionId,
        unitId: unitId,
      );
    }
    return ProfileAboutSubjectRef(
      type: ProfileAboutSubjectType.institution,
      institutionId: context.institutionId,
    );
  }

  void _replace(_EditState next) {
    if (_state case _Editing(:final controller)) {
      if (next is! _Editing || !identical(next.controller, controller)) controller.dispose();
    }
    setState(() => _state = next);
  }

  Future<bool> _load() async {
    final generation = ++_generation;
    setState(() {
      _conflictMessage = null;
      // While editing, the page deliberately keeps the current content on
      // screen instead of flashing a spinner. Without this flag the reload
      // action would look inert until the server answered, and a second tap
      // would start another read.
      _reloading = true;
    });
    if (_state is! _Editing) setState(() => _state = const _Loading());
    try {
      final page = await widget.repository.load(_subject);
      if (!mounted || generation != _generation) return false;
      _replace(
        _Editing(ProfileAboutEditorController(page: page ?? ProfileAboutPage.empty(_subject))),
      );
      return true;
    } on ProfileAboutUnauthorizedException {
      if (!mounted || generation != _generation) return false;
      _replace(const _Denied());
      return false;
    } on Object {
      if (!mounted || generation != _generation) return false;
      _replace(const _Failed());
      return false;
    } finally {
      if (mounted && generation == _generation) setState(() => _reloading = false);
    }
  }

  Future<void> _save(ProfileAboutEditorController controller) async {
    if (controller.status == ProfileAboutEditorStatus.saving) return;
    final generation = _generation;
    controller.status = ProfileAboutEditorStatus.saving;
    setState(() => _conflictMessage = null);
    try {
      await widget.repository.save(controller.page, requestId: newProfileAboutRequestId());
      if (!mounted || generation != _generation) return;
      // Confirm only when this reload was accepted. A denial, read failure
      // or context swap must not announce success in the current context.
      final reloaded = await _load();
      if (!mounted || !reloaded) return;
      widget.onSaved?.call();
      _announce('Sobre salvo.');
    } on ProfileAboutConflictException {
      if (!mounted || generation != _generation) return;
      controller.status = ProfileAboutEditorStatus.ready;
      setState(
        () => _conflictMessage =
            'Este Sobre mudou no servidor desde que você abriu. Recarregue antes de salvar.',
      );
    } on ProfileAboutUnauthorizedException {
      if (!mounted || generation != _generation) return;
      _replace(const _Denied());
    } on Object {
      if (!mounted || generation != _generation) return;
      controller.status = ProfileAboutEditorStatus.ready;
      setState(() => _conflictMessage = 'Não foi possível salvar agora. Tente novamente.');
    }
  }

  void _announce(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Editar perfil'),
      leading: widget.onClose == null
          ? null
          : IconButton(
              key: const Key('principal-profile-edit-close'),
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onClose,
            ),
    ),
    body: switch (_state) {
      _Loading() => const Center(
        child: CircularProgressIndicator(key: Key('principal-profile-edit-loading')),
      ),
      _Denied() => const CoeloStatePanel(
        key: Key('principal-profile-edit-unauthorized'),
        title: 'Sem permissão',
        message: 'Você não pode editar o Sobre neste contexto.',
        icon: Icons.lock_outline_rounded,
      ),
      _Failed() => CoeloStatePanel(
        key: const Key('principal-profile-edit-error'),
        title: 'Não foi possível carregar',
        message: 'Não conseguimos abrir o Sobre deste contexto agora.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      ),
      _Editing(:final controller) => Column(
        children: [
          if (_conflictMessage case final message?)
            Padding(
              key: const Key('principal-profile-edit-conflict'),
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: ProfileAboutEditor(controller: controller),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              // Wrap, not Row: at 200% text the two actions do not fit side by
              // side on a narrow screen and must reflow instead of overflowing.
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: CoeloSpacing.space3,
                runSpacing: CoeloSpacing.space2,
                children: [
                  TextButton(
                    key: const Key('principal-profile-edit-reload'),
                    onPressed: _reloading ? null : _load,
                    child: Text(_reloading ? 'Recarregando…' : 'Recarregar'),
                  ),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => FilledButton(
                      key: const Key('principal-profile-edit-save'),
                      onPressed: controller.status == ProfileAboutEditorStatus.saving
                          ? null
                          : () => _save(controller),
                      child: Text(
                        controller.status == ProfileAboutEditorStatus.saving
                            ? 'Salvando…'
                            : 'Salvar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    },
  );
}
