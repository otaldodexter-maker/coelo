import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../notices/domain/notice_repository.dart';
import '../../notices/domain/platform_notice.dart';
import '../data/principal_for_you_communications_adapter.dart';
import '../domain/principal_for_you_preview_data.dart';
import 'principal_for_you_preview_page.dart';

final class PrincipalForYouRoutePage extends StatefulWidget {
  const PrincipalForYouRoutePage({
    super.key,
    required this.repository,
    required this.supportingData,
    required this.audienceScope,
    this.embedded = false,
    this.now = DateTime.now,
    this.onOpenHappens,
    this.onOpenNow,
    this.onOpenMoments,
    this.onOpenAgenda,
    this.onOpenProfile,
    this.onOpenMessages,
    this.onOpenActivities,
  });

  final NoticeRepository repository;
  final PrincipalForYouPreviewData supportingData;

  /// Server-authorized scope of the actor. Audience eligibility is evaluated
  /// against it before any communication reaches the hub.
  final PrincipalForYouAudienceScope audienceScope;

  /// Whether the Superadmin shell already provides the surrounding chrome.
  final bool embedded;
  final DateTime Function() now;
  final VoidCallback? onOpenHappens;
  final VoidCallback? onOpenNow;
  final VoidCallback? onOpenMoments;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onOpenActivities;

  @override
  State<PrincipalForYouRoutePage> createState() => _PrincipalForYouRoutePageState();
}

sealed class _LoadState {
  const _LoadState();
}

final class _Loading extends _LoadState {
  const _Loading();
}

final class _Loaded extends _LoadState {
  const _Loaded(this.data, {required this.empty});
  final PrincipalForYouPreviewData data;
  final bool empty;
}

final class _Failed extends _LoadState {
  const _Failed();
}

final class _Unauthorized extends _LoadState {
  const _Unauthorized();
}

final class _PrincipalForYouRoutePageState extends State<PrincipalForYouRoutePage> {
  _LoadState _state = const _Loading();
  var _loadGeneration = 0;
  Timer? _validityTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrincipalForYouRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The route builder constructs the scope and the supporting labels fresh on
    // every build. Comparing them by instance treated each rebuild as a new
    // actor: the hub re-read the whole directory and flashed its spinner
    // whenever anything above it rebuilt. Only a different actor, repository or
    // clock is a reason to ask the server again.
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.audienceScope != widget.audienceScope ||
        !identical(oldWidget.now, widget.now)) {
      _load();
      return;
    }
    if (identical(oldWidget.supportingData, widget.supportingData)) return;
    // Only the surrounding labels changed. They are re-rendered over the
    // projection the server already authorized, never re-fetched.
    if (_state case _Loaded(:final data, :final empty)) {
      setState(
        () => _state = _Loaded(
          widget.supportingData.copyWith(highlights: data.highlights),
          empty: empty,
        ),
      );
    }
  }

  Future<void> _load() async {
    _validityTimer?.cancel();
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final supportingData = widget.supportingData;
    final now = widget.now;
    setState(() => _state = const _Loading());
    try {
      final page = await repository.fetchPage(
        const NoticeDirectoryQuery(
          types: {CommunicationType.highlight, CommunicationType.content, CommunicationType.forYou},
          statuses: {NoticeStatus.active},
          pageSize: 100,
        ),
      );
      if (!mounted || generation != _loadGeneration) return;
      _project(List.unmodifiable(page.items), supportingData, now, generation);
    } on NoticeUnauthorizedException {
      if (mounted && generation == _loadGeneration) {
        setState(() => _state = const _Unauthorized());
      }
    } on NoticeRepositoryException {
      if (mounted && generation == _loadGeneration) {
        setState(() => _state = const _Failed());
      }
    } on Object {
      if (mounted && generation == _loadGeneration) {
        setState(() => _state = const _Failed());
      }
    }
  }

  void _project(
    List<PlatformNotice> communications,
    PrincipalForYouPreviewData supportingData,
    DateTime Function() clock,
    int generation,
  ) {
    if (!mounted || generation != _loadGeneration) return;
    _validityTimer?.cancel();
    final now = clock();
    final highlights = PrincipalForYouCommunicationsAdapter.highlights(
      communications,
      now: now,
      scope: widget.audienceScope,
    );
    setState(
      () => _state = _Loaded(
        supportingData.copyWith(highlights: highlights),
        empty: !highlights.any((item) => item.eligible),
      ),
    );
    DateTime? nextBoundary;
    for (final item in communications) {
      if (item.type == CommunicationType.notice || item.status != NoticeStatus.active) continue;
      for (final boundary in [item.startsAt, item.endsAt]) {
        if (boundary != null &&
            boundary.isAfter(now) &&
            (nextBoundary == null || boundary.isBefore(nextBoundary))) {
          nextBoundary = boundary;
        }
      }
    }
    if (nextBoundary != null) {
      _validityTimer = Timer(
        nextBoundary.difference(now),
        () => _project(communications, supportingData, clock, generation),
      );
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _validityTimer?.cancel();
    super.dispose();
  }

  /// Routes a hub action to a real destination, or says plainly that the
  /// capability is not available yet. A production route never answers with the
  /// preview message.
  void _handleAction(String label) {
    final destination = switch (label) {
      'Agenda' => widget.onOpenAgenda,
      'Mensagens' => widget.onOpenMessages,
      'Atividades' => widget.onOpenActivities,
      _ => null,
    };
    if (destination != null) {
      destination();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label ainda não está disponível.')));
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
    _Loading() => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Semantics(
          liveRegion: true,
          label: 'Carregando Para você',
          child: const CircularProgressIndicator(key: Key('principal-for-you-loading')),
        ),
      ),
    ),
    _Failed() => Scaffold(
      key: const Key('principal-for-you-error'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: CoeloSize.iconLg,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              Text(
                'Não foi possível carregar Para você.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              FilledButton.tonal(onPressed: _load, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      ),
    ),
    _Unauthorized() => Scaffold(
      key: const Key('principal-for-you-unauthorized'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: CoeloSize.iconLg,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              Text(
                'Acesso não disponível.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    ),
    _Loaded(:final data, :final empty) => KeyedSubtree(
      key: empty ? const Key('principal-for-you-empty') : null,
      child: PrincipalForYouPreviewPage(
        embedded: widget.embedded,
        data: data,
        onOpenHappens: widget.onOpenHappens,
        onOpenNow: widget.onOpenNow,
        onOpenMoments: widget.onOpenMoments,
        onOpenAgenda: widget.onOpenAgenda,
        onOpenProfile: widget.onOpenProfile,
        onOpenMessages: widget.onOpenMessages,
        onAction: _handleAction,
      ),
    ),
  };
}
