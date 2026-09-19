import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../../app/widgets/superadmin_advanced_color_picker_dialog.dart';
import '../../../../shared/presentation/widgets/avatar_crop_dialog.dart';
import '../../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../auth/domain/logout_action.dart';
import '../../domain/account_profile.dart';
import '../account_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.controller,
    required this.logout,
    this.onDestinationSelected,
    super.key,
  });

  final AccountController controller;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _mobilePhone;
  late final TextEditingController _initials;
  AccountAvatar? _avatar;
  String? _imageError;
  String? _saveError;
  var _hasHydratedInitialProfile = false;
  var _hydratedProfileRevision = -1;
  var _updatingDraft = false;
  var _asyncGeneration = 0;
  final _ownedOverlays = <(NavigatorState, Route<dynamic>)>{};

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _email = TextEditingController();
    _mobilePhone = TextEditingController();
    _initials = TextEditingController();
    for (final field in [_firstName, _lastName, _email, _mobilePhone, _initials]) {
      field.addListener(_onDraftChanged);
    }
    _hydrateConfirmedState(widget.controller.state);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    _asyncGeneration += 1;
    _dismissOwnedOverlays();
    _clearDraft();
    _hydrateConfirmedState(widget.controller.state);
  }

  void _onDraftChanged() {
    if (!_updatingDraft && mounted) setState(() {});
  }

  void _hydrateConfirmedState(AccountControllerState state) {
    final profile = state.profile;
    if (profile == null) {
      if (state.phase == AccountControllerPhase.loading && _hasHydratedInitialProfile) {
        _clearDraft();
      }
      return;
    }
    if (_hasHydratedInitialProfile && state.profileRevision == _hydratedProfileRevision) return;
    if (_hasHydratedInitialProfile && state.updateOrigin == AccountProfileUpdateOrigin.save) {
      _hydratedProfileRevision = state.profileRevision;
      return;
    }
    _restoreConfirmed(profile, revision: state.profileRevision);
  }

  void _restoreConfirmed(AccountProfile profile, {required int revision}) {
    _updatingDraft = true;
    try {
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName;
      _email.text = profile.email;
      _mobilePhone.text = CoeloBrazilianPhoneInputFormatter.format(profile.mobilePhone);
      _initials.text = profile.avatar.initials;
    } finally {
      _updatingDraft = false;
    }
    _avatar = profile.avatar;
    _imageError = null;
    _saveError = null;
    _hasHydratedInitialProfile = true;
    _hydratedProfileRevision = revision;
  }

  void _clearDraft() {
    _hasHydratedInitialProfile = false;
    _hydratedProfileRevision = -1;
    _updatingDraft = true;
    try {
      _firstName.clear();
      _lastName.clear();
      _email.clear();
      _mobilePhone.clear();
      _initials.clear();
    } finally {
      _updatingDraft = false;
    }
    _avatar = null;
    _imageError = null;
    _saveError = null;
  }

  bool _isDirty(AccountProfile profile) {
    final avatar = _avatar;
    return _firstName.text != profile.firstName ||
        _lastName.text != profile.lastName ||
        _email.text != profile.email ||
        _mobilePhone.text != CoeloBrazilianPhoneInputFormatter.format(profile.mobilePhone) ||
        _initials.text != profile.avatar.initials ||
        avatar == null ||
        avatar.mode != profile.avatar.mode ||
        avatar.initials != profile.avatar.initials ||
        avatar.backgroundColor != profile.avatar.backgroundColor ||
        avatar.photoScale != profile.avatar.photoScale ||
        avatar.photoOffset != profile.avatar.photoOffset ||
        !listEquals(avatar.photoBytes, profile.avatar.photoBytes);
  }

  bool _matchesDraft({
    required String firstName,
    required String lastName,
    required String email,
    required String mobilePhone,
    required String initials,
    required AccountAvatar avatar,
  }) =>
      _firstName.text == firstName &&
      _lastName.text == lastName &&
      _email.text == email &&
      _mobilePhone.text == mobilePhone &&
      _initials.text == initials &&
      _sameAvatar(_avatar, avatar);

  bool _sameAvatar(AccountAvatar? first, AccountAvatar second) =>
      first != null &&
      first.mode == second.mode &&
      first.initials == second.initials &&
      first.backgroundColor == second.backgroundColor &&
      first.photoScale == second.photoScale &&
      first.photoOffset == second.photoOffset &&
      listEquals(first.photoBytes, second.photoBytes);

  @override
  void dispose() {
    _asyncGeneration += 1;
    _dismissOwnedOverlays();
    for (final field in [_firstName, _lastName, _email, _mobilePhone, _initials]) {
      field.removeListener(_onDraftChanged);
    }
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _mobilePhone.dispose();
    _initials.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final generation = _asyncGeneration;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
      allowMultiple: false,
      dialogTitle: 'Escolher foto de perfil',
    );
    if (!mounted || generation != _asyncGeneration || result == null) return;
    final file = result.files.single;
    if (file.size > 2 * 1024 * 1024) {
      setState(() => _imageError = 'A imagem deve ter no máximo 2 MB.');
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _imageError = 'Não foi possível ler esta imagem.');
      return;
    }
    final adjusted = await _showOwnedDialog<AvatarCropResult>(
      barrierColor: context.coeloScrim,
      builder: (context) => AvatarCropDialog(bytes: bytes),
    );
    if (adjusted != null && mounted && generation == _asyncGeneration) {
      setState(() {
        _imageError = null;
        _avatar = _avatar!.copyWith(
          mode: AccountAvatarMode.photo,
          photoBytes: adjusted.bytes,
          clearPhotoAsset: true,
          // The rasterizer already baked the chosen crop into these bytes.
          photoScale: 1,
          photoOffset: Offset.zero,
        );
      });
    }
  }

  Future<void> _chooseColor() async {
    final generation = _asyncGeneration;
    (NavigatorState, Route<dynamic>)? entry;
    final selected = await showSuperadminAdvancedColorPicker(
      context,
      initialColor: _avatar!.backgroundColor,
      title: 'Cor da sigla',
      onRouteCreated: (navigator, route) {
        entry = (navigator, route);
        _ownedOverlays.add(entry!);
      },
    );
    if (entry case final owned?) _ownedOverlays.remove(owned);
    if (selected != null && mounted && generation == _asyncGeneration) {
      setState(() => _avatar = _avatar!.copyWith(backgroundColor: selected));
    }
  }

  Future<T?> _showOwnedDialog<T>({required WidgetBuilder builder, Color? barrierColor}) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(context: context, builder: builder, barrierColor: barrierColor);
    final entry = (navigator, route as Route<dynamic>);
    _ownedOverlays.add(entry);
    try {
      final result = await navigator.push<T>(route);
      await route.completed;
      return result;
    } finally {
      _ownedOverlays.remove(entry);
    }
  }

  void _dismissOwnedOverlays() {
    for (final (navigator, route) in _ownedOverlays.toList(growable: false)) {
      if (route.isActive) navigator.removeRoute(route);
    }
    _ownedOverlays.clear();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || widget.controller.busy) return;
    final controller = widget.controller;
    final generation = _asyncGeneration;
    final submittedBaseRevision = controller.state.profileRevision;
    final normalizedInitials = _initials.text.trim().toUpperCase();
    _initials.value = TextEditingValue(
      text: normalizedInitials,
      selection: TextSelection.collapsed(offset: normalizedInitials.length),
    );
    final submittedFirstName = _firstName.text;
    final submittedLastName = _lastName.text;
    final submittedEmail = _email.text;
    final submittedMobilePhone = _mobilePhone.text;
    // D5 (18/09): o servidor grava em E.164; a tela exibe com mascara brasileira.
    final submittedMobilePhoneE164 = CoeloBrazilianPhoneInputFormatter.toE164(submittedMobilePhone);
    final submittedInitials = _initials.text;
    final submittedAvatar = _avatar!.copyWith(initials: normalizedInitials);
    _avatar = submittedAvatar;
    try {
      await controller.saveProfile(
        firstName: submittedFirstName,
        lastName: submittedLastName,
        email: submittedEmail,
        mobilePhone: submittedMobilePhoneE164,
        avatar: submittedAvatar,
      );
      if (mounted && generation == _asyncGeneration && identical(controller, widget.controller)) {
        setState(() {
          _saveError = null;
          final confirmed = controller.profile;
          if (confirmed != null &&
              controller.state.profileRevision > submittedBaseRevision &&
              confirmed.firstName == submittedFirstName.trim() &&
              confirmed.lastName == submittedLastName.trim() &&
              confirmed.mobilePhone == submittedMobilePhoneE164 &&
              _sameAvatar(confirmed.avatar, submittedAvatar) &&
              _matchesDraft(
                firstName: submittedFirstName,
                lastName: submittedLastName,
                email: submittedEmail,
                mobilePhone: submittedMobilePhone,
                initials: submittedInitials,
                avatar: submittedAvatar,
              )) {
            _restoreConfirmed(confirmed, revision: controller.state.profileRevision);
          }
        });
      }
    } catch (_) {
      if (mounted && generation == _asyncGeneration && identical(controller, widget.controller)) {
        setState(() => _saveError = 'Não foi possível salvar o perfil. Tente novamente.');
      }
    }
  }

  void _reset() {
    final profile = widget.controller.profile;
    if (profile == null) return;
    setState(() => _restoreConfirmed(profile, revision: widget.controller.state.profileRevision));
  }

  SuperadminHeaderProfile? _headerProfile(AccountProfile? profile) {
    if (profile == null) return null;
    final avatar = profile.avatar;
    return SuperadminHeaderProfile(
      name: '${profile.firstName} ${profile.lastName}'.trim(),
      role: profile.access.role,
      initials: avatar.initials,
      avatarBackgroundColor: avatar.backgroundColor,
      avatarImage: avatar.mode == AccountAvatarMode.photo && avatar.photoBytes != null
          ? MemoryImage(avatar.photoBytes!)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) => SuperadminShell(
      logout: widget.logout,
      title: 'Meu perfil',
      subtitle: 'Gerencie seus dados pessoais, acesso e segurança.',
      currentDestination: 'profile',
      onDestinationSelected: widget.onDestinationSelected,
      activityController: widget.controller.activities,
      headerProfile: _headerProfile(widget.controller.profile),
      // Decisao 7 do Owner: formulario de edicao sem o balao Mensagens (ele
      // cobria Salvar alteracoes em 1440x1000 na rota real, R04).
      showChatLauncher: false,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final profile = widget.controller.profile;
          _hydrateConfirmedState(widget.controller.state);
          if (profile == null || _avatar == null) {
            if (widget.controller.state.phase == AccountControllerPhase.failure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space5),
                  child: CoeloStatePanel(
                    title: 'Não foi possível carregar o perfil',
                    message: 'Tente novamente.',
                    icon: Icons.cloud_off_outlined,
                    actionLabel: 'Tentar novamente',
                    onAction: widget.controller.load,
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final dirty = _isDirty(profile);
          return ExcludeFocus(
            excluding: widget.controller.busy,
            child: AbsorbPointer(
              absorbing: widget.controller.busy,
              child: Form(
                key: _formKey,
                child: SuperadminFormFrame(
                  navigation: const SizedBox.shrink(),
                  viewportWidth: MediaQuery.sizeOf(context).width,
                  bodyMaxWidth: 1120,
                  scrollKey: const Key('account-profile-scroll'),
                  footer: SuperadminFormActionFooter(
                    tertiaryAction: TextButton.icon(
                      key: const Key('account-reset-profile'),
                      onPressed: widget.controller.busy || !dirty ? null : _reset,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Cancelar alterações'),
                    ),
                    continuationActions: [
                      FilledButton.icon(
                        key: const Key('account-save-profile'),
                        onPressed: widget.controller.busy || !dirty ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar alterações'),
                      ),
                    ],
                  ),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.controller.message ?? _saveError case final message?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
                          child: MaterialBanner(
                            content: Text(message),
                            actions: const [SizedBox.shrink()],
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide =
                              constraints.maxWidth >= 840 &&
                              MediaQuery.textScalerOf(context).scale(1) < 1.5;
                          final personal = _SectionCard(
                            cardKey: const Key('account-personal-card'),
                            title: 'Dados pessoais',
                            description: 'Sua identidade exibida no Superadmin.',
                            child: _PersonalDataForm(
                              firstName: _firstName,
                              lastName: _lastName,
                              email: _email,
                              mobilePhone: _mobilePhone,
                              initials: _initials,
                              avatar: _avatar!,
                              imageError: _imageError,
                              emailChange: profile.emailChange,
                              onPickPhoto: _pickPhoto,
                              onRemovePhoto: () => setState(
                                () => _avatar = _avatar!.copyWith(
                                  mode: AccountAvatarMode.initials,
                                  clearPhoto: true,
                                ),
                              ),
                              onChooseColor: _chooseColor,
                              onCancelEmailChange: widget.controller.cancelEmailChange,
                            ),
                          );
                          final access = _AccessCard(
                            cardKey: const Key('account-access-card'),
                            access: profile.access,
                          );
                          final security = _SecurityCard(
                            cardKey: const Key('account-security-card'),
                          );
                          return wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: personal),
                                    const SizedBox(width: CoeloSpacing.space5),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        key: const Key('account-profile-side-column'),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            access,
                                            const SizedBox(height: CoeloSpacing.space5),
                                            security,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    personal,
                                    const SizedBox(height: CoeloSpacing.space5),
                                    access,
                                    const SizedBox(height: CoeloSpacing.space5),
                                    security,
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _PersonalDataForm extends StatelessWidget {
  const _PersonalDataForm({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobilePhone,
    required this.initials,
    required this.avatar,
    required this.imageError,
    required this.emailChange,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onChooseColor,
    required this.onCancelEmailChange,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController mobilePhone;
  final TextEditingController initials;
  final AccountAvatar avatar;
  final String? imageError;
  final EmailChangeRequest? emailChange;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onChooseColor;
  final VoidCallback onCancelEmailChange;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _AvatarPreview(avatar: avatar),
          FilledButton.tonalIcon(
            key: const Key('account-avatar-picker'),
            onPressed: onPickPhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(avatar.photoBytes == null ? 'Escolher foto' : 'Trocar foto'),
          ),
          if (avatar.photoBytes != null)
            TextButton(onPressed: onRemovePhoto, child: const Text('Remover foto')),
        ],
      ),
      if (imageError != null) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          imageError!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: CoeloSpacing.space5),
      LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            CoeloFormTextField(
              fieldKey: const Key('account-first-name-field'),
              controller: firstName,
              labelText: 'Nome',
              prefixIcon: Icons.person_outline,
              validator: _requiredName,
            ),
            CoeloFormTextField(
              fieldKey: const Key('account-last-name-field'),
              controller: lastName,
              labelText: 'Sobrenome',
              prefixIcon: Icons.badge_outlined,
              validator: _requiredName,
            ),
          ];
          final compact =
              constraints.maxWidth < 600 || MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          return !compact
              ? Row(
                  children: [
                    Expanded(child: fields.first),
                    const SizedBox(width: CoeloSpacing.space3),
                    Expanded(child: fields.last),
                  ],
                )
              : Column(
                  children: [
                    fields.first,
                    const SizedBox(height: CoeloSpacing.space4),
                    fields.last,
                  ],
                );
        },
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        fieldKey: const Key('account-email-field'),
        controller: email,
        labelText: 'E-mail',
        prefixIcon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        validator: _validateEmail,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        fieldKey: const Key('account-mobile-phone-field'),
        controller: mobilePhone,
        labelText: 'Celular',
        prefixIcon: Icons.smartphone_outlined,
        keyboardType: TextInputType.phone,
        hintText: '+55 (11) 91234-5678',
        // D5 (18/09): mascara brasileira na digitacao; o servidor exige E.164
        // (+55DDD9NNNNNNNN) e responde invalid_account_mobile_phone fora disso.
        inputFormatters: const [CoeloBrazilianPhoneInputFormatter()],
        validator: _validateMobilePhone,
      ),
      if (emailChange?.status == EmailChangeStatus.pending) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${emailChange!.requestedEmail} · Aguardando aprovação'),
            TextButton(onPressed: onCancelEmailChange, child: const Text('Cancelar solicitação')),
          ],
        ),
      ],
      const SizedBox(height: CoeloSpacing.space5),
      Text('Avatar sem foto', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space3),
      Builder(
        builder: (context) {
          final initialsField = CoeloFormTextField(
            fieldKey: const Key('account-initials-field'),
            controller: initials,
            labelText: 'Sigla',
            hintText: 'OC',
            prefixIcon: Icons.text_fields_rounded,
            validator: (value) => AccountAvatar.validateInitials(value ?? ''),
          );
          final chooseColorButton = OutlinedButton.icon(
            key: const Key('account-avatar-color-picker'),
            onPressed: onChooseColor,
            icon: DecoratedBox(
              decoration: BoxDecoration(
                color: avatar.backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: const SizedBox.square(dimension: CoeloSize.iconMd),
            ),
            label: const Text('Escolher cor'),
          );
          final compact =
              MediaQuery.sizeOf(context).width < 600 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    initialsField,
                    const SizedBox(height: CoeloSpacing.space3),
                    Align(alignment: Alignment.centerLeft, child: chooseColorButton),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: initialsField),
                    const SizedBox(width: CoeloSpacing.space3),
                    SizedBox(height: 52, child: chooseColorButton),
                  ],
                );
        },
      ),
      const SizedBox(height: CoeloSpacing.space2),
      const Text('PNG, JPG ou WebP, até 2 MB. A sigla aceita uma ou duas letras.'),
    ],
  );
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.avatar});
  final AccountAvatar avatar;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: ColoredBox(
      color: avatar.backgroundColor,
      child: SizedBox.square(
        key: const Key('account-avatar-initials'),
        dimension: 84,
        child: avatar.mode == AccountAvatarMode.photo && avatar.photoBytes != null
            ? Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(avatar.photoOffset.dx, avatar.photoOffset.dy, 0, 1)
                  ..scaleByDouble(avatar.photoScale, avatar.photoScale, 1, 1),
                alignment: Alignment.center,
                child: Image.memory(avatar.photoBytes!, fit: BoxFit.cover),
              )
            : Center(
                child: Text(
                  avatar.initials,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AccountAvatar.foregroundFor(avatar.backgroundColor),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    ),
  );
}

