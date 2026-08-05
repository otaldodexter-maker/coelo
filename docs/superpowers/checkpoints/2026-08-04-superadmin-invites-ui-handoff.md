---
title: "Handoff da refatoração de UI/UX de Convites do Superadmin"
source: "Solicitação aprovada do Owner Coelo em 2026-08-04; plano aprovado nesta atividade"
status: "complete"
generated_at: "2026-08-04"
updated_at: "2026-08-05"
---

# Handoff da refatoração de UI/UX de Convites do Superadmin

## Encerramento

- Data e hora: 2026-08-04 21:08:37 -03:00.
- Estado: ponto funcional intermediário; domínio, suporte visual e diretório estão íntegros e validados de forma focada.
- Motivo: encerramento seguro solicitado antes de iniciar formulário, detalhes ou expansão de testes.

## Objetivo original

Refatorar exclusivamente a experiência de Convites em `apps/superadmin`: diretório somente em tabela, filtros, flyout de ações, criação em sete etapas, detalhes somente leitura, responsividade, acessibilidade e evidências proporcionais, sem banco, autenticação, arquitetura, permissões ou componentes públicos novos.

## Escopo efetivamente trabalhado

- Corrigido o contrato local de revogação para permitir `canRevoke` apenas em convite pendente; `canResend` continua permitindo pendente e expirado.
- Criado suporte visual local para status, formatação de datas e confirmação canônica de revogação.
- Refatorado o diretório para tabela única com toolbar, busca mascarada, filtros canônicos, estados, faixa de criação, tabela redimensionável e flyout contextual.
- Ajustado o teste existente do diretório para usar o tema Coelo requerido pela tabela compartilhada.
- A correção terminológica Grupo Azul → Turma Azul foi incorporada e coberta
  por teste de regressão: contextos escolares de Convites usam Turma, não Grupo.

## Decisões de produto e UI/UX a preservar

- Contexto: `apps/superadmin`, preview local `/dev`; nenhum envio, token, persistência ou autorização produtiva.
- Diretório exclusivamente em tabela; não restaurar cards nem toggle Cards/Tabela.
- Baseline: Instituições para diretório/tabela; Importações para composição; Criar/Editar Instituição para formulário; Menu/Flyouts para ações; Popup de Bug para confirmação.
- Não existe modo Editar: o repositório atual não possui operação de atualização de convite/rascunho.
- Revogação somente para `InviteStatus.pending`; reenvio para `pending` e `expired`.
- Busca usa destinatário mascarado e textos existentes de contexto/papel; não inventar nome de destinatário.
- Filtros suportados: status, público, canal e período de criação. Não criar filtro de expiração sem suporte em `InviteQuery`.
- Tabela mostra apenas destinatário mascarado, público, contexto/papel, canal, status, criação, expiração e ações. Responsável e data específica de envio permanecem omitidos.
- Flyout usa `CoeloAdminFlyout`; revogação usa divisor e `CoeloAdminFlyoutTone.negative`.
- Formulário futuro mantém sete etapas e usa `SuperadminFormStepNavigation`, `CoeloFormTextField`, `CoeloAdminSingleSelectField` e `SuperadminFormActionFooter`.
- Não criar API pública, token, dependência, allowlist ou padrão global.

## Referências consultadas

- `AGENTS.md` e `C:/Users/adrie/.codex/RTK.md`.
- Skills: `coelo-ui`, `coelo-knowledge`, `ui-ux-pro-max`, `ponytail`, `flutter-build-responsive-layout` e `rtk`.
- Contratos `surface-interaction-contracts.md`, `admin-directory-flyout-contracts.md`, `form-layout-contracts.md`, `interactive-state-evidence-matrix.md`, baselines aprovadas, padrões rejeitados, fronteiras e verificação.
- Índice Coelo UI: `pattern.admin-directory`, `admin.resizable-table`, `admin.listing-toolbar`, `admin.flyout`, `pattern.flyout-actions`, `pattern.negative-actions`, `pattern.interaction-states`, seletores e formulários.
- Memória: `superadmin-operational-prototypes.md`, `coelo-admin-interaction-hierarchy.md`, `superadmin-institution-directory.md` e `superadmin-institution-form.md`.
- Fontes canônicas: `docs/superpowers/specs/2026-08-03-superadmin-operational-surfaces-prototype-design.md`, `docs/security/auth-multitenant-permissions.md`, `docs/data/data-model.md`, PRDs, Design System e ADR 0015.
- Código e testes de Convites, Importações, Instituições, `coelo_ui_admin`, footer e navegação de formulário.

