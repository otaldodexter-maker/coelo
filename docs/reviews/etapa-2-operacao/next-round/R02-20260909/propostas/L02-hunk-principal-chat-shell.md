---
title: "L02 — Hunk para o movimento único das rotas Principal para dentro da ShellRoute"
source: "Frente L02 (Chat e Comunicações), worktree e2-r02-l02-chat-comunicacoes; PRINCIPAL.md decisão final do Owner 09/09/2026; achado estrutural de L01 e L03"
status: "hunk-pronto-para-o-movimento-coordenado-por-d00"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Objetivo

L00 pediu que eu registrasse, no formato de `L01-hunks-composicao.md`, o hunk da
minha rota nova para o **movimento único** que leva as rotas `/principal-*` para
dentro da `ShellRoute`. Este documento é só isso. Não descreve a rota em si, que
**já está aplicada e publicada** sob reserva concedida (`5e0344f0`).

Diferença em relação ao documento de L01: lá os hunks ainda não foram aplicados
porque atravessam a cadeia de composição. Aqui a rota já existe e funciona; o que
falta é exclusivamente reposicioná-la na árvore de rotas, junto com as irmãs.

## Por que o movimento é único e não se serializa

Achado estrutural de L01 e L03, que eu confirmo por leitura: as rotas `/principal-*`
são declaradas como **irmãs** da `ShellRoute` (`superadmin_router.dart:961`), não
como filhas. Consequência: o shell nunca é construído para elas — o teste
`principal_real_route_test.dart` inclusive afirma
`find.byKey(Key('superadmin-persistent-shell')) findsNothing` como comportamento
esperado hoje.

A decisão final do Owner de 09/09/2026, registrada em `PRINCIPAL.md` e confirmada
por mim no commit `eaab2df13` da `dev`, é que o shell/menu hospedeiro é preservado
no web **e** no mobile, com a experiência Principal no contêiner de conteúdo. Isso
torna o ajuste **estrutural, não visual**.

Se apenas uma frente mover a sua rota, o menu some ao navegar entre telas irmãs,
porque metade das rotas Principal fica dentro do shell e metade fora. Por isso
**não movi** a minha por conta própria, mesmo tendo reserva no arquivo.

## Estado atual das minhas rotas

Ambas em `apps/superadmin/lib/app/router/superadmin_router.dart`, hoje irmãs da
`ShellRoute`:

- produção: `path: SuperadminRoutes.principalConversations` (linha ~701),
  `name: principalConversationsName`;
- desenvolvimento: `path: SuperadminRoutes.devPrincipalConversations` (linha ~901),
  `name: devPrincipalConversationsName`.

Constantes em `superadmin_routes.dart`: `principalConversations` =
`/principal-conversations`, `devPrincipalConversations` = `/dev/principal-conversations`,
mais os dois `*Name`.

## O hunk

A composição **já suporta** o movimento: `PrincipalChatPage` tem o parâmetro
`embedded`, e quando ele é `true` a página não desenha `Scaffold` nem
`PrincipalGlobalHeader`, entregando só o conteúdo para o contêiner do hospedeiro.
Isso está coberto por teste
(`principal_chat_page_test.dart` › *"hosted in the shell container it draws no chrome of its own"*),
que monta a página dentro de um shell e afirma que o shell continua visível e o
cabeçalho do Principal não aparece.

Portanto o hunk é mínimo: mover o bloco `GoRoute` para dentro dos `routes:` da
`ShellRoute` e passar `embedded: true`.

```dart
// De (irmã da ShellRoute, como está hoje):
GoRoute(
  path: SuperadminRoutes.principalConversations,
  name: SuperadminRoutes.principalConversationsName,
  builder: (context, state) => chatRepository is UnavailableChatRepository
      ? _unavailableCompositionRootRoute(context)
      : PrincipalChatPage(
          chatRepository: chatRepository,
          onBack: () => context.goNamed(SuperadminRoutes.principalHappensName),
          onOpenProfile: () => context.goNamed(SuperadminRoutes.principalProfileName),
        ),
),

// Para (filha da ShellRoute, no movimento único):
GoRoute(
  path: SuperadminRoutes.principalConversations,
  name: SuperadminRoutes.principalConversationsName,
  builder: (context, state) => chatRepository is UnavailableChatRepository
      ? _unavailableCompositionRootRoute(context)
      : PrincipalChatPage(
          chatRepository: chatRepository,
          embedded: true,
          onBack: () => context.goNamed(SuperadminRoutes.principalHappensName),
          onOpenProfile: () => context.goNamed(SuperadminRoutes.principalProfileName),
        ),
),
```

O mesmo vale para a rota `/dev`, trocando `chatRepository` por
`developmentChatRepository` e mantendo os destinos de `/dev` no `onBack`.

Nada além disso muda no meu lado: a falha fechada, os destinos e o retorno
contextual permanecem idênticos.

## O que o movimento quebra nos meus testes, e que eu conserto na hora

Dois casos meus assumem o estado atual e vão precisar de ajuste **no mesmo commit
do movimento**, não antes:

1. `principal_chat_route_test.dart` › *"the Principal messages launcher opens the
   Principal composition"* — passa a poder afirmar também que
   `Key('superadmin-persistent-shell')` está presente, o que hoje seria falso.
2. `principal_chat_page_test.dart` › *"renders its own Principal chrome"* — continua
   válido para o modo **não** embutido, que segue existindo; nenhum ajuste previsto.

Não vou alterá-los preventivamente: até o movimento acontecer, eles descrevem o
comportamento real, e mudá-los antes deixaria testes verdes descrevendo algo que o
código não faz.

## Ordem

Ordem combinada de escrita no arquivo: **L03 → L01 → L02**. Meu bloco é novo e não
colide com os builders alterados por L03 (Perfil e Para Você) nem por L01
(`/principal-happens` e `/principal-moments`). Para o movimento único, porém, a
ordem deixa de importar: ele precisa ser **um** commit que reposiciona todas as
rotas Principal de uma vez, montado por D00.

## Dependência que eu não resolvo

Se o movimento exigir que o shell passe a construir conteúdo Principal com a
navegação responsiva do hospedeiro, isso é implementação e prova da frente L01,
conforme `PRINCIPAL.md`. Eu entrego a superfície pronta para ser hospedada e o
hunk acima; não vou redesenhar o shell.
