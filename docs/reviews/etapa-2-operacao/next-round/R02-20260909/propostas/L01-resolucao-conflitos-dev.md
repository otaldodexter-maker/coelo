---
title: "L01 — resolução dos conflitos com dev e injeções ainda abertas"
source: "origin/dev f5e5d8dfc (movimento único de hospedagem de D00); branch codex/e2-r02-l01-publicacoes"
status: "blocos-prontos-para-aplicacao-pelo-coordenador"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Resolução dos conflitos de L01 com `dev`, e o que ainda falta

## O que o movimento de D00 já resolveu, e o que não resolveu

**Superado:** mover as rotas do Principal para dentro do `ShellRoute` e passar
`embedded: true`. Está em `dev` (`f5e5d8dfc`). A metade correspondente da minha proposta
`L01-hunks-composicao.md` está feita e já a marquei como superada lá.

**NÃO superado:** a cadeia de injeção. Verificado por leitura de `origin/dev`. Os cinco
defeitos que prendi em teste **sobreviveram ao movimento** — a hospedagem resolveu o encaixe
visual e não resolveu o acesso ao dado.

`superadmin_router.dart` **não conflita** com esta branch, porque não o toquei.

---

## Conflito 1 — `principal_moments_publication_route.dart` — UNIÃO OBRIGATÓRIA

**Este é o conflito perigoso.** Os dois lados fizeram mudanças **diferentes** no mesmo
arquivo: `dev` acrescentou a flag `embedded` e o repasse dela; esta branch acrescentou a
porta `mediaPicker` com o seletor de arquivos padrão.

**Resolver escolhendo um lado apaga função real.** Ficando só com `dev`, a rota produtiva
de publicar Momentos volta a não conseguir publicar nada, porque o controller exige ao menos
uma mídia e não haverá porta de seleção — que é exatamente o defeito corrigido nesta rodada.
Ficando só com esta branch, perde-se a hospedagem. As duas mudanças **não se tocam**.

Arquivo resolvido, pronto para colar por inteiro:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../application/moments_publication_controller.dart';
import '../domain/moments_publication.dart';
import 'principal_moments_publication_page.dart';

/// Owns the production controller lifecycle for the real Momentos publisher.
final class PrincipalMomentsPublicationRoute extends StatefulWidget {
  const PrincipalMomentsPublicationRoute({
    required this.repository,
    required this.publicationContext,
    this.onClose,
    this.onPublished,
    this.mediaPicker,
    this.embedded = false,
    super.key,
  });

  final MomentsPublicationRepository repository;
  final bool embedded;
  final MomentsPublicationContext publicationContext;
  final VoidCallback? onClose;
  final ValueChanged<MomentsPublication>? onPublished;

  /// Media selection port. Defaults to the local file selection used by the
  /// other Principal publishers; tests inject a deterministic one.
  final MomentsMediaPicker? mediaPicker;

  @override
  State<PrincipalMomentsPublicationRoute> createState() => _PrincipalMomentsPublicationRouteState();
}

final class _PrincipalMomentsPublicationRouteState extends State<PrincipalMomentsPublicationRoute> {
  late MomentsPublicationController _controller;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(covariant PrincipalMomentsPublicationRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        oldWidget.publicationContext == widget.publicationContext) {
      return;
    }
    _controller.dispose();
    _createController();
  }

  void _createController() {
    _controller = MomentsPublicationController(
      repository: widget.repository,
      context: widget.publicationContext,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrincipalMomentsPublicationPage(
    controller: _controller,
    embedded: widget.embedded,
    mediaPicker: widget.mediaPicker ?? pickMomentsMediaFiles,
    onClose: widget.onClose,
    onPublished: widget.onPublished,
  );
}

/// Local file selection for the productive Momentos publisher.
///
/// It only reads bytes the person chose. Bucket, key, provider, tenant and
/// authorization stay server-side: the media reaches R2 through the
/// `moments-media` server path when the publication is accepted.
Future<List<MomentsMediaCandidate>> pickMomentsMediaFiles() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.custom,
    allowedExtensions: MomentsMediaLimits.acceptedExtensions,
  );
  return (result?.files ?? const <PlatformFile>[])
      .where((file) => file.bytes != null)
      .map(
        (file) => MomentsMediaCandidate(
          name: file.name,
          mimeType: _mimeType(file.extension),
          bytes: file.bytes!,
        ),
      )
      .toList(growable: false);
}

