---
title: "L02 — Hunk para o movimento único das rotas Principal para dentro da ShellRoute"
source: "Frente L02 (Chat e Comunicações), worktree e2-r02-l02-chat-comunicacoes; PRINCIPAL.md decisão final do Owner 09/09/2026; achado estrutural de L01 e L03"
status: "resolucao-de-conflito-para-d00-apos-f5e5d8df"
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


---

# Atualização — resolução do conflito com `dev` após o movimento único

Escrito depois de D00 executar a hospedagem em `f5e5d8df`. Verifiquei `origin/dev` em
**leitura pura** (`git show`, sem merge e sem integrar), na ponta `d7ce6976`.

## O que mudou em `dev`

- As rotas `/principal-*` **agora são filhas do `ShellRoute`**: o `ShellRoute` começa na linha 755 e
  seu `routes:` na 787, com `principalHappens` na 788.
- `embedded: true` já aparece **5 vezes** — o padrão que a minha composição também suporta.
- `SuperadminShell.host` continua estruturalmente igual ao que eu editei: o parâmetro
  `onDestinationSelected` segue sendo a âncora, então **minha inserção de 3 linhas aplica no mesmo
  lugar**.
- Os **três** destinos `?from=principal` continuam lá (linhas 699, 810 e 5468), porque o meu delta
  não está em `dev`.
- **`chatUnreadCountLoader` não aparece em `dev`.** Minha fiação do badge não sobreviveu porque
  nunca esteve lá; ela vem com o meu merge.

## Conflito: um só arquivo

`apps/superadmin/lib/app/router/superadmin_router.dart`. Resolução, trecho a trecho:

1. **Base:** o lado de `dev` prevalece em toda a estrutura de hospedagem. Não reverter o movimento.
2. **Minha rota nova `/principal-conversations`:** deve **sobreviver e entrar dentro do `ShellRoute`**,
   junto das irmãs, com `embedded: true` — não deixá-la de fora do shell. O corpo do builder é o que
   está na seção anterior deste documento, com a falha fechada por
   `_unavailableCompositionRootRoute` preservada.
3. **`/dev/principal-conversations`:** mesmo tratamento, com `developmentChatRepository`.
4. **As 4 constantes** em `superadmin_routes.dart` (`principalConversations`,
   `principalConversationsName`, `devPrincipalConversations`, `devPrincipalConversationsName`):
   não conflitam, apenas somam.
5. **Os 3 destinos `?from=principal`** (linhas 699, 810 e 5468 em `dev`) devem passar a apontar para
   as rotas novas, como no meu `5e0344f0`. Sem isso o launcher do Principal volta a abrir a página
   administrativa e o movimento de hospedagem não resolve o defeito, só o reposiciona.
6. **A fiação do badge** (`chatUnreadCountLoader`) deve entrar nos três shells que o router monta,
   incluindo o `SuperadminShell.host` reescrito, **com a guarda `is UnavailableChatRepository`
   intacta**. Sem a guarda o launcher afirmaria "nenhuma não lida" quando na verdade não sabe.
7. **`mediaReader`/`mediaSession` em `/dev/conversations`:** somam, não conflitam.

## O que eu não fiz, deliberadamente

Não integrei `dev`, não fiz merge nem rebase, e não rodei minhas provas contra a composição
integrada — isso exigiria materializar a base conjunta, que é do integrador. A verificação acima é
de leitura. **Depois do merge, os arquivos a reexecutar são
`principal_chat_route_test.dart`, `chat_unread_badge_wiring_test.dart` e `chat_routes_test.dart`**:
são os que afirmam exatamente os pontos 2, 5 e 6 e, se a resolução perder algum deles, eles falham.

---

# Apêndice — blocos prontos para colar (contra `origin/dev` `d7ce6976`)

Nada aqui é descrição: são os trechos finais, já reindentados para o lugar onde entram.
Linhas citadas são as de `dev` lidas com `git show`, sem merge.

## 1. `superadmin_routes.dart` — 4 constantes

Somam, não conflitam. Junto das demais `principal*`:

```dart
  static const principalConversations = '/principal-conversations';
  static const principalConversationsName = 'principal-conversations';
```

e junto das `devPrincipal*`:

```dart
  static const devPrincipalConversations = '/dev/principal-conversations';
  static const devPrincipalConversationsName = 'dev-principal-conversations';
```

