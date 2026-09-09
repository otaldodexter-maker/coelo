import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../principal_circulars/domain/circular_repository.dart';
import '../../principal_happens/domain/principal_happens_feed_repository.dart';
import '../../principal_shared/domain/principal_runtime_context.dart';
import '../../profile_about/domain/profile_about_repository.dart';
import '../domain/principal_profile_preview_data.dart';
import 'principal_profile_happens_tab.dart';
import 'principal_profile_preview_page.dart';

/// Production composition root for `principal.profile-view`.
///
/// Identity and scope come from the server-authorized Principal context, never
/// from the URL or from preview fixtures. Circulares and Sobre are projected by
/// their own authorized repositories; sections without an authorized source stay
/// empty instead of borrowing demo data.
final class PrincipalProfileRoutePage extends StatefulWidget {
  const PrincipalProfileRoutePage({
    required this.runtimeContext,
    required this.onOpenAgenda,
    this.circularRepository,
    this.aboutRepository,
    this.happensFeedRepository,
    this.onOpenCircular,
    this.onMessage,
    this.onOpenEdit,
    this.onOpenHome,
    this.onOpenForYou,
    this.onOpenMoments,
    this.onOpenSearch,
    this.onOpenMessages,
    this.onPublishNow,
    this.onOpenNotifications,
    this.onOpenContext,
    super.key,
  });

  final PrincipalRuntimeContext runtimeContext;
  final CircularRepository? circularRepository;
  final ProfileAboutRepository? aboutRepository;
  final PrincipalHappensFeedRepository? happensFeedRepository;
  final VoidCallback onOpenAgenda;
  final ValueChanged<String>? onOpenCircular;
  final VoidCallback? onMessage;
  final VoidCallback? onOpenEdit;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenForYou;
  final VoidCallback? onOpenMoments;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onPublishNow;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenContext;

  @override
  State<PrincipalProfileRoutePage> createState() => _PrincipalProfileRoutePageState();
}

sealed class _AboutState {
  const _AboutState();
}

final class _AboutLoading extends _AboutState {
  const _AboutLoading();
}

final class _AboutReady extends _AboutState {
  const _AboutReady(this.page);
  final ProfileAboutPage? page;
}

final class _AboutFailed extends _AboutState {
  const _AboutFailed();
}

final class _AboutUnauthorized extends _AboutState {
  const _AboutUnauthorized();
}

final class _PrincipalProfileRoutePageState extends State<PrincipalProfileRoutePage> {
  _AboutState _about = const _AboutLoading();
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrincipalProfileRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.aboutRepository, widget.aboutRepository) &&
        oldWidget.runtimeContext.institutionId == widget.runtimeContext.institutionId &&
        oldWidget.runtimeContext.unitId == widget.runtimeContext.unitId &&
        oldWidget.runtimeContext.groupId == widget.runtimeContext.groupId) {
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _generation += 1;
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

  Future<void> _load() async {
    final generation = ++_generation;
    final repository = widget.aboutRepository;
    if (repository == null) {
      setState(() => _about = const _AboutReady(null));
      return;
    }
    setState(() => _about = const _AboutLoading());
    try {
      final page = await repository.load(_subject);
      if (!mounted || generation != _generation) return;
      setState(() => _about = _AboutReady(page));
    } on ProfileAboutUnauthorizedException {
      if (!mounted || generation != _generation) return;
      setState(() => _about = const _AboutUnauthorized());
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() => _about = const _AboutFailed());
    }
  }

  String get _contextLabel {
    final context = widget.runtimeContext;
    return [
      context.institutionName,
      ?context.unitName,
      ?context.groupName,
    ].join(' · ');
  }

  PrincipalProfilePreviewData get _data {
    final context = widget.runtimeContext;
    final about = switch (_about) {
      _AboutReady(:final page) => page,
      _ => null,
    };
    // The bio is the authorized `description` field of the About page, not a
    // section body: sections already render in full inside the Sobre tab.
    final visibleFields =
        about?.project(ProfileAboutAudience.profileAccess).fields ?? const <ProfileAboutField>[];
    final bio = visibleFields
        .where((field) => field.key == ProfileAboutFieldKey.description)
        .map((field) => field.value.trim())
        .where((value) => value.isNotEmpty)
        .take(1);
    return PrincipalProfilePreviewData.contextual(
      name: _titleFor(context),
      typeLabel: _contextLabel,
      bio: bio.isEmpty ? '' : bio.first,
    );
  }

  Widget? get _happensTab {
    final repository = widget.happensFeedRepository;
    if (repository == null) return null;
    return PrincipalProfileHappensTab(
      repository: repository,
      scope: PrincipalHappensFeedScope(
        institutionId: widget.runtimeContext.institutionId,
        unitId: widget.runtimeContext.unitId,
        groupId: widget.runtimeContext.groupId,
      ),
    );
  }

  CircularScope get _circularScope => CircularScope(
    institutionId: widget.runtimeContext.institutionId,
    unitId: widget.runtimeContext.unitId,
    groupId: widget.runtimeContext.groupId,
  );

  @override
  Widget build(BuildContext context) => switch (_about) {
    _AboutLoading() => const Scaffold(
      body: Center(child: CircularProgressIndicator(key: Key('principal-profile-loading'))),
    ),
    // Fail-closed: a denied About never falls back to the previous content and
    // never offers a retry that would re-probe the server.
    _AboutUnauthorized() => const Scaffold(
      key: Key('principal-profile-unauthorized'),
      body: CoeloStatePanel(
        title: 'Acesso não disponível',
        message: 'Seu vínculo atual não autoriza este perfil.',
        icon: Icons.lock_outline_rounded,
      ),
    ),
    _AboutFailed() => Scaffold(
      key: const Key('principal-profile-error'),
      body: CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Não conseguimos carregar este perfil agora.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      ),
    ),
    _AboutReady(:final page) => PrincipalProfilePreviewPage(
      key: const Key('principal-profile-content'),
      data: _data,
      showPreviewFeeds: false,
      happensTab: _happensTab,
      aboutPage: page,
      circularRepository: widget.circularRepository,
      circularScope: widget.circularRepository == null ? null : _circularScope,
      onOpenCircular: widget.onOpenCircular,
      onOpenAgenda: widget.onOpenAgenda,
      onMessage: widget.onMessage,
      onOpenEdit: widget.aboutRepository == null ? null : widget.onOpenEdit,
      onOpenHome: widget.onOpenHome,
      onOpenForYou: widget.onOpenForYou,
      onOpenMoments: widget.onOpenMoments,
      onOpenSearch: widget.onOpenSearch,
      onOpenMessages: widget.onOpenMessages,
      onPublishNow: widget.onPublishNow,
      onOpenNotifications: widget.onOpenNotifications,
      onOpenContext: widget.onOpenContext,
    ),
  };
}

String _titleFor(PrincipalRuntimeContext context) =>
    context.groupName ?? context.unitName ?? context.institutionName;
