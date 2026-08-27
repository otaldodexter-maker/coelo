import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

enum ProfileAboutEditorStatus { ready, loading, empty, saving, failure, unauthorized }

final class ProfileAboutEditorController extends ChangeNotifier {
  ProfileAboutEditorController({
    required ProfileAboutPage page,
    this.suggestions = const [],
    this.onChanged,
  }) : _page = page;

  ProfileAboutPage _page;
  List<ProfileAboutSuggestion> suggestions;
  final ValueChanged<ProfileAboutPage>? onChanged;
  ProfileAboutEditorStatus _status = ProfileAboutEditorStatus.ready;
  ProfileAboutAudience previewAudience = ProfileAboutAudience.profileAccess;
  int _nextSection = 1;
  bool isDirty = false;

  ProfileAboutPage get page => _page;
  ProfileAboutEditorStatus get status => _status;
  set status(ProfileAboutEditorStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  bool get _isSaving => _status == ProfileAboutEditorStatus.saving;
  bool get hasSuggestions =>
      suggestions.any((suggestion) => !_page.fields.any((field) => field.key == suggestion.key));

  void replaceSuggestions(Iterable<ProfileAboutSuggestion> value) {
    suggestions = List.unmodifiable(value);
  }

  void replacePage(ProfileAboutPage page) {
    _page = page;
    isDirty = false;
    _status = ProfileAboutEditorStatus.ready;
    notifyListeners();
  }

  void _changed() {
    isDirty = true;
    onChanged?.call(_page);
    notifyListeners();
  }

  void copySuggestions() {
    if (_isSaving) return;
    _page = _page.copySuggestions(
      suggestions,
      suggestions.map((suggestion) => suggestion.key).toSet(),
    );
    _status = ProfileAboutEditorStatus.ready;
    _changed();
  }

  void setPreviewAudience(ProfileAboutAudience value) {
    previewAudience = value;
    notifyListeners();
  }

  void move(String id, ProfileAboutMove direction) {
    if (_isSaving) return;
    _page = _page.moveSection(id, direction);
    _changed();
  }

  void addSection([ProfileAboutSectionType type = ProfileAboutSectionType.text]) {
    if (_isSaving) return;
    _page = _page.addSection(
      ProfileAboutSection(
        id: _nextDraftSectionId(),
        type: type,
        title: _newSectionTitle(type),
        body: '',
        position: _page.sections.length,
      ),
    );
    _status = ProfileAboutEditorStatus.ready;
    _changed();
  }

  void reorder(int oldIndex, int newIndex) {
    if (_isSaving) return;
    _page = _page.reorderSection(oldIndex, newIndex);
    _changed();
  }

  void updateSection(String id, {String? title, String? body, ProfileAboutVisibility? visibility}) {
    if (_isSaving) return;
    _page = _page.updateSection(id, title: title, body: body, visibility: visibility);
    _changed();
  }

  void duplicateSection(String id) {
    if (_isSaving) return;
    _page = _page.duplicateSection(id, _nextDraftSectionId());
    _changed();
  }

  String _nextDraftSectionId() {
    final used = _page.sections.map((section) => section.id).toSet();
    while (true) {
      final candidate = 'draft-section-${_nextSection++}';
      if (!used.contains(candidate)) return candidate;
    }
  }

  void removeSection(String id) {
    if (_isSaving) return;
    _page = _page.removeSection(id);
    _changed();
  }

  void updateField(ProfileAboutField field) {
    if (_isSaving) return;
    _page = _page.replaceField(field);
    _changed();
  }

  Map<ProfileAboutFieldKey, String> get officialChanges => {
    for (final field in _page.fields)
      if (suggestions.any(
        (suggestion) => suggestion.key == field.key && suggestion.value != field.value,
      ))
        field.key: field.value,
  };
}

final class ProfileAboutEditor extends StatelessWidget {
  const ProfileAboutEditor({
    required this.controller,
    this.onPreview,
    this.onAdjustLocation,
    super.key,
  });

