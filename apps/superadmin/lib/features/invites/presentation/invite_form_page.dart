import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_invite.dart';
import 'invite_form_sections.dart';
import 'invite_request_id.dart';

enum _OptionsState { loading, ready, failure, unauthorized }

const _stepLabels = ['Contexto e perfil', 'Destinatário', 'Entrega', 'Revisão'];

final class InviteFormPage extends StatefulWidget {
  const InviteFormPage({
    required this.repository,
    required this.onCancel,
    this.onSent,
    this.logout = unavailableSuperadminLogout,
    this.onDestinationSelected,
    super.key,
  });

  final InviteRepository repository;
  final VoidCallback onCancel;
  final ValueChanged<PlatformInvite>? onSent;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<InviteFormPage> createState() => _InviteFormPageState();
}

final class _InviteFormPageState extends State<InviteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _contextSearchController = TextEditingController();
  final _recipientSearchController = TextEditingController();
  final _emailController = TextEditingController();
  Timer? _searchDebounce;
  InviteFormOptions _options = const InviteFormOptions(scopes: [], profiles: [], recipients: []);
  _OptionsState _optionsState = _OptionsState.loading;
  InviteScopeOption? _scope;
  InviteProfileOption? _profile;
  InviteRecipientOption? _recipient;
  InviteRecipientMode _recipientMode = InviteRecipientMode.person;
  Set<InviteChannel> _channels = {};
  int _expiresInHours = 48;
  int _step = 0;
  int _furthestStep = 0;
  final Set<int> _errorSteps = {};
  bool _submitting = false;
  InviteCommandResult? _result;
  double _footerHeight = 0;
  var _optionsEpoch = 0;
  bool _refreshingOptions = false;
  String? _issueRequestId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOptions());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _contextSearchController.dispose();
    _recipientSearchController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions({bool showLoading = true}) async {
    final epoch = ++_optionsEpoch;
    if (mounted) {
      setState(() {
        _refreshingOptions = true;
        if (showLoading) _optionsState = _OptionsState.loading;
        if (!showLoading) {
          _options = InviteFormOptions(
            scopes: _step == 0 ? [?_scope] : _options.scopes,
            profiles: _step == 1 ? _options.profiles : const [],
            recipients: const [],
          );
        }
      });
    }
    try {
      final scope = _scope?.scope;
      final options = await widget.repository.fetchOptions(
        InviteOptionsQuery(
          search: _step == 1 ? _recipientSearchController.text : _contextSearchController.text,
          institutionId: scope?.institutionId,
          unitId: scope?.unitId,
          groupId: scope?.groupId,
          pageSize: 100,
        ),
      );
      if (!mounted || epoch != _optionsEpoch) return;
      setState(() {
        _options = options;
        _optionsState = _OptionsState.ready;
        _refreshingOptions = false;
        if (_profile != null && !options.profiles.any((value) => value.id == _profile!.id)) {
          _profile = null;
        }
        if (_recipient != null &&
            !options.recipients.any((value) => value.personId == _recipient!.personId)) {
          _recipient = null;
        }
      });
    } on InviteUnauthorizedException {
      if (mounted && epoch == _optionsEpoch) {
        setState(() {
          _options = const InviteFormOptions(scopes: [], profiles: [], recipients: []);
          _optionsState = _OptionsState.unauthorized;
          _refreshingOptions = false;
        });
      }
    } on Object {
      if (mounted && epoch == _optionsEpoch) {
        setState(() {
          _options = const InviteFormOptions(scopes: [], profiles: [], recipients: []);
          _optionsState = _OptionsState.failure;
          _refreshingOptions = false;
        });
      }
    }
  }

  void _searchOptions(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_loadOptions(showLoading: false)),
    );
  }

  void _selectScope(InviteScopeOption? value) {
    setState(() {
      _scope = value;
      _profile = null;
      _recipient = null;
      _contextSearchController.clear();
    });
    unawaited(_loadOptions(showLoading: false));
  }

  bool _stepValid(int step) => switch (step) {
    0 => _scope != null && _profile != null,
    1 =>
      _recipientMode == InviteRecipientMode.person
          ? _recipient != null
          : validateInviteEmail(_emailController.text) == null,
    2 => _channels.isNotEmpty,
    _ => _scope != null && _profile != null && _channels.isNotEmpty,
  };

  void _continue() {
    if (!_stepValid(_step) || !(_formKey.currentState?.validate() ?? true)) {
      setState(() => _errorSteps.add(_step));
      return;
    }
    final leavingScopeStep = _step == 0;
    setState(() {
      _errorSteps.remove(_step);
      if (_step < _stepLabels.length - 1) {
        _step++;
        _furthestStep = _step > _furthestStep ? _step : _furthestStep;
      }
    });
    if (leavingScopeStep) unawaited(_loadOptions(showLoading: false));
  }

  Future<void> _issue() async {
    if (!_stepValid(0) || !_stepValid(1) || !_stepValid(2)) {
      setState(() {
        _errorSteps
          ..clear()
          ..addAll([
            for (var index = 0; index < 3; index++)
              if (!_stepValid(index)) index,
          ]);
        _step = _errorSteps.first;
      });
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await widget.repository.issue(
        InviteIssueCommand(
          requestId: _issueRequestId ??= newInviteRequestId(),
          scope: _scope!.scope,
          profileId: _profile!.id,
          recipient: _recipientMode == InviteRecipientMode.person
              ? InviteRecipientDraft(personId: _recipient!.personId)
              : InviteRecipientDraft(email: _emailController.text.trim()),
          channels: _channels,
          expiresInHours: _expiresInHours,
        ),
      );
      if (mounted) {
        setState(() {
          _result = result;
          _issueRequestId = null;
        });
      }
    } on InviteConflictException {
      _issueRequestId = null;
      if (mounted) _feedback('Este convite já foi processado com dados diferentes.', error: true);
    } on InviteUnauthorizedException {
      _issueRequestId = null;
      if (mounted) _feedback('Sua autorização mudou. Recarregue e tente novamente.', error: true);
    } on Object {
      if (mounted) _feedback('Não foi possível emitir o convite.', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _feedback(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? colors.error : null));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = ColoredBox(
        key: const Key('invite-form-page-surface'),
        color: Theme.of(context).colorScheme.surface,
        child: switch (_optionsState) {
          _OptionsState.loading => const Center(
            child: CoeloStatePanel(
              title: 'Carregando opções',
              message: 'Buscando contextos, perfis e Pessoas autorizadas.',
              icon: Icons.hourglass_top_rounded,
            ),
          ),
          _OptionsState.failure => Center(
            child: CoeloStatePanel(
              title: 'Opções indisponíveis',
              message: 'Não foi possível carregar os dados do convite.',
              icon: Icons.error_outline_rounded,
              actionLabel: 'Tentar novamente',
              onAction: _loadOptions,
            ),
          ),
          _OptionsState.unauthorized => const Center(
            child: CoeloStatePanel(
              title: 'Acesso não autorizado',
              message: 'Seu contexto atual não permite emitir convites.',
              icon: Icons.lock_outline_rounded,
            ),
          ),
          _OptionsState.ready => SuperadminFormFrame(
            viewportWidth: constraints.maxWidth,
            scrollKey: const Key('invite-form-scroll'),
            navigation: _navigation(),
            body: Form(
              key: _formKey,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : CoeloMotion.fast,
                child: KeyedSubtree(key: ValueKey((_step, _result != null)), child: _body()),
              ),
            ),
            footer: _footer(),
          ),
        },
      );
      return SuperadminShell(
        logout: widget.logout,
        title: 'Novo convite',
        subtitle: 'Defina contexto, perfil, destinatário e entrega.',
        currentDestination: 'invites',
        onDestinationSelected: widget.onDestinationSelected,
        chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
        child: content,
      );
    },
  );

  Widget _navigation() => SuperadminFormStepNavigation(
    steps: [
      for (var index = 0; index < _stepLabels.length; index++)
        SuperadminFormStep(
          label: _stepLabels[index],
          status: _errorSteps.contains(index)
              ? SuperadminFormStepStatus.error
              : index == _step
              ? SuperadminFormStepStatus.current
              : index < _furthestStep
              ? SuperadminFormStepStatus.complete
              : SuperadminFormStepStatus.incomplete,
          enabled: !_submitting && _result == null && index <= _furthestStep,
        ),
    ],
    currentIndex: _step,
    onStepSelected: (index) {
      if (index <= _furthestStep && _result == null) {
        setState(() => _step = index);
        if (index <= 1) unawaited(_loadOptions(showLoading: false));
      }
    },
  );

  Widget _body() {
    final result = _result;
    if (result != null) return InviteDeliveryResult(result: result);
    if (_step == 0 && _options.scopes.isEmpty) {
      final hasSearch = _contextSearchController.text.trim().isNotEmpty;
      return CoeloStatePanel(
        title: hasSearch ? 'Nenhum contexto encontrado' : 'Nenhum contexto disponível',
        message: hasSearch
            ? 'Ajuste a busca para consultar seus contextos autorizados.'
            : 'Não há instituições, unidades ou turmas autorizadas para este convite.',
        icon: hasSearch ? Icons.search_off_rounded : Icons.account_tree_outlined,
        actionLabel: hasSearch ? 'Limpar busca' : null,
        onAction: hasSearch
            ? () {
                _contextSearchController.clear();
                unawaited(_loadOptions(showLoading: false));
              }
            : null,
      );
    }
    return switch (_step) {
      0 => InviteScopeProfileSection(
        options: _options,
        scope: _scope,
        profile: _profile,
        searchController: _contextSearchController,
        loading: _refreshingOptions,
        showErrors: _errorSteps.contains(0),
        onSearchChanged: _searchOptions,
        onScopeChanged: _selectScope,
        onProfileChanged: (value) => setState(() => _profile = value),
      ),
      1 => InviteRecipientSection(
        options: _options,
        mode: _recipientMode,
        recipient: _recipient,
        emailController: _emailController,
        searchController: _recipientSearchController,
        onSearchChanged: _searchOptions,
        showErrors: _errorSteps.contains(1),
        loading: _refreshingOptions,
        onModeChanged: (value) => setState(() {
          _recipientMode = value;
          _recipient = null;
          _emailController.clear();
        }),
        onRecipientChanged: (value) => setState(() => _recipient = value),
      ),
      2 => InviteDeliverySection(
        channels: _channels,
        expiresInHours: _expiresInHours,
        showErrors: _errorSteps.contains(2),
        onChannelsChanged: (value) => setState(() => _channels = value),
        onExpiryChanged: (value) => setState(() => _expiresInHours = value),
      ),
      _ => InviteReviewSection(
        scope: _scope!,
        profile: _profile!,
        recipientLabel: _recipientMode == InviteRecipientMode.person
            ? _recipient!.label
            : maskInviteRecipient(_emailController.text.trim(), InviteChannel.email),
        channels: _channels,
        expiresInHours: _expiresInHours,
      ),
    };
  }

  Widget _footer() {
    if (_result != null) {
      return SuperadminFormActionFooter(
        surfaceKey: const Key('invite-form-footer-surface'),
        onHeightChanged: _setFooterHeight,
        tertiaryAction: TextButton(onPressed: null, child: const Text('Convite emitido')),
        continuationActions: [
          FilledButton(
            key: const Key('invite-form-done'),
            onPressed: _finish,
            child: const Text('Concluir'),
          ),
        ],
      );
    }
    final primary = _step == _stepLabels.length - 1
        ? FilledButton(
            key: const Key('invite-form-send'),
            onPressed: _submitting ? null : _issue,
            child: _submitting
                ? const SizedBox.square(
                    dimension: CoeloSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Emitir convite'),
          )
        : FilledButton(
            key: const Key('invite-form-continue'),
            onPressed: _submitting ? null : _continue,
            child: const Text('Continuar'),
          );
    return SuperadminFormActionFooter(
      surfaceKey: const Key('invite-form-footer-surface'),
      onHeightChanged: _setFooterHeight,
      tertiaryAction: TextButton(
        key: const Key('invite-form-cancel'),
        onPressed: _submitting ? null : widget.onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (_step > 0)
          OutlinedButton(
            key: const Key('invite-form-previous'),
            onPressed: _submitting
                ? null
                : () {
                    setState(() => _step--);
                    if (_step <= 1) unawaited(_loadOptions(showLoading: false));
                  },
            child: const Text('Anterior'),
          ),
        primary,
      ],
    );
  }

  void _finish() {
    final result = _result;
    if (result != null) widget.onSent?.call(result.invite);
  }

  void _setFooterHeight(double value) {
    if (!mounted || (_footerHeight - value).abs() < 0.5) return;
    setState(() => _footerHeight = value);
  }
}
