// ignore_for_file: deprecated_member_use

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import '../data/fake_invite_repository.dart';
import '../domain/platform_invite.dart';

final class InviteFormPage extends StatefulWidget {
  const InviteFormPage({required this.repository, this.onSent, super.key});
  final FakeInviteRepository repository;
  final ValueChanged<PlatformInvite>? onSent;
  @override
  State<InviteFormPage> createState() => _InviteFormPageState();
}

final class _InviteFormPageState extends State<InviteFormPage> {
  final _scope = TextEditingController(text: 'Instituição Aurora'),
      _role = TextEditingController(text: 'Administrador'),
      _recipient = TextEditingController();
  InviteAudience _audience = InviteAudience.institutionAdmin;
  InviteChannel _channel = InviteChannel.email;
  DateTime? _expiry;
  int _step = 0;
  @override
  void dispose() {
    _scope.dispose();
    _role.dispose();
    _recipient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Padding(
      padding: EdgeInsets.all(c.maxWidth < 768 ? CoeloSpacing.space4 : CoeloSpacing.space6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Novo convite', style: Theme.of(context).textTheme.headlineSmall),
              Text('Etapa ${_step + 1} de 7'),
              const SizedBox(height: CoeloSpacing.space4),
              Expanded(child: SingleChildScrollView(child: _content())),
              const SizedBox(height: CoeloSpacing.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _step == 0 ? null : () => setState(() => _step--),
                    child: const Text('Anterior'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (_step < 6) {
                        setState(() => _step++);
                      } else if (_recipient.text.trim().isNotEmpty) {
                        widget.onSent?.call(
                          widget.repository.send(
                            InviteDraft(
                              audience: _audience,
                              scope: _scope.text,
                              role: _role.text,
                              recipient: _recipient.text,
                              channel: _channel,
                              expiresAt: _expiry,
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(_step == 6 ? 'Enviar convite' : 'Continuar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _content() => switch (_step) {
    0 => Column(
      children: [
        for (final v in InviteAudience.values)
          RadioListTile(
            value: v,
            groupValue: _audience,
            title: Text(v.label),
            onChanged: (v) => setState(() => _audience = v!),
          ),
      ],
    ),
    1 => TextField(
      controller: _scope,
      decoration: const InputDecoration(labelText: 'Hierarquia e escopo'),
    ),
    2 => TextField(
      controller: _role,
      decoration: const InputDecoration(labelText: 'Papel e finalidade'),
    ),
    3 => TextField(
      controller: _recipient,
      decoration: const InputDecoration(labelText: 'Destinatário'),
    ),
    4 => Column(
      children: [
        for (final v in InviteChannel.values)
          RadioListTile(
            value: v,
            groupValue: _channel,
            title: Text(v.label),
            onChanged: (v) => setState(() => _channel = v!),
          ),
      ],
    ),
    5 => ListTile(
      title: const Text('Expiração'),
      subtitle: Text(
        _expiry == null ? 'Padrão: 48 horas após o envio' : _expiry!.toIso8601String(),
      ),
      trailing: OutlinedButton(
        onPressed: () => setState(() => _expiry = DateTime.now().add(const Duration(hours: 72))),
        child: const Text('Usar 72h'),
      ),
    ),
    _ => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Público: ${_audience.label}'),
        Text('Escopo: ${_scope.text}'),
        Text('Papel: ${_role.text}'),
        Text('Canal: ${_channel.label}'),
        Text('Expiração: ${_expiry?.toIso8601String() ?? '48 horas'}'),
      ],
    ),
  };
}
