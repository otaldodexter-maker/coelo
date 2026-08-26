import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/activity_profile_about_repository.dart';
import 'activity_form_controller.dart';

final class ActivityProfileAboutSection extends StatefulWidget {
  const ActivityProfileAboutSection({
    required this.controller,
    required this.repository,
    this.activityId,
    super.key,
  });

  final ActivityFormController controller;
  final ActivityProfileAboutRepository repository;
  final String? activityId;

  @override
  State<ActivityProfileAboutSection> createState() => _ActivityProfileAboutSectionState();
}

enum _AboutLoadState { loading, ready, unavailable, unauthorized }

final class _ActivityProfileAboutSectionState extends State<ActivityProfileAboutSection> {
  _AboutLoadState _state = _AboutLoadState.loading;
  final Map<ProfileAboutFieldKey, TextEditingController> _fields = {};

  static const _editableFields = <ProfileAboutFieldKey, (String, IconData)>{
    ProfileAboutFieldKey.description: ('Descrição', Icons.notes_outlined),
    ProfileAboutFieldKey.objective: ('Objetivo', Icons.flag_outlined),
    ProfileAboutFieldKey.audience: ('Público', Icons.groups_outlined),
    ProfileAboutFieldKey.methodology: ('Metodologia', Icons.school_outlined),
    ProfileAboutFieldKey.materials: ('Materiais', Icons.inventory_2_outlined),
    ProfileAboutFieldKey.generalGuidance: ('Orientações gerais', Icons.info_outline),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final institutionId = widget.controller.selectedInstitutionId;
    if (institutionId == null) {
      if (mounted) setState(() => _state = _AboutLoadState.unavailable);
      return;
    }
    try {
      var page =
          widget.controller.aboutPage ??
          await widget.repository.load(institutionId: institutionId, activityId: widget.activityId);
      page = _withActivitySuggestions(page);
      widget.controller.setAboutPage(page, markDirty: false);
      for (final key in _editableFields.keys) {
        _fields[key] = TextEditingController(text: _value(page, key));
      }
      if (mounted) setState(() => _state = _AboutLoadState.ready);
    } on ActivityProfileAboutUnauthorizedException {
      if (mounted) setState(() => _state = _AboutLoadState.unauthorized);
    } on ActivityProfileAboutUnavailableException {
      if (mounted) setState(() => _state = _AboutLoadState.unavailable);
    }
  }

  ProfileAboutPage _withActivitySuggestions(ProfileAboutPage page) {
    final name = widget.controller.name.text.trim();
    final description = widget.controller.description.text.trim();
    var next = page;
    if (name.isNotEmpty && _value(page, ProfileAboutFieldKey.displayName).isEmpty) {
      next = next.replaceField(
        ProfileAboutField(
          key: ProfileAboutFieldKey.displayName,
          value: name,
          origin: ProfileAboutOrigin.suggestedOfficial,
          sourceLabel: 'Cadastro da atividade',
        ),
      );
    }
    if (description.isNotEmpty && _value(page, ProfileAboutFieldKey.description).isEmpty) {
      next = next.replaceField(
        ProfileAboutField(
          key: ProfileAboutFieldKey.description,
          value: description,
          origin: ProfileAboutOrigin.suggestedOfficial,
          sourceLabel: 'Cadastro da atividade',
        ),
      );
    }
    return next;
  }

  static String _value(ProfileAboutPage page, ProfileAboutFieldKey key) =>
      page.fields.where((field) => field.key == key).map((field) => field.value).firstOrNull ?? '';

  void _change(ProfileAboutFieldKey key, String value) {
    final page = widget.controller.aboutPage;
    if (page == null) return;
    final existing = page.fields.where((field) => field.key == key).firstOrNull;
    widget.controller.setAboutPage(
      page.replaceField(
        existing?.copyWith(value: value) ?? ProfileAboutField(key: key, value: value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
    _AboutLoadState.loading => const Center(
      child: Padding(
        padding: EdgeInsets.all(CoeloSpacing.space6),
        child: CircularProgressIndicator(),
      ),
    ),
    _AboutLoadState.unavailable => const CoeloStatePanel(
      key: Key('activity-about-unavailable'),
      title: 'Sobre indisponível',
      message: 'O editor de Sobre da atividade não está disponível neste ambiente.',
      icon: Icons.cloud_off_outlined,
    ),
    _AboutLoadState.unauthorized => const CoeloStatePanel(
      key: Key('activity-about-unauthorized'),
      title: 'Acesso não autorizado',
      message: 'Você não pode editar o Sobre desta atividade.',
      icon: Icons.lock_outline,
    ),
    _AboutLoadState.ready => Column(
      key: const Key('activity-about-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sobre do perfil', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          'Conteúdo público contextual da atividade. O cadastro e o Sobre permanecem independentes.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        for (final entry in _editableFields.entries) ...[
          CoeloFormTextField(
            key: Key('activity-about-${entry.key.name}'),
            controller: _fields[entry.key]!,
            labelText: entry.value.$1,
            prefixIcon: entry.value.$2,
            maxLines:
                entry.key == ProfileAboutFieldKey.description ||
                    entry.key == ProfileAboutFieldKey.generalGuidance
                ? 3
                : 2,
            onChanged: (value) => _change(entry.key, value),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
      ],
    ),
  };
}
