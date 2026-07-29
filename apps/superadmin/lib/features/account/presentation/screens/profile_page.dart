import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../../shared/presentation/widgets/avatar_crop_dialog.dart';
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
    _initials = TextEditingController(text: profile?.avatar.initials);
    _avatar = profile?.avatar;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
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
    final adjusted = await showDialog<AvatarCropResult>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AvatarCropDialog(bytes: bytes),
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
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => _AvatarColorDialog(initial: _avatar!.backgroundColor),
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
      avatar: _avatar!.copyWith(initials: normalizedInitials),
    );
    if (mounted) setState(() {});
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
                          title: 'Dados pessoais',
                          description: 'Sua identidade exibida no Superadmin.',
                          child: _PersonalDataForm(
                            firstName: _firstName,
                            lastName: _lastName,
                            email: _email,
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
                        final side = Column(
                          children: [
                            _AccessCard(access: profile.access),
                            const SizedBox(height: CoeloSpacing.space5),
                            _SecurityCard(controller: widget.controller),
                          ],
                        );
                        return wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: personal),
                                  const SizedBox(width: CoeloSpacing.space5),
                                  Expanded(flex: 2, child: side),
                                ],
                              )
                            : Column(
                                children: [
                                  personal,
                                  const SizedBox(height: CoeloSpacing.space5),
                                  side,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: CoeloSpacing.space5),
                    _FormFooter(busy: widget.controller.busy, onSave: _save),
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
              controller: firstName,
              labelText: 'Nome',
              prefixIcon: Icons.person_outline,
              validator: _requiredName,
            ),
            CoeloFormTextField(
              controller: lastName,
              labelText: 'Sobrenome',
              prefixIcon: Icons.badge_outlined,
              validator: _requiredName,
            ),
          ];
          return constraints.maxWidth >= 600
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
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CoeloFormTextField(
              fieldKey: const Key('account-initials-field'),
              controller: initials,
              labelText: 'Sigla',
              hintText: 'OC',
              prefixIcon: Icons.text_fields_rounded,
              validator: (value) => AccountAvatar.validateInitials(value ?? ''),
            ),
          ),
          const SizedBox(width: CoeloSpacing.space3),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
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
            ),
          ),
        ],
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
  const _AccessCard({required this.access});
  final AccountAccessSummary access;

  @override
  Widget build(BuildContext context) => _SectionCard(
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
  const _SecurityCard({required this.controller});
  final AccountController controller;

  @override
  Widget build(BuildContext context) => _SectionCard(
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
  const _SectionCard({required this.title, required this.description, required this.child});
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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
  const _FormFooter({required this.busy, required this.onSave});
  final bool busy;
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
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          key: const Key('account-save-profile'),
          onPressed: busy ? null : onSave,
          icon: busy
              ? const SizedBox.square(
                  dimension: CoeloSize.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(busy ? 'Salvando…' : 'Salvar alterações'),
        ),
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
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    title: const Text('Alterar senha'),
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
      OutlinedButton(onPressed: Navigator.of(context).pop, child: const Text('Cancelar')),
      FilledButton(
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
      ),
    ],
  );
}

class _AvatarColorDialog extends StatefulWidget {
  const _AvatarColorDialog({required this.initial});
  final Color initial;

  @override
  State<_AvatarColorDialog> createState() => _AvatarColorDialogState();
}

class _AvatarColorDialogState extends State<_AvatarColorDialog> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController hex = TextEditingController(text: _hex(widget.initial));

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  void update(HSVColor value) {
    setState(() {
      hsv = value;
      hex.text = _hex(value.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = hsv.toColor();
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: const Text('Cor da sigla'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: color,
              child: Text(
                'OC',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AccountAvatar.foregroundFor(color),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            _ColorSlider(
              label: 'Matiz',
              value: hsv.hue,
              max: 360,
              onChanged: (value) => update(hsv.withHue(value)),
            ),
            _ColorSlider(
              label: 'Saturação',
              value: hsv.saturation * 100,
              onChanged: (value) => update(hsv.withSaturation(value / 100)),
            ),
            _ColorSlider(
              label: 'Brilho',
              value: hsv.value * 100,
              onChanged: (value) => update(hsv.withValue(value / 100)),
            ),
            CoeloFormTextField(
              controller: hex,
              labelText: 'Hexadecimal',
              prefixIcon: Icons.tag_rounded,
              onChanged: (value) {
                if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
                  setState(() => hsv = HSVColor.fromColor(_parseHex(value)));
                }
              },
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              'RGB: ${(color.r * 255).round()} · ${(color.g * 255).round()} · '
              '${(color.b * 255).round()}',
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: Navigator.of(context).pop, child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(color),
          child: const Text('Usar cor'),
        ),
      ],
    );
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 100,
  });
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 80, child: Text(label)),
      Expanded(
        child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged),
      ),
      SizedBox(width: 44, child: Text(value.round().toString())),
    ],
  );
}

String? _requiredName(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null;

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe o e-mail.';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Informe um e-mail válido.';
}

String _hex(Color color) => '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Color _parseHex(String value) => Color(int.parse('FF${value.substring(1)}', radix: 16));
