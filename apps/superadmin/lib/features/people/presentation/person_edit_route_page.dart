import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/logout_action.dart';
import '../domain/person_directory.dart';
import 'person_form_page.dart';

final class PersonEditRoutePage extends StatefulWidget {
  const PersonEditRoutePage({
    required this.personId,
    required this.repository,
    required this.logout,
    this.onCancel,
    this.onSaved,
    this.onDestinationSelected,
    this.onOpenChildSecurity,
    super.key,
  });

  final String personId;
  final PersonDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCancel;
  final ValueChanged<PersonDirectoryItem>? onSaved;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onOpenChildSecurity;

  @override
  State<PersonEditRoutePage> createState() => _PersonEditRoutePageState();
}

final class _PersonEditRoutePageState extends State<PersonEditRoutePage> {
  late Future<_LoadedPerson> _detail;
  var _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PersonEditRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId ||
        !identical(oldWidget.repository, widget.repository)) {
      _load();
    }
  }

  void _load() {
    final personId = widget.personId;
    final generation = ++_requestGeneration;
    _detail = widget.repository
        .fetchDetail(personId)
        .then((person) => _LoadedPerson(personId, generation, person));
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) => FutureBuilder<_LoadedPerson>(
    future: _detail,
    builder: (context, snapshot) {
      final loaded = snapshot.data;
      if (loaded != null &&
          loaded.requestedId == widget.personId &&
          loaded.generation == _requestGeneration &&
          loaded.person.id == widget.personId) {
        return PersonFormPage(
          key: ValueKey('person-form-${loaded.person.id}'),
          repository: widget.repository,
          logout: widget.logout,
          original: loaded.person,
          onCancel: widget.onCancel,
          onSaved: widget.onSaved,
          onDestinationSelected: widget.onDestinationSelected,
          onOpenChildSecurity: widget.onOpenChildSecurity,
        );
      }
      final error = snapshot.error;
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space6),
            child: Center(
              child: error is PersonDirectoryUnauthorizedException
                  ? const CoeloStatePanel(
                      title: 'Acesso não autorizado',
                      message: 'Você não possui permissão para consultar esta pessoa.',
                      icon: Icons.lock_outline_rounded,
                    )
                  : error != null
                  ? CoeloStatePanel(
                      title: 'Não foi possível carregar a pessoa',
                      message: 'Tente novamente em instantes.',
                      icon: Icons.error_outline_rounded,
                      actionLabel: 'Tentar novamente',
                      onAction: _retry,
                    )
                  : const CoeloStatePanel(
                      title: 'Carregando pessoa',
                      message: 'Aguarde enquanto buscamos os dados.',
                      loading: true,
                    ),
            ),
          ),
        ),
      );
    },
  );
}

final class _LoadedPerson {
  const _LoadedPerson(this.requestedId, this.generation, this.person);

  final String requestedId;
  final int generation;
  final PersonDirectoryItem person;
}
