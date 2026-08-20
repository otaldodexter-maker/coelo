import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/form_anonymous_edit_secret_store.dart';
import 'form_response_page.dart';

final class FormResponseRoutePage extends StatefulWidget {
  const FormResponseRoutePage({required this.api, required this.occurrenceId, super.key});

  final FormsApi? api;
  final String occurrenceId;

  @override
  State<FormResponseRoutePage> createState() => _FormResponseRoutePageState();
}

final class _FormResponseRoutePageState extends State<FormResponseRoutePage> {
  FormAnonymousEditSecretStore? _secretStore;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStore());
  }

  Future<void> _loadStore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _secretStore = SharedPreferencesFormAnonymousEditSecretStore(preferences));
      }
    } catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failure != null) {
      return const CoeloStatePanel(
        title: 'Resposta indisponível',
        message: 'Não foi possível abrir o armazenamento seguro deste dispositivo.',
        icon: Icons.lock_outline_rounded,
      );
    }
    final secretStore = _secretStore;
    if (secretStore == null) {
      return const CoeloStatePanel(
        title: 'Abrindo formulário',
        message: 'Preparando a edição segura da resposta.',
        loading: true,
      );
    }
    return FormResponsePage(
      api: widget.api,
      occurrenceId: widget.occurrenceId,
      secretStore: secretStore,
    );
  }
}