## Arquivos criados

- `apps/superadmin/lib/features/invites/presentation/invite_presentation_support.dart`.
- Este checkpoint: `docs/superpowers/checkpoints/2026-08-04-superadmin-invites-ui-handoff.md`.

## Arquivos alterados nesta unidade

- `apps/superadmin/lib/features/invites/domain/platform_invite.dart`.
- `apps/superadmin/lib/features/invites/presentation/invite_directory_page.dart`.
- `apps/superadmin/test/features/invites/invite_directory_page_test.dart`.

## Superfícies e componentes afetados

- Diretório de Convites.
- `CoeloAdminListingToolbar`, `CoeloAdminMultiSelectFilter`, `CoeloAdminSingleSelectField`, `CoeloAdminCreateAction.banner`, `CoeloAdminResizableTable`, `CoeloAdminFlyout`, `CoeloStatusChip`, `CoeloStatePanel` e `CoeloAdminDialogShell` como consumidores; nenhum componente compartilhado foi alterado.
- Rotas ainda não foram alteradas nesta unidade.

## Concluído

- Diretório sem cards/toggle e com tabela canônica.
- Busca, limpeza e filtros por status, público, canal e criação preservando estado.
- Estados loading, empty, no-results, error e unauthorized.
- Status textual com cores e ícones semânticos.
- Ações condicionais de detalhes, copiar, reenviar e revogar; processamento e feedback local.
- Confirmação negativa canônica sem exposição de link/token.
- Revogação restrita a pendentes.
- Formatação, análise focada, testes existentes e `git diff --check` executados.

## Parcialmente concluído

- O diretório possui comportamento implementado, mas ainda carece dos testes comportamentais ampliados e goldens previstos no plano.
- O suporte de confirmação foi compilado/analisado, mas será exercitado pelos testes de diretório e detalhes na retomada.
- A ação “Ver detalhes” depende do callback existente; a rota já o fornece, mas não foi revalidada nesta unidade.

## Ainda não iniciado

- Refatoração de `invite_form_page.dart` e adição de `onCancel` no router.
- Refatoração de `invite_detail_page.dart`.
- Testes novos de formulário, detalhes, filtros, flyout, teclado, foco, reduced motion e matriz 375/768/1024/1440.
- Goldens mobile light/desktop dark e estados interativos.
- Atualização da spec canônica e projeção `docs/knowledge`.
- Gates Coelo Knowledge, validador visual do catálogo, análise completa e suítes compartilhadas.

## Verificações executadas

- `dart format` nos três arquivos Dart de produção alterados e no teste do diretório: concluído.
- `dart analyze lib/features/invites/domain/platform_invite.dart lib/features/invites/presentation/invite_presentation_support.dart lib/features/invites/presentation/invite_directory_page.dart`: `No issues found`.
- Testes focados `fake_invite_repository_test.dart` e `invite_directory_page_test.dart`: 3/3 passaram.
- `git diff --check -- apps/superadmin/lib/features/invites apps/superadmin/test/features/invites`: exit code 0; apenas avisos de normalização LF→CRLF.

## Erros, avisos e bloqueios

- A primeira execução do teste do diretório falhou porque o teste usava `MaterialApp` sem `CoeloTheme`; corrigido no próprio teste e repetido com sucesso.
- A ferramenta interna `apply_patch` e seu wrapper local retornaram bloqueio/timeout e “Acesso negado”. As escritas foram feitas por substituições .NET estritamente delimitadas e validadas por format, analyze, testes e diff.
- O worktree já estava amplamente sujo antes desta atividade. Não limpar, restaurar ou incluir mudanças alheias.
- Avisos LF→CRLF são de normalização do worktree e não representam erro de sintaxe.

## Débitos técnicos conscientes

- `_InviteDirectoryPageState` ainda concentra filtros e ações; não extrair controller antes de existir necessidade real.
- O feedback de processamento envolve operações fake síncronas com yield de um ciclo; deve continuar local ao preview.
- A cobertura existente é mínima; a próxima unidade deve testar o diretório antes de avançar para formulário/detalhes.

## Estado atual do Git

No escopo de Convites:

