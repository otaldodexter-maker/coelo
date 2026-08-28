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
    this.now = DateTime.now,
    this.onOpenHappens,
    this.onOpenNow,
    this.onOpenMoments,
    this.onOpenAgenda,
    this.onOpenProfile,
  });

  final NoticeRepository repository;
  final PrincipalForYouPreviewData supportingData;
  final DateTime Function() now;
  final VoidCallback? onOpenHappens;
  final VoidCallback? onOpenNow;
  final VoidCallback? onOpenMoments;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenProfile;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrincipalForYouRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        identical(oldWidget.supportingData, widget.supportingData) &&
        identical(oldWidget.now, widget.now)) {
      return;
    }
    _load();
  }

  Future<void> _load() async {
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
      final highlights = PrincipalForYouCommunicationsAdapter.highlights(page.items, now: now());
      if (!mounted || generation != _loadGeneration) return;
      setState(
        () => _state = _Loaded(
          supportingData.copyWith(highlights: highlights),
          empty: highlights.isEmpty,
        ),
      );
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

  @override
  void dispose() {
    _loadGeneration += 1;
    super.dispose();
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
        data: data,
        onOpenHappens: widget.onOpenHappens,
        onOpenNow: widget.onOpenNow,
        onOpenMoments: widget.onOpenMoments,
        onOpenAgenda: widget.onOpenAgenda,
        onOpenProfile: widget.onOpenProfile,
      ),
    ),
  };
}