class _AccessCard extends StatefulWidget {
  const _AccessCard({required this.access, required this.cardKey});
  final AccountAccessSummary access;
  final Key cardKey;

  @override
  State<_AccessCard> createState() => _AccessCardState();
}

class _AccessCardState extends State<_AccessCard> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final capabilities = widget.access.capabilities
        .where((item) => item.toLowerCase().contains(query))
        .toSet()
        .toList();
    final groups = <String, List<AccountCapabilityDetail>>{};
    for (final item in widget.access.capabilityDetails) {
      if ('${item.label} ${item.moduleLabel} ${item.scopeLabel}'.toLowerCase().contains(query)) {
        (groups[item.groupKey] ??= []).add(item);
      }
    }
    final hasDetails = widget.access.capabilityDetails.isNotEmpty;
    return _SectionCard(
      cardKey: widget.cardKey,
      title: 'Meu acesso',
      description: 'Somente leitura. Permissões são administradas por governança.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.access.role, style: Theme.of(context).textTheme.titleMedium),
          Text(widget.access.mfaEnabled ? 'MFA configurada' : 'MFA fora do MVP'),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloSearchField(
            key: const Key('account-access-search'),
            controller: _search,
            semanticLabel: 'Buscar em Meu acesso',
            hintText: 'Buscar permissão',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: CoeloSpacing.space10 * 10),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: const Key('account-access-scroll'),
                controller: _scroll,
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasDetails ? groups.isEmpty : capabilities.isEmpty)
                      const Text('Nenhuma permissão encontrada.'),
                    if (hasDetails)
                      for (final group in groups.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                          child: Text(
                            group.first.groupLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        for (final item in group)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: CoeloSpacing.space3,
                              right: CoeloSpacing.space3,
                            ),
                            child: Text(item.label),
                          ),
                      ],
                    if (!hasDetails)
                      for (final capability in capabilities)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: CoeloSpacing.space3,
                            right: CoeloSpacing.space3,
                          ),
                          child: Text(capability),
                        ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          const Text(
            'Uma permissão não indica que a função já está disponível. Importações e exportações gerais seguem adiadas; respostas de formulários podem ser exportadas em XLSX.',
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.cardKey});
  final Key cardKey;

  @override
  Widget build(BuildContext context) => _SectionCard(
    cardKey: cardKey,
    title: 'Segurança',
    description: 'Alteração de senha indisponível nesta versão.',
    child: Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const Key('account-password-unavailable'),
        onPressed: null,
        icon: const Icon(Icons.lock_outline_rounded),
        label: const Text('Indisponível'),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.cardKey,
    required this.title,
    required this.description,
    required this.child,
  });
  final Key cardKey;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: cardKey,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          child,
        ],
      ),
    ),
  );
}

String? _requiredName(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null;

String? _validateMobilePhone(String? value) {
  final e164 = CoeloBrazilianPhoneInputFormatter.toE164(value ?? '');
  if (e164.isEmpty) return 'Informe o celular.';
  return _mobilePhoneE164.hasMatch(e164)
      ? null
      : 'Informe um celular válido: +55 (DDD) 9XXXX-XXXX.';
}

/// Celular brasileiro em E.164: +55, DDD sem zero e nove digitos iniciados por 9.
final RegExp _mobilePhoneE164 = RegExp(r'^\+55[1-9][1-9]9[0-9]{8}$');

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe o e-mail.';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Informe um e-mail válido.';
}