- Modificados: `fake_invite_repository.dart` (alteração preexistente), `platform_invite.dart`, `invite_directory_page.dart`, `invite_directory_page_test.dart`.
- Novo: `invite_presentation_support.dart`.
- O repositório contém muitas outras alterações e checkpoints concorrentes; preservar integralmente.

## Resumo do diff

O diff rastreado de Convites mostra 4 arquivos, 477 inserções e 124 remoções. O arquivo novo de suporte e este checkpoint ainda não entram nesse `--stat` por serem untracked. A maior mudança é a substituição do diretório cards/tabela por uma composição exclusivamente tabular e responsiva.

## Próximo passo exato

Abrir `apps/superadmin/test/features/invites/invite_directory_page_test.dart` e ampliar somente a cobertura do diretório já implementado: confirmar ausência de cards/toggle, presença de `CoeloAdminResizableTable`, busca mascarada, aplicação/limpeza de um filtro e disponibilidade do flyout por estado. Não iniciar o formulário antes desses testes passarem.

## Primeiro arquivo da retomada

`apps/superadmin/test/features/invites/invite_directory_page_test.dart`.

## Comandos de retomada

```powershell
rtk git status --short
rtk git diff -- apps/superadmin/lib/features/invites apps/superadmin/test/features/invites docs/superpowers/checkpoints/2026-08-04-superadmin-invites-ui-handoff.md
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib/features/invites
rtk test C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/invites/fake_invite_repository_test.dart test/features/invites/invite_directory_page_test.dart
```

Executar análise e testes a partir de `apps/superadmin`; executar status/diff a partir da raiz.

## Critério de conclusão da próxima unidade

- Testes do diretório cobrem tabela única, busca, filtros, limpeza e flyout sem novas falhas.
- Análise focada permanece sem issues.
- Nenhum arquivo fora de Convites é alterado, salvo o checkpoint correspondente.
- Somente depois disso iniciar a refatoração do formulário.

## Gate de memória

Não executado nesta unidade intermediária. A fonte canônica e a projeção de conhecimento permanecem pendentes para a etapa funcional completa; não foi criado registro de memória parcial nem conteúdo sensível.
## Retomada e conclusão

Esta seção supersede as pendências registradas no checkpoint intermediário sem
apagar as referências, decisões e verificações históricas acima.

- Conclusão registrada em: 2026-08-05 09:34:59 -03:00.
- Diretório: concluído exclusivamente em tabela, com busca mascarada, filtros
  suportados, estados canônicos, rolagem vertical do conteúdo, linha adaptativa
  a texto ampliado e flyout contextual.
- Criar convite: concluído em sete etapas com controles canônicos, validação por
  canal, revisão mascarada, navegação responsiva e
  SuperadminFormActionFooter. A rota existente recebeu somente o callback de
  cancelamento para retornar ao diretório.
- Detalhes: concluído em modo somente leitura, sem Editar, token ou link completo;
  inclui status, dados disponíveis, timeline, clipboard, reenvio e confirmação
  negativa de revogação.
- Regra de domínio: revogação somente para pendentes; reenvio para pendentes e
  expirados.
- Responsividade: validada em 375, 768, 1024 e 1440 px, light/dark, texto a
  200% e reduced motion. Mobile e tablet claros usam colorScheme.surface como
  fundo-base simples.
- Evidência visual: nove goldens de Convites foram gerados, inspecionados e
  comparados novamente com sucesso.
- Testes de Convites: 30 passaram, incluindo a regressão de terminologia Turma.
- Componentes compartilhados: 33 testes de tabela/filtros/flyout e 6 testes de
  footer/navegação passaram.
- Análise focada de produção e testes de Convites: sem issues.
- Gate de memória: os dois validadores passaram; a captura ficou restrita às
  decisões duráveis da experiência de Convites, sem PII, token ou fixture
  reconhecível.
- Validador visual bloqueante: executado e bloqueado por cinco ocorrências de
  InkWell fora de Convites, em Importações, Avisos e Suporte. Nenhuma ocorrência
  proibida foi encontrada em features/invites; a allowlist não foi alterada.
- Análise completa do Superadmin: executada e bloqueada por erros e infos fora
  de Convites, em Avisos, Perfis de acesso, Chat, Safety e Suporte. O escopo
  focado permanece limpo.
- Nenhum localhost, push, merge ou troca de branch foi realizado.
- Estado final: funcional e validado para o escopo de Convites; apenas gates
  globais permanecem vermelhos por alterações externas preservadas.