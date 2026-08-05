import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/logout_action.dart';
import '../../safety/domain/child_safety.dart';
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
    this.childSafetyStore,
    this.onOpenChildSecurity,
    super.key,
  });

  final String personId;
  final PersonDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCancel;
  final ValueChanged<PersonDirectoryItem>? onSaved;
  final ValueChanged<String>? onDestinationSelected;
  final ChildSafetyStore? childSafetyStore;
  final VoidCallback? onOpenChildSecurity;

  @override
  State<PersonEditRoutePage> createState() => _PersonEditRoutePageState();
}

final class _PersonEditRoutePageState extends State<PersonEditRoutePage> {
  late Future<PersonDirectoryItem> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.repository.fetchDetail(widget.personId);
  }

  @override
  void didUpdateWidget(covariant PersonEditRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId ||
        !identical(oldWidget.repository, widget.repository)) {
      _detail = widget.repository.fetchDetail(widget.personId);
    }
  }

  void _retry() => setState(() {
    _detail = widget.repository.fetchDetail(widget.personId);
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<PersonDirectoryItem>(
    future: _detail,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return PersonFormPage(
          repository: widget.repository,
          logout: widget.logout,
          original: snapshot.requireData,
          onCancel: widget.onCancel,
          onSaved: widget.onSaved,
          onDestinationSelected: widget.onDestinationSelected,
          childSafetyStore: widget.childSafetyStore,
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
