---
title: "Checkpoint da correção UI/UX de Conversas do Superadmin"
source: "Plano aprovado pelo Owner Coelo em 2026-08-04"
status: "completed"
generated_at: "2026-08-04"
updated_at: "2026-08-05"
---

# Checkpoint da correção UI/UX de Conversas do Superadmin

## Encerramento

- Data e hora: 2026-08-04 21:02:01 -03:00.
- Encerramento solicitado em ponto seguro, sem push, merge ou troca de branch.
- Branch observada no início da atividade: `dev`.
- O worktree já estava amplamente sujo e contém muitas alterações concorrentes
  alheias a Conversas; nenhuma delas foi revertida, descartada ou incorporada ao
  escopo deste checkpoint.

## Objetivo original

Corrigir somente a UI/UX da tela Conversas do Superadmin, preservando o Design
System Coelo, sem Supabase, backend, regra de negócio ou arquitetura produtiva.

## Escopo efetivamente trabalhado

- launcher do chat no shell autenticado;
- composição responsiva da página de Conversas;
- facetas, filtros rápidos e seleção visual da inbox;
- bandeiras pessoais da demonstração;
- ritmo visual da thread;
- shell, ações e estados de hover dos popups de grupo, massa, filtros e hierarquia;
- testes focados do launcher e das bandeiras;
- atualização da spec canônica do protótipo.

## Decisões que devem ser preservadas

- Existe exatamente um launcher, pertencente ao shell autenticado.
- A cápsula é laranja, estável e não muda de geometria em hover ou foco.
- Não existe tooltip visual redundante “Abrir conversas”; o nome semântico permanece.
- A posição do launcher é normalizada e armazenada localmente quando o shell
  autenticado habilita persistência; logout bem-sucedido limpa a posição.
- O arraste respeita safe area e a reserva inferior fornecida pela página.
- Responsividade depende das constraints de `LayoutBuilder`.
- Desktop amplo mantém inbox, thread e contexto; larguras menores priorizam a
  thread e usam overlay/sheet para contexto.
- As facetas usam `SuperadminUnderlineTabs`.
- `Fixadas`, `Não lidas` e `Bandeiras` são filtros rápidos combináveis.
- Seleção da conversa usa superfície tonal, indicador laranja fixo e
  `Semantics(selected: true)`.
- Não existe presença artificial nos avatares de pessoa.
- Bandeiras: Urgente/vermelho, Acompanhar/amarelo, Resolvido/verde,
  Aguardando retorno/azul, Sensível/rosa e Restrito temático.
- O ciclo é vazio → vermelho → amarelo → verde → azul → rosa → restrito → vazio.
- Restrito usa `colorScheme.inverseSurface`, nunca `Colors.black` literal.
- A paleta combina ícone e texto; mouse/foco abre legenda, clique não-touch cicla
  e toque abre o seletor.
- Popups reutilizam `CoeloAdminDialogShell`; hover/foco usa
  `primaryContainer/primary` e não cinza.
- Nenhuma alteração de Supabase, envio real, autorização, RLS ou persistência de
  mensagens foi iniciada.

## Referências consultadas

- `.agents/skills/coelo-ui/SKILL.md` e contratos referenciados por ela;
- `.codex/skills/ui-ux-pro-max/SKILL.md`;
- `.agents/skills/ponytail/SKILL.md`;
- `.agents/skills/flutter-build-responsive-layout/SKILL.md`;
- `.agents/skills/rtk/SKILL.md` e `C:\Users\adrie\.codex\RTK.md`;
- `docs/design/design-system.md`;
- `docs/superpowers/specs/2026-07-28-superadmin-chat-local-redesign-design.md`;
- `docs/knowledge/team/superadmin-chat-groups.md`;
- referências conceituais oficiais de WhatsApp, Instagram e Slack já registradas
  no plano aprovado.

## Arquivos criados

- `docs/superpowers/checkpoints/2026-08-04-superadmin-chat-uiux-safe-stop.md`.

## Arquivos alterados neste lote