  final ProfileAboutEditorController controller;
  final VoidCallback? onPreview;
  final VoidCallback? onAdjustLocation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => switch (controller.status) {
      ProfileAboutEditorStatus.loading => const CoeloStatePanel(
        title: 'Carregando Sobre',
        message: 'Buscando o conteúdo autorizado.',
        loading: true,
      ),
      ProfileAboutEditorStatus.empty => _content(context),
      ProfileAboutEditorStatus.failure => const CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Tente novamente sem perder suas alterações locais.',
        icon: Icons.error_outline,
      ),
      ProfileAboutEditorStatus.unauthorized => const CoeloStatePanel(
        title: 'Sem permissão',
        message: 'Você não pode editar o Sobre neste contexto.',
        icon: Icons.lock_outline,
      ),
      _ => _content(context),
    },
  );

  Widget _content(BuildContext context) {
    final page = controller.page;
    final sections = [...page.sections]..sort((a, b) => a.position.compareTo(b.position));
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPreview = constraints.maxWidth >= 1120;
        final editor = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: 'O Sobre é independente do cadastro oficial',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(CoeloSpacing.space4),
                  child: Text(
                    'O Sobre é independente do cadastro oficial. Alterações aqui não atualizam automaticamente o cadastro.',
                  ),
                ),
              ),
            ),
            if (controller.hasSuggestions) ...[
              const SizedBox(height: CoeloSpacing.space4),
              OutlinedButton.icon(
                onPressed: controller.copySuggestions,
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('Começar com dados do cadastro'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: CoeloSpacing.space2),
                child: Text(
                  'Os dados serão copiados. Alterações futuras permanecerão independentes.',
                ),
              ),
            ],
            const SizedBox(height: CoeloSpacing.space5),
            Align(
              alignment: Alignment.centerRight,
              child: CoeloAdminFlyout<ProfileAboutAudience>(
                items: [
                  for (final audience in ProfileAboutAudience.values)
                    CoeloAdminFlyoutItem(
                      value: audience,
                      label: _audienceLabel(audience),
                      selected: audience == controller.previewAudience,
                    ),
                ],
                onSelected: controller.setPreviewAudience,
                builder: (context, flyout) => OutlinedButton.icon(
                  onPressed: () => flyout.isOpen ? flyout.close() : flyout.open(),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text('Prévia: ${_audienceLabel(controller.previewAudience)}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            if (page.fields.isEmpty && sections.isEmpty)
              const CoeloStatePanel(
                title: 'Nenhum conteúdo no Sobre',
                message: 'Copie sugestões do cadastro ou adicione uma seção editorial.',
                icon: Icons.info_outline,
              )
            else ...[
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: sections.length,
                onReorderItem: controller.reorder,
                itemBuilder: (context, index) => _SectionRow(
                  key: ValueKey(sections[index].id),
                  section: sections[index],
                  index: index,
                  count: sections.length,
                  onMove: controller.move,
                  onEdit: () => _editSection(context, sections[index]),
                  onDuplicate: () => controller.duplicateSection(sections[index].id),
                  onRemove: () => controller.removeSection(sections[index].id),
                  onVisibility: (value) =>
                      controller.updateSection(sections[index].id, visibility: value),
                ),
              ),
              for (final field in page.fields)
                _FieldRow(
                  field: field,
                  onAdjustLocation: onAdjustLocation,
                  onEdit: () => _editField(context, field),
                  onVisibility: (value) =>
                      controller.updateField(field.copyWith(visibility: value)),
                ),
            ],
            const SizedBox(height: CoeloSpacing.space4),
            CoeloAdminFlyout<ProfileAboutSectionType>(
              items: [
                for (final type in _addableSectionTypes)
                  CoeloAdminFlyoutItem(value: type, label: _sectionTypeLabel(type)),
              ],
              onSelected: controller.addSection,
              builder: (context, flyout) => OutlinedButton.icon(
                onPressed: flyout.open,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar seção'),
              ),
            ),
            if (!showPreview) ...[
              const SizedBox(height: CoeloSpacing.space3),
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Pré-visualizar'),
              ),
            ],
            if (controller.status == ProfileAboutEditorStatus.saving) ...[
              const SizedBox(height: CoeloSpacing.space3),
              const LinearProgressIndicator(semanticsLabel: 'Salvando alterações do Sobre'),
            ],
          ],
        );
        if (!showPreview) return editor;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: editor),
            const SizedBox(width: CoeloSpacing.space6),
            Expanded(child: _Preview(page: page.project(controller.previewAudience))),
          ],
        );
      },
    );
  }

  Future<void> _editSection(BuildContext context, ProfileAboutSection section) async {
    final title = TextEditingController(text: section.title);
    final body = TextEditingController(text: section.body);
    final save = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        dialogKey: const Key('profile-about-section-dialog'),
        title: 'Editar seção',
        closeTooltip: 'Fechar edição da seção',
        body: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoeloFormTextField(
                controller: title,
                labelText: 'Título',
                prefixIcon: Icons.title,
                maxLength: 120,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              CoeloFormTextField(
                controller: body,
                labelText: 'Conteúdo',
                prefixIcon: Icons.notes,
                maxLines: 6,
                maxLength: 12000,
              ),
            ],
          ),
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Aplicar'),
        ),
      ),
    );
    if (save == true) {
      controller.updateSection(section.id, title: title.text.trim(), body: body.text.trim());
    }
    title.dispose();
    body.dispose();
  }

  Future<void> _editField(BuildContext context, ProfileAboutField field) async {
    final value = TextEditingController(text: field.value);
    final save = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        dialogKey: const Key('profile-about-field-dialog'),
        title: 'Editar informação',
        closeTooltip: 'Fechar edição da informação',
        body: CoeloFormTextField(
          controller: value,
          labelText: field.key.name,
          prefixIcon: Icons.edit_outlined,
          maxLines: field.key == ProfileAboutFieldKey.importantInformation ? 5 : 2,
          maxLength: 4000,
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Aplicar'),
        ),
      ),
    );
    if (save == true && value.text.trim().isNotEmpty) {
      controller.updateField(field.copyWith(value: value.text.trim()));
    }
    value.dispose();
  }
}

