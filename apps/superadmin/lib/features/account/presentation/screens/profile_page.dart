import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../../app/widgets/superadmin_advanced_color_picker_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _firstName = TextEditingController(text: profile?.firstName);
    _lastName = TextEditingController(text: profile?.lastName);
    _email = TextEditingController(text: profile?.email);
    _mobilePhone = TextEditingController(text: profile?.mobilePhone);
    _initials = TextEditingController(text: profile?.avatar.initials);
    _avatar = profile?.avatar;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _mobilePhone.dispose();
    _initials.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
      allowMultiple: false,
      dialogTitle: 'Escolher foto de perfil',
    );
    if (!mounted || result == null) return;
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
    final adjusted = await showDialog<_AvatarCropResult>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _AvatarCropDialog(bytes: bytes),
    );
    if (adjusted != null && mounted) {
      setState(() {
        _imageError = null;
        _avatar = _avatar!.copyWith(
          mode: AccountAvatarMode.photo,
          photoBytes: adjusted.bytes,
          photoScale: adjusted.scale,
          photoOffset: adjusted.offset,
        );
      });
    }
  }

  Future<void> _chooseColor() async {
    final selected = await showSuperadminAdvancedColorPicker(
      context,
      initialColor: _avatar!.backgroundColor,
      title: 'Cor da sigla',
    );
    if (selected != null && mounted) {
      setState(() => _avatar = _avatar!.copyWith(backgroundColor: selected));
    }
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || widget.controller.busy) return;
    final normalizedInitials = _initials.text.trim().toUpperCase();
    _initials.value = TextEditingValue(
      text: normalizedInitials,
      selection: TextSelection.collapsed(offset: normalizedInitials.length),
    );
    await widget.controller.saveProfile(
      firstName: _firstName.text,
      lastName: _lastName.text,
      email: _email.text,
      mobilePhone: _mobilePhone.text,
      avatar: _avatar!.copyWith(initials: normalizedInitials),
    );
    if (mounted) setState(() {});
  }

  void _reset() {
    final reset = _avatar!.resetFor(_firstName.text, _lastName.text);
    _initials.value = TextEditingValue(
      text: reset.initials,
      selection: TextSelection.collapsed(offset: reset.initials.length),
    );
    setState(() {
      _imageError = null;
      _avatar = reset;
    });
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Meu perfil',
    subtitle: 'Gerencie seus dados pessoais, acesso e segurança.',
    currentDestination: 'profile',
    onDestinationSelected: widget.onDestinationSelected,
    activityController: widget.controller.activities,
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final profile = widget.controller.profile;
        if (profile == null || _avatar == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CoeloSpacing.space5),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.controller.message case final message?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
                        child: MaterialBanner(
                          content: Text(message),
                          actions: const [SizedBox.shrink()],
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 840;
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
                          controller: widget.controller,
                        );
                        return wide
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                            Expanded(child: security),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                    const SizedBox(height: CoeloSpacing.space5),
                    _FormFooter(busy: widget.controller.busy, onReset: _reset, onSave: _save),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
      Builder(
        builder: (context) {
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
          return MediaQuery.sizeOf(context).width >= 600
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
      ),
      if (emailChange?.status == EmailChangeStatus.pending) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Row(
          children: [
            Expanded(child: Text('${emailChange!.requestedEmail} · Aguardando aprovação')),
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

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.access, required this.cardKey});
  final AccountAccessSummary access;
  final Key cardKey;

  @override
  Widget build(BuildContext context) => _SectionCard(
    cardKey: cardKey,
    title: 'Meu acesso',
    description: 'Somente leitura. Permissões são administradas por governança.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(access.role),
            subtitle: Text(access.mfaEnabled ? 'MFA configurada' : 'MFA pendente'),
          ),
        ),
        for (final capability in access.capabilities)
          Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text(capability),
            ),
          ),
      ],
    ),
  );
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.controller, required this.cardKey});
  final AccountController controller;
  final Key cardKey;

  @override
  Widget build(BuildContext context) => _SectionCard(
    cardKey: cardKey,
    title: 'Segurança',
    description: 'Atualize sua senha de acesso.',
    child: Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => _PasswordDialog(controller: controller),
        ),
        icon: const Icon(Icons.lock_outline_rounded),
        label: const Text('Alterar senha'),
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