String _mimeType(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'application/octet-stream',
};
```

Diferenças em relação ao lado de `dev`, para conferência rápida: o import de `file_picker`;
o parâmetro `this.mediaPicker`; o campo `MomentsMediaPicker? mediaPicker`; a linha
`mediaPicker: widget.mediaPicker ?? pickMomentsMediaFiles` no `build`; e as duas funções de
apoio no fim. Tudo o mais é idêntico a `dev`, inclusive `embedded: widget.embedded`, que
substitui o `embedded: false` que esta branch tinha.

**Verificação depois de aplicar:** `flutter test test/features/principal_moments_publication/`
deve dar 88 aprovados, e `test/app/router/principal_moments_publication_route_test.dart`
deve continuar verde.

---

## Conflito 2 — `principal_now_preview_page.dart` — BENIGNO, ficar com `dev`

Os dois lados fizeram **a mesma coisa**: a flag `embedded` e o helper `_hostSafeArea`, para
o viewer não reaplicar os insets que o hospedeiro já consumiu. São semanticamente
equivalentes.

**Resolução: ficar integralmente com o lado de `dev`.** Nada se perde.

Único reaproveitamento que vale, e é opcional: os comentários de documentação desta branch
explicam **por que** a flag existe — a decisão do Owner de 09/09 e o fato de o hospedeiro já
ter consumido os insets. O código de `dev` não registra isso, e é o tipo de porquê que se
perde e depois ninguém reconstrói. Se for barato, colar sobre o campo `embedded`:

```dart
  /// Marks the viewer as hosted inside the Superadmin shell content area.
  ///
  /// The host keeps its own shell/menu visible (Owner decision of 2026-09-09),
  /// so the viewer must not re-apply the system insets the host already
  /// consumed. The immersive composition itself is unchanged.
  final bool embedded;
```

---

## Injeção 1 — feed misto no Acontece — UM ÚNICO SÍTIO

Fecha o subaceite obrigatório `circulars.happens-card` de `acontece.feed`.

**Boa notícia:** a cadeia já está inteira em `dev`. `principalMixedFeedRepository` é
instanciado em `superadmin_auth_scope.dart:372`, declarado em `:209`, devolvido como `null`
no caminho sem sessão em `:440`, repassado em `superadmin_app.dart:281` e em `main.dart:58`,
e chega ao parâmetro do router. **Falta só o builder usá-lo.**

Em `superadmin_router.dart` de `dev`, o builder de `SuperadminRoutes.principalHappens`
(por volta da linha 788) constrói `PrincipalHappensPreviewPage(...)` com `feedRepository` e
`data: PrincipalHappensPreviewData.empty`. Trocar pelo construtor `.mixed`, que já existe na
página, quando o repositório de feed misto estiver disponível:

```dart
                final repository = principalHappensFeedRepository;
                if (repository == null) return _unavailableCompositionRootRoute(context);
                final mixed = principalMixedFeedRepository;
                if (mixed != null) {
                  return PrincipalHappensPreviewPage.mixed(
                    mixedFeedRepository: mixed,
                    mixedFeedScope: CircularScope(
                      institutionId: runtimeContext.institutionId,
                      unitId: runtimeContext.unitId,
                      groupId: runtimeContext.groupId,
                    ),
                    mediaRepository: repository,
                    onOpenCircular: (circularId) => context.goNamed(
                      SuperadminRoutes.circularDetailName,
                      pathParameters: {'circularId': circularId},
                    ),
                    data: PrincipalHappensPreviewData.empty,
                    embedded: true,
                    onCreatePost: () => context.goNamed(SuperadminRoutes.principalHappensPublishName),
                    onOpenNow: () => context.pushNamed(SuperadminRoutes.principalNowName),
                    onPublishNow: () => context.goNamed(SuperadminRoutes.principalNowPublicationName),
                    onOpenMessages: () => context.goNamed(
                      SuperadminRoutes.conversationsName,
                      queryParameters: const {'from': 'principal'},
                    ),
                  );
                }
                return PrincipalHappensPreviewPage(
                  // ... exatamente o que já existe hoje, como caminho de exceção
                );
