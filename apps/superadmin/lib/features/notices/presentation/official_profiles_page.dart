import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/entity_lifecycle_runner.dart';
import '../domain/notice_repository.dart';
import '../domain/platform_notice.dart';

/// Comunicação › Avisos › Perfis oficiais (spec 068): catálogo ativo, posts do
/// Acontece por perfil, publicar e retirar. A autorização é do servidor
/// (`notices.publish`); a tela só pede e mostra.
final class OfficialProfilesPage extends StatefulWidget {
  const OfficialProfilesPage({
    required this.profiles,
    required this.posts,
    this.onReturn,
    super.key,
  });

  final NoticeCtaTargetOptionsReader profiles;
  final OfficialPostsCommands posts;
  final VoidCallback? onReturn;

  @override
  State<OfficialProfilesPage> createState() => _OfficialProfilesPageState();
}

final class _OfficialProfilesPageState extends State<OfficialProfilesPage> {
  List<NoticeOfficialProfile> _profiles = const [];
  List<OfficialPost> _posts = const [];
  String? _selectedProfileId;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.profiles.fetchOfficialProfiles(),
        widget.posts.fetchOfficialPosts(),
      ]);
      if (!mounted) return;
      setState(() {
        _profiles = results[0] as List<NoticeOfficialProfile>;
        _posts = results[1] as List<OfficialPost>;
        _loading = false;
      });
    } on NoticeRepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.safeMessage;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os perfis oficiais.';
        _loading = false;
      });
    }
  }

  void _feedback(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _publish() async {
    if (_profiles.isEmpty) return;
    final input = await showDialog<(String, String)>(
      context: context,
      barrierColor: context.coeloScrim,
      builder: (_) => _PublishDialog(
        profiles: _profiles,
        initialProfileId: _selectedProfileId ?? _profiles.first.id,
      ),
    );
    if (input == null || !mounted) return;
    final (profileId, caption) = input;
    try {
      await widget.posts.publishOfficialPost(
        requestId: entityLifecycleRequestId(),
        profileId: profileId,
        caption: caption,
      );
      final profile = _profiles.where((p) => p.id == profileId).firstOrNull;
      _feedback('Publicado no Acontece como ${profile?.displayName ?? 'perfil oficial'}.');
    } on NoticeRepositoryException catch (error) {
      _feedback(error.safeMessage);
    } on Object {
      _feedback('Não foi possível publicar.');
    }
    await _load();
  }

  Future<void> _withdraw(OfficialPost post) async {
    final reason = await showDialog<String>(
      context: context,
      barrierColor: context.coeloScrim,
      builder: (_) => _WithdrawDialog(post: post),
    );
    if (reason == null || !mounted) return;
    try {
      await widget.posts.withdrawOfficialPost(
        requestId: entityLifecycleRequestId(),
        postId: post.id,
        expectedVersion: post.managementVersion,
        reason: reason,
      );
      _feedback('Post retirado do Acontece.');
    } on NoticeConflictException {
      _feedback('O post foi alterado por outra pessoa. A lista foi recarregada.');
    } on NoticeRepositoryException catch (error) {
      _feedback(error.safeMessage);
    } on Object {
      _feedback('Não foi possível retirar o post.');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_loading) {
      return const Center(
        key: Key('official-profiles-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error case final error?) {
      return Center(
        key: const Key('official-profiles-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: CoeloSpacing.space3),
            FilledButton.tonal(onPressed: _load, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }
    final visiblePosts = _selectedProfileId == null
        ? _posts
        : _posts.where((p) => p.profileId == _selectedProfileId).toList();
    return ListView(
      key: const Key('official-profiles-list'),
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      children: [
        Row(
          children: [
            if (widget.onReturn case final onReturn?)
              IconButton(
                key: const Key('official-profiles-return'),
                tooltip: 'Voltar para Avisos',
                onPressed: onReturn,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            Expanded(
              child: Text(
                'Perfis oficiais',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              key: const Key('official-post-publish'),
              onPressed: _profiles.isEmpty ? null : _publish,
              icon: const Icon(Icons.post_add_rounded),
              label: const Text('Publicar no Acontece'),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          'Todo mundo do Principal segue estes perfis; o post entra no feed Acontece de todos os '
          'contextos e a publicação assinada entra no Para você.',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            ChoiceChip(
              key: const Key('official-profile-chip-all'),
              label: const Text('Todos'),
              selected: _selectedProfileId == null,
              onSelected: (_) => setState(() => _selectedProfileId = null),
            ),
            for (final profile in _profiles)
              ChoiceChip(
                key: Key('official-profile-chip-${profile.handle}'),
                avatar: profile.mandatory ? const Icon(Icons.verified_rounded) : null,
                label: Text('${profile.displayName} · @${profile.handle}'),
                selected: _selectedProfileId == profile.id,
                onSelected: (_) => setState(
                  () => _selectedProfileId = _selectedProfileId == profile.id ? null : profile.id,
                ),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Posts no Acontece', style: theme.textTheme.titleSmall),
        const SizedBox(height: CoeloSpacing.space2),
        if (visiblePosts.isEmpty)
          Padding(
            key: const Key('official-posts-empty'),
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space6),
            child: Text(
              'Nenhum post por enquanto.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          )
        else
          for (final post in visiblePosts) ...[
            Card(
              key: Key('official-post-${post.id}'),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${post.profileName} · @${post.handle}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          CoeloDateField.format(post.publishedAt.toLocal()),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: CoeloSpacing.space2),
                        if (post.isPublished)
                          OutlinedButton(
                            key: Key('official-post-withdraw-${post.id}'),
                            onPressed: () => _withdraw(post),
                            child: const Text('Retirar'),
                          )
                        else
                          Tooltip(
                            message: post.withdrawReason ?? '',
                            child: Chip(
                              label: const Text('Retirado'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: CoeloSpacing.space2),
                    Text(post.caption, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
          ],
      ],
    );
  }
}

final class _PublishDialog extends StatefulWidget {
  const _PublishDialog({required this.profiles, required this.initialProfileId});
  final List<NoticeOfficialProfile> profiles;
  final String initialProfileId;

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

final class _PublishDialogState extends State<_PublishDialog> {
  final _caption = TextEditingController();
  late String _profileId = widget.initialProfileId;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('official-post-dialog'),
    title: 'Publicar no Acontece',
    closeTooltip: 'Fechar',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('official-post-profile'),
          isExpanded: true,
          initialValue: _profileId,
          decoration: const InputDecoration(labelText: 'Publicar como'),
          items: [
            for (final profile in widget.profiles)
              DropdownMenuItem(value: profile.id, child: Text(profile.label)),
          ],
          onChanged: (value) => setState(() => _profileId = value ?? _profileId),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: const Key('official-post-caption'),
          controller: _caption,
          labelText: 'Texto do post',
          hintText: 'Até 2000 caracteres. Entra no Acontece de todos os contextos.',
          prefixIcon: Icons.edit_note_outlined,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('official-post-confirm'),
      onPressed: _caption.text.trim().isEmpty || _caption.text.trim().length > 2000
          ? null
          : () => Navigator.of(context).pop((_profileId, _caption.text.trim())),
      child: const Text('Publicar'),
    ),
  );
}

final class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.post});
  final OfficialPost post;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

final class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('official-post-withdraw-dialog'),
    title: 'Retirar post do Acontece?',
    closeTooltip: 'Fechar',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.post.caption,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: const Key('official-post-withdraw-reason'),
          controller: _reason,
          labelText: 'Motivo',
          hintText: 'Ex.: publicado por engano',
          prefixIcon: Icons.edit_note_outlined,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('official-post-withdraw-confirm'),
      onPressed: _reason.text.trim().isEmpty
          ? null
          : () => Navigator.of(context).pop(_reason.text.trim()),
      style: coeloDestructiveFilledButtonStyle(context),
      child: const Text('Retirar'),
    ),
  );
}