final class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.index,
    required this.count,
    required this.onMove,
    required this.onEdit,
    required this.onDuplicate,
    required this.onRemove,
    required this.onVisibility,
  });
  final ProfileAboutSection section;
  final int index;
  final int count;
  final void Function(String, ProfileAboutMove) onMove;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final ValueChanged<ProfileAboutVisibility> onVisibility;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '${section.title}, posição ${index + 1} de $count',
    customSemanticsActions: {
      if (index > 0)
        const CustomSemanticsAction(label: 'Mover para cima'): () =>
            onMove(section.id, ProfileAboutMove.up),
      if (index + 1 < count)
        const CustomSemanticsAction(label: 'Mover para baixo'): () =>
            onMove(section.id, ProfileAboutMove.down),
    },
    child: Card(
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: ListTile(
        minVerticalPadding: CoeloSpacing.space3,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, semanticLabel: 'Arrastar para reposicionar'),
        ),
        title: Text(section.title),
        subtitle: Text('${section.type.name} · ${_visibilityLabel(section.visibility)}'),
        onTap: onEdit,
        trailing: Wrap(
          children: [
            CoeloAdminFlyout<ProfileAboutVisibility>(
              items: _visibilityItems(section.visibility),
              onSelected: onVisibility,
              builder: (context, flyout) => IconButton(
                tooltip: 'Alterar visibilidade',
                onPressed: () => flyout.isOpen ? flyout.close() : flyout.open(),
                icon: const Icon(Icons.visibility_outlined),
              ),
            ),
            IconButton(
              onPressed: index > 0 ? () => onMove(section.id, ProfileAboutMove.up) : null,
              tooltip: 'Mover para cima',
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              onPressed: index + 1 < count ? () => onMove(section.id, ProfileAboutMove.down) : null,
              tooltip: 'Mover para baixo',
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            CoeloAdminFlyout<String>(
              items: const [
                CoeloAdminFlyoutItem(value: 'duplicate', label: 'Duplicar'),
                CoeloAdminFlyoutItem(
                  value: 'remove',
                  label: 'Remover',
                  tone: CoeloAdminFlyoutTone.negative,
                ),
              ],
              onSelected: (value) => switch (value) {
                'duplicate' => onDuplicate(),
                'remove' => onRemove(),
                _ => null,
              },
              builder: (context, flyout) => IconButton(
                tooltip: 'Mais ações da seção',
                onPressed: () => flyout.isOpen ? flyout.close() : flyout.open(),
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.onAdjustLocation,
    required this.onEdit,
    required this.onVisibility,
  });
  final ProfileAboutField field;
  final VoidCallback? onAdjustLocation;
  final VoidCallback onEdit;
  final ValueChanged<ProfileAboutVisibility> onVisibility;
  @override
  Widget build(BuildContext context) {
    final location = field.key == ProfileAboutFieldKey.preciseLocation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(location ? Icons.location_on_outlined : Icons.info_outline),
              title: Text(field.key.name),
              subtitle: Text(field.value),
              onTap: onEdit,
              trailing: CoeloAdminFlyout<ProfileAboutVisibility>(
                items: _visibilityItems(field.visibility),
                onSelected: onVisibility,
                builder: (context, flyout) => IconButton(
                  tooltip: 'Alterar visibilidade',
                  onPressed: () => flyout.isOpen ? flyout.close() : flyout.open(),
                  icon: const Icon(Icons.visibility_outlined),
                ),
              ),
            ),
            if (location) ...[
              Container(
                height: 132,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: const Icon(Icons.location_pin, size: CoeloSize.iconLg),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              const Text('Prévia cartográfica indisponível neste ambiente.'),
              const Text('O mapa segue a visibilidade da localização.'),
              if (onAdjustLocation != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onAdjustLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ajustar localização'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _Preview extends StatelessWidget {
  const _Preview({required this.page});
  final ProfileAboutPage page;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Prévia do perfil', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space4),
          for (final field in page.fields) ...[
            Text(field.key.name, style: Theme.of(context).textTheme.labelLarge),
            Text(field.value),
            const SizedBox(height: CoeloSpacing.space3),
          ],
          for (final section in page.sections) ...[
            Text(section.title, style: Theme.of(context).textTheme.titleSmall),
            if (section.body.isNotEmpty) Text(section.body),
            const SizedBox(height: CoeloSpacing.space3),
          ],
        ],
      ),
    ),
  );
}

String _visibilityLabel(ProfileAboutVisibility value) => switch (value) {
  ProfileAboutVisibility.profileAccess => 'Todos com acesso ao perfil',
  ProfileAboutVisibility.linked => 'Somente vinculados',
  ProfileAboutVisibility.team => 'Somente equipe',
  ProfileAboutVisibility.hidden => 'Oculto',
};

List<CoeloAdminFlyoutItem<ProfileAboutVisibility>> _visibilityItems(
  ProfileAboutVisibility selected,
) => [
  for (final value in ProfileAboutVisibility.values)
    CoeloAdminFlyoutItem(value: value, label: _visibilityLabel(value), selected: value == selected),
];

String _audienceLabel(ProfileAboutAudience value) => switch (value) {
  ProfileAboutAudience.profileAccess => 'Todos com acesso ao perfil',
  ProfileAboutAudience.linked => 'Somente vinculados',
  ProfileAboutAudience.team => 'Somente equipe',
};

const _addableSectionTypes = [
  ProfileAboutSectionType.text,
  ProfileAboutSectionType.iconList,
  ProfileAboutSectionType.contact,
  ProfileAboutSectionType.hours,
  ProfileAboutSectionType.links,
  ProfileAboutSectionType.structuredInfo,
];

String _sectionTypeLabel(ProfileAboutSectionType value) => switch (value) {
  ProfileAboutSectionType.text => 'Texto',
  ProfileAboutSectionType.iconList => 'Lista com ícones',
  ProfileAboutSectionType.location => 'Localização',
  ProfileAboutSectionType.contact => 'Contato',
  ProfileAboutSectionType.hours => 'Horário',
  ProfileAboutSectionType.links => 'Vínculos',
  ProfileAboutSectionType.structuredInfo => 'Informação estruturada',
};

String _newSectionTitle(ProfileAboutSectionType value) => switch (value) {
  ProfileAboutSectionType.text => 'Nova seção',
  ProfileAboutSectionType.iconList => 'Destaques',
  ProfileAboutSectionType.location => 'Localização',
  ProfileAboutSectionType.contact => 'Contato',
  ProfileAboutSectionType.hours => 'Horários',
  ProfileAboutSectionType.links => 'Vínculos',
  ProfileAboutSectionType.structuredInfo => 'Informações importantes',
};

Future<Map<ProfileAboutFieldKey, String>> confirmProfileAboutOfficialUpdate(
  BuildContext context, {
  required Map<ProfileAboutFieldKey, String> changes,
  required bool canUpdateOfficialData,
}) async {
  if (changes.isEmpty || !canUpdateOfficialData) return const {};
  final update = await showDialog<bool>(
    context: context,
    barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
    builder: (context) => CoeloAdminDialogShell(
      dialogKey: const Key('profile-about-official-update-dialog'),
      title: 'Atualizar também no cadastro oficial?',
      closeTooltip: 'Fechar confirmação de atualização',
      body: const Text(
        'O Sobre será salvo de forma independente. A atualização do cadastro exige permissão própria e será auditada.',
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Agora não'),
      ),
      primaryAction: FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Sim, atualizar'),
      ),
    ),
  );
  return update == true ? changes : const {};
}