## 2. `superadmin_router.dart` — import

```dart
import '../../features/principal_chat/presentation/principal_chat_page.dart';
```

## 3. Rota de produção — **dentro** da lista `routes:` do `ShellRoute`

Indentação de 10 espaços, igual às irmãs a partir da linha 788 de `dev`:

```dart
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

## 4. Rota `/dev` — mesma lista

```dart
          GoRoute(
            path: SuperadminRoutes.devPrincipalConversations,
            name: SuperadminRoutes.devPrincipalConversationsName,
            builder: (context, state) => PrincipalChatPage(
              chatRepository: developmentChatRepository,
              embedded: true,
              onBack: () => context.goNamed(SuperadminRoutes.devPrincipalHappensName),
              onOpenProfile: () => context.goNamed(SuperadminRoutes.devPrincipalProfileName),
            ),
          ),
```

## 5. Os três destinos — trocas exatas

**`dev` linha 697-700** (`/dev/principal-happens`), de:

```dart
          onOpenMessages: () => context.goNamed(
            SuperadminRoutes.devConversationsName,
            queryParameters: const {'from': 'principal'},
          ),
```

para:

```dart
          onOpenMessages: () =>
              context.goNamed(SuperadminRoutes.devPrincipalConversationsName),
```

**`dev` linha 808-811** (`/principal-happens`, produção), de:

```dart
                  onOpenMessages: () => context.goNamed(
                    SuperadminRoutes.conversationsName,
                    queryParameters: const {'from': 'principal'},
                  ),
```

para:

```dart
                  onOpenMessages: () =>
                      context.goNamed(SuperadminRoutes.principalConversationsName),
```

**`dev` linha 5465-5469** (despacho do menu de desenvolvimento), de:

```dart
    case 'principal-chat':
      context.goNamed(
        SuperadminRoutes.devConversationsName,
        queryParameters: const {'from': 'principal'},
      );
```

para:

```dart
    case 'principal-chat':
      context.goNamed(SuperadminRoutes.devPrincipalConversationsName);
```

## 6. Badge de não lidas — 3 inserções

Em `operationalPage` (composição `/dev`, `dev` linha ~452), junto de `activityController`:

```dart
    chatUnreadCountLoader: developmentChatRepository.fetchUnreadTotal,
```

Em `productionOperationalPage` (`dev` linha ~467), junto de `activityController`:

```dart
    // O launcher só afirma contagem quando existe repositório autorizado.
    // `UnavailableChatRepository.fetchUnreadTotal` devolve 0, e um zero
    // silencioso é indistinguível de "não há não lidas": passar null faz o
    // launcher não afirmar nada em vez de afirmar algo falso.
    chatUnreadCountLoader: chatRepository is UnavailableChatRepository
        ? null
        : chatRepository.fetchUnreadTotal,
```

Em `SuperadminShell.host` (`dev` linha ~760), logo depois de `onDestinationSelected`:

```dart
                  // Mesma regra do shell de produção: sem repositório
                  // autorizado o launcher não afirma contagem alguma.
                  chatUnreadCountLoader: developmentPreview
                      ? developmentChatRepository.fetchUnreadTotal
                      : chatRepository is UnavailableChatRepository
                      ? null
                      : chatRepository.fetchUnreadTotal,
```

**A guarda `is UnavailableChatRepository` não é opcional.** Sem ela o shell chama o repositório
fail-closed, cujo `fetchUnreadTotal` devolve `0`, e o launcher passa a afirmar "não há não lidas"
quando na verdade não sabe.

## 7. Preview `/dev/conversations` — dependências de mídia

No builder de `SuperadminChatPage` daquela rota, junto de `chatRepository`:

```dart
                mediaReader: mediaReader,
                mediaSession: mediaSession,
```

## Os quatro perigos, e o que os pega

| Perigo | Teste que falha se acontecer |
| --- | --- |
| Rota nova ficar **fora** do `ShellRoute` | `principal_chat_route_test.dart` |
| Algum dos 3 destinos não ser trocado | `chat_routes_test.dart`, `principal_chat_route_test.dart` |
| Guarda do badge perdida | `chat_unread_badge_wiring_test.dart` |
| Mídia da preview perdida | `chat_unread_badge_wiring_test.dart` |
