import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/fake_notice_repository.dart';
import '../domain/platform_notice.dart';
import 'notice_preview_dialog.dart';

final class NoticeFormPage extends StatefulWidget {
  const NoticeFormPage({required this.repository, this.noticeId, this.onSaved, super.key});
  final FakeNoticeRepository repository;
  final String? noticeId;
  final ValueChanged<PlatformNotice>? onSaved;
  @override
  State<NoticeFormPage> createState() => _NoticeFormPageState();
}

final class _NoticeFormPageState extends State<NoticeFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _audienceLabel;
  late final TextEditingController _buttonLabel;
  PlatformNotice? _saved;
  late NoticePriority _priority;
  late NoticeAudience _audience;
  late NoticeBehavior _behavior;
  late bool _mandatory;

  @override
  void initState() {
    super.initState();
    final notice = widget.noticeId == null ? null : widget.repository.find(widget.noticeId!);
    _saved = notice;
    _title = TextEditingController(text: notice?.title ?? '');
    _message = TextEditingController(text: notice?.message ?? '');
    _audienceLabel = TextEditingController(text: notice?.audienceLabel ?? 'Equipe Coelo');
    _buttonLabel = TextEditingController(text: notice?.buttonLabel ?? 'Confirmar');
    _priority = notice?.priority ?? NoticePriority.important;
    _audience = notice?.audience ?? NoticeAudience.coeloTeam;
    _behavior = notice?.behavior ?? NoticeBehavior.confirmation;
    _mandatory = notice?.mandatory ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _audienceLabel.dispose();
    _buttonLabel.dispose();
    super.dispose();
  }

  NoticeDraft get _draft => NoticeDraft(
    title: _title.text,
    message: _message.text,
    priority: _priority,
    audience: _audience,
    audienceLabel: _audienceLabel.text,
    behavior: _behavior,
    mandatory: _mandatory,
    buttonLabel: _buttonLabel.text,
  );

  void _save() {
    if (!_form.currentState!.validate()) return;
    final saved = _saved == null
        ? widget.repository.create(_draft)
        : widget.repository.update(_saved!.id, _draft);
    setState(() => _saved = saved);
    widget.onSaved?.call(saved);
  }

  Future<void> _preview() async {
    final notice =
        _saved ??
        PlatformNotice(
          id: 'preview-notice',
          title: _title.text.isEmpty ? 'Prévia do aviso' : _title.text,
          message: _message.text.isEmpty ? 'Mensagem do aviso.' : _message.text,
          priority: _priority,
          status: NoticeStatus.active,
          startsAt: DateTime.now(),
          endsAt: null,
          audience: _audience,
          audienceLabel: _audienceLabel.text,
          behavior: _behavior,
          mandatory: _mandatory,
          reach: 0,
          buttonLabel: _buttonLabel.text,
        );
    await showNoticePreview(
      context,
      notice,
      onAccepted: notice.id == 'preview-notice'
          ? null
          : () => widget.repository.accept(
              notice.id,
              checkboxChecked: _behavior != NoticeBehavior.checkboxConfirmation || true,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 768;
      return Padding(
        padding: EdgeInsets.all(compact ? CoeloSpacing.space4 : CoeloSpacing.space6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Form(
              key: _form,
              child: ListView(
                children: [
                  Text(
                    _saved == null ? 'Novo aviso' : 'Editar aviso',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  const Text('Todos os dados são fictícios e ficam apenas nesta sessão.'),
                  const SizedBox(height: CoeloSpacing.space5),
                  CoeloFormTextField(
                    controller: _title,
                    labelText: 'Título',
                    prefixIcon: Icons.campaign_outlined,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Informe um título.' : null,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloFormTextField(
                    controller: _message,
                    labelText: 'Mensagem',
                    prefixIcon: Icons.subject_rounded,
                    maxLines: 4,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Informe uma mensagem.' : null,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _fields(compact),
                  const SizedBox(height: CoeloSpacing.space4),
                  Text('Imagem e anexo', style: Theme.of(context).textTheme.titleMedium),
                  const Text('Fixture local: sem picker, upload ou arquivo real.'),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloFormTextField(
                    controller: _audienceLabel,
                    labelText: 'Destinatário identificado',
                    prefixIcon: Icons.groups_outlined,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloAdminSingleSelectField<NoticeBehavior>(
                    label: 'Comportamento',
                    value: _behavior,
                    options: NoticeBehavior.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => setState(() => _behavior = value),
                  ),
                  SwitchListTile(
                    value: _mandatory,
                    onChanged: (value) => setState(() => _mandatory = value),
                    title: const Text('Aviso obrigatório'),
                    subtitle: const Text('A simulação informa que o aviso reaparece até o aceite.'),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloFormTextField(
                    controller: _buttonLabel,
                    labelText: 'Rótulo do botão',
                    prefixIcon: Icons.smart_button_outlined,
                  ),
                  const SizedBox(height: CoeloSpacing.space6),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: CoeloSpacing.space3,
                    runSpacing: CoeloSpacing.space3,
                    children: [
                      OutlinedButton(onPressed: _preview, child: const Text('Ver prévia')),
                      FilledButton(
                        onPressed: _save,
                        child: Text(_saved == null ? 'Salvar rascunho' : 'Salvar alterações'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _fields(bool compact) {
    final fields = [
      CoeloAdminSingleSelectField<NoticePriority>(
        label: 'Prioridade',
        value: _priority,
        options: NoticePriority.values,
        optionLabel: (value) => value.label,
        onChanged: (value) => setState(() => _priority = value),
      ),
      CoeloAdminSingleSelectField<NoticeAudience>(
        label: 'Audiência',
        value: _audience,
        options: NoticeAudience.values,
        optionLabel: (value) => value.label,
        onChanged: (value) => setState(() => _audience = value),
      ),
    ];
    return compact
        ? Column(
            children: [
              fields.first,
              const SizedBox(height: CoeloSpacing.space4),
              fields.last,
            ],
          )
        : Row(
            children: [
              Expanded(child: fields.first),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(child: fields.last),
            ],
          );
  }
}