class _FormFooter extends StatelessWidget {
  const _FormFooter({required this.busy, required this.onReset, required this.onSave});
  final bool busy;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resetButton = OutlinedButton.icon(
            key: const Key('account-reset-profile'),
            onPressed: busy ? null : onReset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Redefinir'),
          );
          final saveButton = FilledButton.icon(
            key: const Key('account-save-profile'),
            onPressed: busy ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar alterações'),
          );
          return constraints.maxWidth < 480
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    resetButton,
                    const SizedBox(height: CoeloSpacing.space3),
                    saveButton,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [resetButton, saveButton],
                );
        },
      ),
    ),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.controller});
  final AccountController controller;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirmation = TextEditingController();
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 600 || MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final cancelButton = OutlinedButton(
      key: const Key('account-password-cancel'),
      onPressed: Navigator.of(context).pop,
      child: const Text('Cancelar'),
    );
    final submitButton = FilledButton(
      key: const Key('account-password-submit'),
      onPressed: () async {
        final result = await widget.controller.changePassword(
          currentPassword: current.text,
          newPassword: next.text,
          confirmation: confirmation.text,
        );
        if (!context.mounted) return;
        if (result == null) {
          Navigator.of(context).pop();
        } else {
          setState(() => error = result);
        }
      },
      child: const Text('Alterar senha'),
    );
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrollable: true,
      title: Row(
        children: [
          const Expanded(child: Text('Alterar senha')),
          IconButton(
            key: const Key('account-password-close'),
            tooltip: 'Fechar alteração de senha',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Theme.of(context).colorScheme.error,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(CoeloSize.touchMin),
              hoverColor: Theme.of(context).colorScheme.errorContainer,
              focusColor: Theme.of(context).colorScheme.errorContainer,
              highlightColor: Colors.transparent,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoeloFormTextField(
              controller: current,
              labelText: 'Senha atual',
              prefixIcon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloFormTextField(
              controller: next,
              labelText: 'Nova senha',
              prefixIcon: Icons.password_rounded,
              obscureText: true,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloFormTextField(
              controller: confirmation,
              labelText: 'Confirmar nova senha',
              prefixIcon: Icons.password_rounded,
              obscureText: true,
              errorText: error,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            const Text('Senha atual do protótipo: coelo-demo'),
          ],
        ),
      ),
      actions: [
        compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cancelButton,
                  const SizedBox(height: CoeloSpacing.space3),
                  submitButton,
                ],
              )
            : Row(
                children: [
                  Expanded(child: cancelButton),
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(child: submitButton),
                ],
              ),
      ],
    );
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.bytes});
  final Uint8List bytes;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final transformation = TransformationController();
  double zoom = 1;

  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }

  void reset() {
    transformation.value = Matrix4.identity();
    setState(() => zoom = 1);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    title: const Text('Ajustar foto'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Arraste e ajuste o zoom. A área dentro do círculo será exibida.'),
          const SizedBox(height: CoeloSpacing.space4),
          ClipOval(
            child: SizedBox.square(
              dimension: 300,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.scrim,
                child: InteractiveViewer(
                  key: const Key('account-avatar-crop-view'),
                  transformationController: transformation,
                  minScale: 1,
                  maxScale: 4,
                  boundaryMargin: EdgeInsets.zero,
                  constrained: true,
                  child: Image.memory(widget.bytes, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          Slider(
            value: zoom,
            min: 1,
            max: 4,
            divisions: 30,
            label: '${zoom.toStringAsFixed(1)}×',
            onChanged: (value) {
              setState(() => zoom = value);
              transformation.value = Matrix4.diagonal3Values(value, value, 1);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: reset, child: const Text('Redefinir')),
      OutlinedButton(onPressed: Navigator.of(context).pop, child: const Text('Cancelar')),
      FilledButton(
        onPressed: () {
          final matrix = transformation.value;
          Navigator.of(context).pop(
            _AvatarCropResult(
              bytes: widget.bytes,
              scale: matrix.entry(0, 0),
              offset: Offset(matrix.entry(0, 3), matrix.entry(1, 3)),
            ),
          );
        },
        child: const Text('Aplicar'),
      ),
    ],
  );
}

class _AvatarCropResult {
  const _AvatarCropResult({required this.bytes, required this.scale, required this.offset});

  final Uint8List bytes;
  final double scale;
  final Offset offset;
}

String? _requiredName(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null;

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe o e-mail.';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Informe um e-mail válido.';
}
