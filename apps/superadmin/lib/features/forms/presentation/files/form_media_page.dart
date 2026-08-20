import 'dart:async';

import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../data/form_media_resolver.dart';

typedef FormMediaResolve = Future<FormMediaDownloadTicket> Function({
  required String assetId,
  String? editSecret,
});
typedef FormMediaImageBuilder = Widget Function(BuildContext context, Uri signedUrl);

final class FormMediaPage extends StatefulWidget {
  const FormMediaPage({
    required this.assetId,
    required this.resolve,
    this.editSecret,
    this.imageBuilder,
    super.key,
  });

  final String assetId;
  final String? editSecret;
  final FormMediaResolve resolve;
  final FormMediaImageBuilder? imageBuilder;

  @override
  State<FormMediaPage> createState() => _FormMediaPageState();
}

final class _FormMediaPageState extends State<FormMediaPage> {
  FormMediaDownloadTicket? _ticket;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final ticket = await widget.resolve(assetId: widget.assetId, editSecret: widget.editSecret);
      if (mounted) setState(() => _ticket = ticket);
    } catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failure != null) {
      return const CoeloStatePanel(
        title: 'Mídia indisponível',
        message: 'O arquivo não existe ou você não tem permissão para acessá-lo.',
        icon: Icons.lock_outline_rounded,
      );
    }
    final ticket = _ticket;
    if (ticket == null) {
      return const CoeloStatePanel(
        title: 'Carregando mídia',
        message: 'Validando seu acesso ao arquivo privado.',
        loading: true,
      );
    }
    final builder = widget.imageBuilder;
    return Scaffold(
      appBar: AppBar(title: const Text('Mídia do formulário')),
      body: Center(
        child: builder?.call(context, ticket.signedUrl) ??
            Image.network(
              ticket.signedUrl.toString(),
              fit: BoxFit.contain,
              semanticLabel: 'Imagem anexada à resposta',
              errorBuilder: (context, error, stackTrace) => const CoeloStatePanel(
                title: 'Mídia indisponível',
                message: 'O link temporário expirou. Abra o arquivo novamente.',
                icon: Icons.broken_image_outlined,
              ),
            ),
      ),
    );
  }
}