```

Import necessário no router, se ainda não estiver lá:
`import '../../features/principal_circulars/domain/circular_repository.dart';` para
`CircularScope`.

**Cuidado que precisa ser dito:** o construtor `.mixed` fixa `feedScope = null`, ou seja, a
página passa a ler **só** o feed misto. Isso é o desejado, porque `list_visible_happens_feed`
já devolve publicações **e** Circulares — mas significa que o caminho antigo deixa de rodar
quando o misto existir. Por isso o `if`: sem repositório misto, o comportamento atual
permanece intacto.

**Verificação depois de aplicar:** o meu teste
`test/app/router/principal_happens_composition_gaps_test.dart`, primeiro caso, **passa a
falhar** — e isso é o resultado correto. Ele documenta o defeito; quando a injeção entrar,
ele deve ser **invertido**, não apagado, como o cabeçalho dele manda.

---

## Injeção 2 — feed de Momentos — CADEIA COMPLETA, tira a rota do beco

`/principal-moments` devolve `_unavailableCompositionRootRoute` incondicionalmente em `dev`
(linha 957). **`PrincipalMomentsFeedRepository` não existe em nenhum ponto da composição** —
nem em `superadmin_auth_scope.dart`, nem em `superadmin_app.dart`, nem em `main.dart`, nem
como parâmetro do router. A cadeia inteira precisa ser criada, na ordem:

1. `superadmin_auth_scope.dart` — junto de `principalHappensFeedRepository`: parâmetro em
   `:156`, campo em `:208`, instância `SupabasePrincipalMomentsFeedRepository(client)` em
   `:371` e `null` no caminho sem sessão em `:439`. A classe está em
   `features/principal_moments/data/supabase_principal_moments_feed_repository.dart` e
   implementa **os dois seams**, leitura e retirada, então **uma instância basta**.
2. `superadmin_app.dart` — parâmetro em `:144`, campo em `:199`, repasse em `:280`.
3. `main.dart` — repasse em `:57`.
4. `superadmin_router.dart` — parâmetro novo na assinatura, junto de
   `principalMixedFeedRepository`, e o builder de `principalMoments` deixando de devolver a
   composição indisponível para montar `PrincipalMomentsPreviewPage` com `feedRepository`,
   `feedScope` derivado do runtime context e `withdrawalRepository` apontando para a **mesma
   instância**, mais `embedded: true`.

Sem os quatro passos o código não compila; aplicação parcial é detectada pelo analisador.

---

## Injeção 3 — mídia de Circulares — desbloqueia os anexos nas rotas reais

`CircularMediaRepository` também não é injetado em `dev`. Mesma cadeia dos quatro passos,
com `SupabaseCircularMediaRepository(client)`, definida em
`features/principal_circulars/data/supabase_circular_auxiliary_repositories.dart`. Os
consumidores já estão prontos e aceitam o repositório como opcional:

- as duas construções de `ProductionCircularComposerHost` no router, para a seleção e o
  envio de anexos;
- `PrincipalCircularDetailPage`, que já repassa ao leitor — o repasse foi corrigido nesta
  rodada em `df95390bd`.

Sem essa injeção, os anexos continuam honestamente fechados nas telas reais, que é o
caminho de exceção correto, mas não pode ser o caminho normal.

---

## Semântica dos meus testes depois do merge — importante para a lista de verificação

Os dois arquivos que documentam defeito —
`test/app/router/principal_happens_composition_gaps_test.dart` e
`test/app/router/principal_now_real_route_test.dart`, este último em parte — **asseveram o
comportamento defeituoso de hoje**. Portanto:

- **Verde é o esperado** enquanto o defeito existir. Verde não é suspeito.
- **Vermelho significa que alguém corrigiu a composição** — e aí o teste deve ser
  **invertido**, não apagado, conforme o cabeçalho de cada um.

Um teste que documenta defeito tem a semântica trocada em relação a um teste comum, e é
fácil ler ao contrário numa lista de verificação pós-merge.
