---
source: R08-fechamento; inventario-etapa-2.json; R09-prompts.md; orientação do Owner de 2026-09-12 sobre CRUD real e consumo
status: preparado-nao-iniciado
generated_at: 2026-09-12
---

# R09 — plano preparado

Nenhuma execução R09 começa pela preparação deste documento. O Owner envia o
prompt de abertura em R09-prompts.md: até quatro horas de execução e trinta
minutos de fechamento, antecipado pelo consumo. Não prolongar R08 nem criar
tarefas duplicadas. C0 e G0–G8 usam GPT-6 Astra, esforço médio.

## Resultado e orçamento

Objetivo: app utilizável, CRUD real, persistência/reload, RLS e hierarquia na
rota normal. Todas as frentes entram na fila; até três executoras simultâneas
além de C0, em revezamento. Uma fatia por frente, fechar antes de abrir outra.
G0 e G5 removem dependências; G8 valida o que libera aceites. Não gastar a
rodada em nova auditoria, reexecuções verdes ou documentação sem entrega.

Cota consultada na preparação: 49% consumidos, 51% restantes. C0 remede a
cada dez minutos. Aos 70% reduzir para uma executora; aos 75% iniciar fechamento;
meta de entrega até 85%, reservando 15% da conta. Antecipar pela taxa observada,
pois o consumo é compartilhado e não há previsão garantida por hora/modelo.
Janela termina pelo primeiro corte: tempo ou consumo. Não resgatar/resetar
cota nem mudar de modelo por conta própria.

Meta de planejamento +6–10 p.p. de conclusão, sujeita aos gates inspecionados:
na base atual +14–24 FE, +14–23 BE, +12–20 E2E. Não é promessa de resultado;
não reclassificar IDs, mudar denominadores ou repetir evidências para alcançar
meta. SQL e aprovação visual só crescem por entrega pertinente. Aos 45 minutos
sem gate fechado, C0 intervém; aos 60 sem novo aceite de camada, muda alocação
e registra a causa. Controle detalhado e prompts: R09-prompts.md.

## Base e ordem

1. C0 faz fetch e lê origin/dev; reconcilia R08-fechamento, worktrees, WIP,
   ignorados, remoto e estado das nove tarefas. Nunca editar/pull no checkout principal.
2. Preservar escritor central e publicar posse/T0/corte antes de liberar G0-G8.
   Reutilizar tarefas existentes quando aplicável; G0 ambiente-runtime.json,
   G8 fase0.json/grupo suites. Heartbeat dez minutos somente na nova janela autorizada.
3. G0 mede runtime, RAM, Docker e ferramentas. Liberar local independente
   imediatamente; E2E após runtime medido, SQL após espelho/pgTAP.
4. Testes focais da base integrada precedem o censo. Um processo Flutter,
   concorrência interna definida pela memória real. Censo completo em base fixa
   somente se couber no consumo sem atrasar CRUD e fechamento. C0/G8 preservam
   IDs, done, exit, falhas, skips e não executados. Não somar reruns ou usar
   censoR07 como aprovação atual. Alterações exigem apenas provas afetadas.
5. Primeiras fatias: vínculos/Locais de Turmas, Pessoas criar/editar, Chamada,
   Cardápios/Chat, anexo Circular e Operações executáveis. Depois Avaliações nos
   recursos existentes, Formulários e publicadores. H28 entra como prova focal
   de Pessoas. SQL59 aplicado e flagtrue não são pendências.
   Cadeias API passadas não são repetidas sem alteração material.
6. Frentes executam próximo gate autorizado; se bloqueado, registram e avançam
   no independente. Checkpoint inclui nove frentes; ACK20min, integração30min.
7. C0 aplica deltas/validadores e publica merges reais. Próximo lote SQL60,
   sempre backup/preflight/pgTAP/regressões/ledger/composição. Deploy exclusivo C0.
8. Revisão/fechamento no primeiro corte de tempo/consumo, com sete métricas,
   recursos retidos, WIP/ignorados, remoto e pausa do novo heartbeat. Preservar
   worktrees e branches; não repetir remoção/restauração da R08.

## Pendências e decisões

R09-backlog lista68ações E2E abertas e gates transversais. R08-perguntas-owner
separa seis R/H19/H02/H05/H06/H13 de decisões já recebidas. P52/P53 não reabrem.
Não alterar senha nem ampliar revisão de credenciais/segurança; controles
obrigatórios permanecem. Sintéticos ficam até fim formal da Etapa2.

## Recursos válidos para reaproveitar

BuildQA G0e2769f7b contém dev477e6c8df/H28true; server3014/mesmaaba na última
medição. Isso não garante que processos sobrevivam ao fechamento; G0 remede.
Form-media21, moments-media10, chat-media4, internal-user-create4 implantadas.
Lotes56–59 aplicados. Manifesto C0 identifica dez grupos de dados/ativos;
Avaliações833a89d8/c4e38ada/d2c945d8 e imagens de Formulários não devem ser recriadas.