- `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- `apps/superadmin/lib/features/chat/presentation/chat_models.dart`
- `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`
- `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_advanced_filters.dart`
- `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_flow_dialog.dart`
- `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart`
- `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_inbox.dart`
- `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_launcher.dart`
- `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_thread_body.dart`
- `apps/superadmin/test/app/shell/superadmin_shell_chat_inset_test.dart`
- `apps/superadmin/test/features/chat/presentation/chat_controller_test.dart`
- `apps/superadmin/test/features/chat/presentation/superadmin_chat_launcher_test.dart`
- `docs/superpowers/specs/2026-07-28-superadmin-chat-local-redesign-design.md`

Os mesmos arquivos já continham alterações anteriores em parte do escopo. O
`git diff --stat` abaixo representa o diff acumulado do worktree nesses caminhos,
não atribuição exclusiva desta sessão.

## Concluído

- duplicidade do launcher removida no shell host/embutido;
- geometria animada e `AnimatedSize` removidos do launcher;
- tooltip redundante removido e cápsula laranja estabilizada;
- clamp inferior do drag implementado;
- posição normalizada local e reset no logout implementados com fallback seguro
  quando a plataforma de preferências não está registrada em widget tests;
- facetas lineares, filtros rápidos combináveis e seleção forte da inbox implementados;
- contexto adicional, não lidas e bandeiras ficaram mais escaneáveis;
- seis bandeiras e paleta acessível implementadas;
- divisor de não lidas adicionado à thread e presença artificial removida;
- popups migrados para o shell administrativo canônico;
- ações de filtros 50/50 e estados sem hover cinza implementados;
- spec canônica atualizada;
- todos os arquivos Dart alterados foram formatados;
- análise estática focada final sem issues.

## Parcialmente concluído

- Os testes foram atualizados para launcher único, geometria estável e seis
  bandeiras, mas a suíte final não foi concluída após as últimas correções.
- A paleta de bandeiras usa o comportamento de teclado fornecido por `MenuAnchor`;
  a prova widget específica de setas/Enter/Escape ainda não foi adicionada.
- A persistência local foi implementada, mas ainda falta teste widget com mock da
  plataforma de preferências e simulação de refresh/logout.
- Goldens e validação visual em 375/768/1024/1440, light/dark e reduced motion
  ainda não foram executados.
- O gate `coelo-knowledge` ainda não foi executado após a atualização canônica.
  A projeção de conhecimento não foi alterada.

## Não iniciado

- nenhuma correção dos bugs funcionais auditados em Pessoas/Crianças, Atividades,
  grupo apenas com criança ou deduplicação do envio em massa;
- nenhuma integração produtiva, Supabase ou persistência de mensagens;
- nenhuma atualização de goldens.

## Verificações executadas

- RED inicial:
  - launcher não mostrava “Mensagens” em repouso;
  - launcher voltava ao cinza;
  - shell renderizava 2 launchers.
- Após a primeira correção, a suíte do launcher chegou a 10 testes verdes e um
  teste compacto com expectativa antiga; a expectativa foi atualizada.
- `dart analyze lib/app/shell/superadmin_shell.dart lib/features/chat/presentation`:
  `No issues found!` na execução final após as correções de preferências.
- `dart format`: todos os arquivos Dart alterados formatados; duas inserções
  inicialmente mal posicionadas foram corrigidas antes da análise final.
- Suíte combinada de chat: não concluída. A primeira tentativa incluiu um caminho
  inexistente (`superadmin_chat_responsive_test.dart`), revelou plataforma de
  preferências ausente em widget tests e um ID de fixture inválido. Os dois
  problemas de código/teste foram corrigidos.
- O reteste isolado posterior excedeu 120 segundos por contenção de múltiplos
  processos Flutter/Dart concorrentes e foi encerrado pelo timeout; não há
  resultado verde final a declarar.

## Erros, avisos e bloqueios atuais

- Nenhum erro de análise estática no shell/chat.
- Testes focados finais permanecem sem resultado por contenção de processos
  Flutter/Dart no workspace compartilhado.
- Testes existentes podem ainda depender de `SegmentedButton` ou do divisor
  proprietário `superadmin-chat-dialog-header-divider`; devem ser alinhados ao
  componente canônico antes de atualizar goldens.
- O wrapper RTK demorou ou falhou em comandos simples e `dart format` dentro do
  sandbox não conseguiu criar `AppData\Roaming\.dart-tool`; a execução
  escalada do Dart foi usada para a checagem final.
- O utilitário `apply_patch` do ambiente retornou acesso negado/ficou pendente;
  patches foram aplicados com `git apply`, sem escrita destrutiva.
- Não encerrar processos Dart genéricos: o workspace compartilhado contém testes
  concorrentes de outras superfícies.

## Débitos técnicos conscientes

- A inbox ainda usa `ListView(children:)` para as seis fixtures locais; migração
  para slivers/builders deve ocorrer somente quando houver volume real ou teste
  de construção lazy aprovado.
- A persistência de posição tem fallback silencioso quando a plataforma local
  não existe, necessário para widget tests; falta cobertura explícita.
- Goldens do launcher, inbox, paleta e popups estão desatualizados.
- Não foi feita revisão visual em localhost nesta etapa de encerramento.

## Estado do git status

O `git status --short` em 2026-08-04 21:02:01 -03:00 mostrou um worktree
amplamente sujo, com alterações e exclusões concorrentes em apps, packages,
docs, skills e testes. Os 13 caminhos do lote de Conversas acima estão
modificados. Não houve stage, commit, push, merge, reset ou troca de branch.

## Resumo do git diff do lote

`13 files changed, 629 insertions(+), 295 deletions(-)` antes da criação deste
checkpoint. Esse número inclui alterações preexistentes acumuladas nos mesmos
arquivos.

## Próximo passo exato

Abrir primeiro
`apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`
e alinhar somente as expectativas antigas de facetas/dialog frame aos
componentes canônicos atuais. Em seguida, executar os testes focados abaixo com
`--no-pub`, um arquivo por vez, evitando concorrência. Não alterar produção antes
de observar uma falha reproduzível.

## Comandos de retomada

Executar a partir de `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart --suppress-analytics test --no-pub test/features/chat/presentation/chat_controller_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart --suppress-analytics test --no-pub test/features/chat/presentation/superadmin_chat_launcher_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart --suppress-analytics test --no-pub test/app/shell/superadmin_shell_chat_inset_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart --suppress-analytics test --no-pub test/features/chat/presentation/superadmin_chat_page_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib/app/shell/superadmin_shell.dart lib/features/chat/presentation
```

## Critérios para concluir a próxima etapa

- controller, launcher, shell inset, página, hierarquia e ações de diálogo verdes;
- exatamente um launcher;
- geometria estável e clamp inferior comprovados;
- seis bandeiras e interações de mouse/teclado/toque comprovadas;
- nenhum hover cinza nos controles alcançáveis;
- análise focada sem issues;
- goldens atualizados somente após os widgets tests ficarem verdes;
- gate `coelo-knowledge` executado e resultado registrado;
- nenhuma alteração fora da tela Conversas/Shell necessária para esses critérios.



## Retomada e fechamento em 2026-08-05

Encerramento: 2026-08-05 09:18:56 -03:00.

A implementação UI/UX do Chat foi estabilizada sem localhost e sem alteração
de Supabase, regra de negócio ou outra tela. A retomada concluiu:

- deduplicação do callback de restauração do launcher, eliminando o deslocamento
  duplicado de 8 px após Home;
- ocultação do launcher enquanto o drawer mobile está aberto, sem recriar o
  Scaffold;
- menus de ações e bandeiras migrados para `CoeloAdminFlyout`;
- remoção de `CheckboxListTile` e `InkWell` crus do seletor hierárquico do
  Chat, preservando hover/foco primário, toque e teclado;
- base da thread alterada para `colorScheme.surface`, em aderência à regra
  mobile/tablet atualizada;
- expectativas antigas de responsividade, dialogs, grupos e controles
  alinhadas aos componentes canônicos;
- spec canônica e projeção de conhecimento do Chat atualizadas.

Verificações executadas:

- análise focada de shell, apresentação e testes do Chat: sem issues;
- suíte combinada de controller, launcher, página e inset do shell: 44 testes
  aprovados;
- teste direcionado do drawer mobile após a correção: aprovado;
- gate de conhecimento e testes da skill: aprovados;
- validador visual oficial: nenhuma ocorrência no Chat. O comando global ainda
  retorna cinco `InkWell` preexistentes fora do escopo, em Imports, Avisos e
  Suporte;
- suíte completa do shell: 56 testes aprovados e duas falhas observadas antes
  da correção do drawer. A falha do drawer foi corrigida e revalidada
  isoladamente; a geometria do menu de perfil permanece fora do escopo.

Um teste adicional de bandeiras por mouse/teclado/toque foi tentado, mas o
processo Flutter expirou antes de carregar qualquer caso. O teste temporário foi
removido para preservar o último estado verde. A lógica de ciclo continua
coberta pelo controller; a evidência widget dedicada e os goldens específicos
de bandeiras/hover permanecem como continuidade visual.

Estado: funcional e validado para o lote de Chat coberto pelos 44 testes. Não
houve stage, commit, push, merge, reset ou troca de branch.

Próximo passo pequeno, se houver nova etapa: abrir
`apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`
e criar um teste isolado da paleta de bandeiras sem `pumpAndSettle` sob hover;
depois criar os goldens dedicados do Chat em 375, 768, 1024 e 1440, light/dark,
sem atualizar qualquer baseline não aprovada.


## Auditoria final em 2026-08-06

- Estado: concluído e validado para o escopo UI/UX local da tela Conversas.
- Nenhum localhost, Supabase, backend, push, merge, stage ou troca de branch foi usado.

### Concluído nesta auditoria

- teste hierárquico alinhado aos controles canônicos que substituíram
  CheckboxListTile, sem mudança de regra ou domínio;
- corrupção UTF-8 corrigida nesta spec e no checkpoint;
- matriz golden confirmada em 375, 768, 1024 e 1440, light e dark;
- goldens dedicados confirmados para launcher, contexto recolhido, paleta aberta,
  popups de grupo, envio em massa, filtros e reduced motion;
- nenhum golden foi regenerado porque não houve divergência.

### Resultados finais

- suíte completa de Chat e inset do shell: 79 testes aprovados sem
  --update-goldens;
- análise estática de source, testes e integração direta: sem issues;
- validador visual administrativo global: aprovado;
- gates de conhecimento: base, consulta e cenários aprovados.
### Pendencias fora desta entrega

- bugs funcionais ja auditados em Pessoas/Criancas, Atividades, grupo apenas com
  crianca e deduplicacao de envio em massa permanecem documentados e nao foram
  alterados, pois esta entrega e exclusivamente UI/UX;
- persistencia produtiva de mensagens, Supabase, notificacoes e regras de negocio
  continuam fora do escopo.

### Retomada futura

Nao ha proxima etapa obrigatoria para esta entrega. Qualquer continuacao deve nascer
de uma nova solicitacao pequena e aprovada, mantendo o primeiro arquivo de referencia
em apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart.
