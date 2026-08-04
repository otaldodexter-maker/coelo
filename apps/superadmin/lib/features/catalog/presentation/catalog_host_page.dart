import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import 'catalog_platform_host.dart';

void openConfiguredCatalogExternally(String catalogUrl, {ValueChanged<Uri>? openExternally}) {
  final uri = resolveCatalogOrigin(catalogUrl, hostOrigin: catalogHostOrigin);
  if (uri != null) {
    (openExternally ?? openCatalogExternally)(uri);
  }
}

final class CatalogHostPage extends StatelessWidget {
  const CatalogHostPage({
    required this.catalogUrl,
    required this.logout,
    required this.onInstitutionsOpen,
    this.onUnitsOpen,
    this.onHomeOpen,
    this.onSupportOpen,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.localPreview = false,
    super.key,
  });

  final String catalogUrl;
  final LogoutAction logout;
  final VoidCallback onInstitutionsOpen;
  final VoidCallback? onUnitsOpen;
  final VoidCallback? onHomeOpen;
  final VoidCallback? onSupportOpen;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final bool localPreview;

  @override
  Widget build(BuildContext context) {
    final uri = resolveCatalogOrigin(catalogUrl, hostOrigin: catalogHostOrigin);
    return SuperadminShell(
      title: 'Catálogo',
      subtitle: 'Consulte fundamentos, componentes e padrões aprovados.',
      logout: logout,
      currentDestination: 'catalog',
      onBugReportSubmitted: onBugReportSubmitted,
      onOpenConversations: onConversationsOpen,
      onDestinationSelected: (destination) {
        if (destination == 'home') {
          onHomeOpen?.call();
        } else if (destination == 'institutions') {
          onInstitutionsOpen();
        } else if (destination == 'units') {
          onUnitsOpen?.call();
        } else if (destination == 'support') {
          onSupportOpen?.call();
        }
      },
      actions: [
        if (uri != null && !localPreview)
          OutlinedButton.icon(
            key: const Key('catalog-open-external'),
            onPressed: catalogEmbeddingSupported ? () => openCatalogExternally(uri) : null,
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Abrir catálogo em nova aba'),
          ),
      ],
      compactActions: [
        if (uri != null && !localPreview)
          IconButton(
            tooltip: 'Abrir catálogo em nova aba',
            onPressed: catalogEmbeddingSupported ? () => openCatalogExternally(uri) : null,
            icon: const Icon(Icons.open_in_new_outlined),
          ),
      ],
      child: localPreview && uri != null && _isLocalCatalog(uri)
          ? buildCatalogPlatformHost(uri)
          : localPreview
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(CoeloSpacing.space6),
                child: CoeloStatePanel(
                  key: Key('catalog-local-preview'),
                  title: 'Catálogo local',
                  message: 'Preview local disponível sem depender do domínio externo.',
                  icon: Icons.widgets_outlined,
                ),
              ),
            )
          : uri == null
          ? const CoeloStatePanel(
              title: 'Endereço do catálogo indisponível',
              message: 'Configure uma origem HTTPS própria para o catálogo.',
              icon: Icons.link_off_outlined,
            )
          : catalogEmbeddingSupported
          ? buildCatalogPlatformHost(uri)
          : _CatalogPlatformFallback(uri: uri),
    );
  }

  static bool _isLocalCatalog(Uri uri) =>
      uri.scheme == 'http' && (uri.host == '127.0.0.1' || uri.host == 'localhost');
}

final class _CatalogPlatformFallback extends StatelessWidget {
  const _CatalogPlatformFallback({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: CoeloStatePanel(
          key: const Key('catalog-platform-fallback'),
          title: 'Catálogo disponível no navegador',
          message: 'Abra ${uri.origin} em uma nova aba para consultar o conteúdo.',
          icon: Icons.web_outlined,
        ),
      ),
    );
  }
}

@visibleForTesting
Uri? resolveCatalogOrigin(String value, {String? hostOrigin}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return null;
  }
  final localHttp = uri.scheme == 'http' && (uri.host == '127.0.0.1' || uri.host == 'localhost');
  if (uri.scheme != 'https' && !localHttp) {
    return null;
  }
  final normalized = uri.replace(path: '/');
  final currentHost = hostOrigin == null ? null : Uri.tryParse(hostOrigin.trim());
  if (currentHost != null && currentHost.hasAuthority && currentHost.origin == normalized.origin) {
    return null;
  }
  return normalized;
}
