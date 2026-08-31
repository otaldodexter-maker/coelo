---
title: "Plano de conclusão das famílias operacionais fora de V4.19–V5.31"
source: "pedido do Owner em 2026-08-31; docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md; specs/019-superadmin-people-directory.md; specs/020-superadmin-attendance-prototype.md; specs/021-superadmin-daily-routine-prototype.md; specs/038-attendance-responsive-dashboard.md"
status: "in-progress"
generated_at: "2026-08-31"
---

# Plano de conclusão das famílias operacionais

## Resultado e limites

Concluir e verificar as correções Flutter locais seguras das 24 ações ativas,
preservando fail-closed, estados de decisão e limites de backend. O trabalho
ocorre exclusivamente no worktree `operations-completion`; não faz merge no
checkout principal e não altera as seções V4.19–V5.31 do rastreador.

Agenda/Eventos permanece somente em auditoria documental enquanto
`specs/006-comunicacao-agenda.md` estiver `draft`. Importação e exportações de
Unidades, integração Supabase, Storage, RLS, remoto e E2E não são promovidos
sem evidência própria. Formulários que compartilhem arquivos modificados no
checkout principal são registrados para reconciliação, não sobrescritos.

## Manifesto do recorte ativo — 24 ações

- Pessoas: `people.list`, `people.create`, `people.edit`, `people.links`,
  `people.reload`.
- Unidades: `units.list`, `units.filter`, `units.create`, `units.edit`,
  `units.status`, `units.error`, `units.access-denied`, `units.reload`.
- Assiduidade e chamada: `attendance.dashboard`, `attendance.create`,
  `attendance.mark`, `attendance.correct`, `attendance.finish`,
  `attendance.export`.
- Rotina Diária: `daily-routine.list`, `daily-routine.create`,
  `daily-routine.edit`, `daily-routine.apply`, `daily-routine.publish`.

As 20 ações originalmente inventariadas de Formulários, Respostas, Arquivos de
Formulários, Agenda e Eventos foram retiradas do ownership de implementação
pelo Owner. Seus inventários permanecem somente como handoff read-only, sem
delta, testes adicionais, golden atualizado, commit ou promoção de estado.

## Ownership paralelo

| Frente | Ownership exclusivo de implementação | Ownership central |
| --- | --- | --- |
| Pessoas | `apps/superadmin/lib/features/people/**`; testes e goldens de Pessoas | router compartilhado, docs, rastreador e commits ficam com o agente raiz |
| Unidades | `apps/superadmin/lib/features/units/**`; testes e goldens de Unidades | gateways produtivos e backend permanecem fail-closed |
| Assiduidade/Chamada | `apps/superadmin/lib/features/attendance/**`; testes e goldens de Assiduidade | contratos compartilhados só mudam após prova de necessidade |
| Rotina Diária | `apps/superadmin/lib/features/daily_routine/**`; testes e goldens de Rotina | router compartilhado e docs ficam centralizados |
| Formulários | somente arquivos confirmados sem colisão após inventário | qualquer arquivo V4.19/V4.20 colidente é excluído da edição |

Agentes paralelos não editam `docs/reviews/coelo-flutter-pendencias.md`, fontes
de conhecimento, router compartilhado ou o mesmo arquivo. O agente raiz
revisa os diffs, sincroniza evidências e cria commits pequenos por família.

## Sequência TDD por família

1. Confirmar action IDs, contrato aprovado, implementação, componente, teste e
   golden real; consultar o índice Coelo UI e as baselines de Instituições.
2. Executar a suíte focada existente sem atualizar goldens e registrar o
   baseline. Falha inesperada segue diagnóstico de causa raiz antes de edição.
3. Para cada gap seguro, adicionar primeiro um teste RED proporcional que
   falhe pelo comportamento ausente, não por erro de compilação artificial.
4. Implementar a menor correção correta com componentes Coelo existentes,
   preservando `colorScheme.surface`, tokens, Nunito Sans, foco, semântica,
   toque, reduced motion e texto a 200%.
5. Rodar o teste RED até GREEN, a suíte focada e análise estática do recorte.
6. Gerar somente os goldens abrangidos pela correção, abrir cada PNG e comparar
   com a baseline aprovada; nunca aceitar atualização para ocultar regressão.
7. Atualizar apenas as linhas dos action IDs desta frente no rastreador, usando
   o marcador `OPERATIONS-WAVE` em registros novos e preservando os estados de
   backend/integração.
8. Revisar o diff da família e criar commit escopado antes de liberar arquivos
   para outra frente.

## Matriz mínima de verificação

- larguras 375, 768, 1024 e 1440 px;
- light e dark; texto a 100% e 200%; reduced motion;
- teclado, mouse e toque; hover, foco e seleção;
- loading, vazio, sem resultados, erro/retry e unauthorized;
- ausência de overflow e alvos mínimos de 48 px;
- componentes e tokens semânticos Coelo, sem Material cru ou HEX local.

## Gates finais

Executar testes focados de todas as famílias alteradas, suítes dos pacotes
afetados, `flutter analyze`, formatter em modo de verificação, `git diff
--check`, `apps/catalog/tool/validate_admin_visual_contracts.dart`, gates de
conhecimento e revisão independente. Corrigir P0/P1 e repetir todos os gates
afetados. O relatório final lista ações concluídas e bloqueadas, evidências,
goldens inspecionados, limites, commits e instruções de rebase/cherry-pick e
reconciliação manual do rastreador.

## Critério de parada

A frente termina quando todas as correções Flutter seguras encontradas no
recorte estão verificadas e commitadas, e todo item não executável possui
bloqueio documental concreto. `local-green`, rota `/dev`, fixture, mock,
fail-closed ou teste isolado não são apresentados como conclusão integrada.
