---
title: "Fechamento operacional da Etapa 2 E2E"
source: "dev fe6f6b51; branches E2E publicadas; rastreadores Coelo Front-end, Back-end e Front-end + Back-end"
status: "superseded — histórico, não usar como plano"
generated_at: "2026-09-08"
updated_at: "2026-09-08"
---

# Fechamento operacional da Etapa 2 E2E

> **SUBSTITUÍDO pela [reconciliação de pendências](reconciliacao-pendencias-2026-09-08.md).**
> O texto abaixo é histórico e contém próximos passos incorretos: backend de
> Avaliações/readers já existem; Locais usa script direto, não Pester; o teste
> Forms foi +101/-1 (102 casos); o preflight exige reconciliar o runner.
> Percentuais locais e ETA antigos não são medições atuais. Consulte somente
> as três matrizes vigentes e o inventário para planejar a execução.

Horário de corte desta auditoria: 2026-09-08 09:32 BRT. O recorte autorizado
continua sendo `apps/superadmin` e os packages/backends usados por ele. As rotas
`/dev` usam fixtures; as rotas sem `/dev` usam a composição produtiva e não
podem cair em fake. Toda mídia nova do MVP usa R2 privado conforme a ADR 0032.

## Percentuais reconciliados

| Medição | Concluído | Restante | Interpretação |
|---|---:|---:|---|
| Front-end técnico local (`local-green`) | 104/219 = 47,49% | 115/219 = 52,51% | Há prova local, mas ainda podem faltar gates próprios do cliente. |
| Front-end estrito (`verified`) | 0/219 = 0,00% | 219/219 = 100,00% | Nenhuma ação fechou todos os gates do cliente. |
| Back-end técnico local por família | 3/38 = 7,89% | 35/38 = 92,11% | Prova local não equivale a deploy ou `done`. |
| Back-end estrito (`done`) | 0/219 = 0,00% | 219/219 = 100,00% | Nenhuma ação fechou Supabase e Cloudflare aplicáveis no remoto. |
| Integração MVP (`verified-e2e`) | 0/192 = 0,00% | 192/192 = 100,00% | Exclui 22 ações pós-MVP e cinco gates somente Flutter. |
| Prontas para E2E | 0/192 = 0,00% | 192/192 = 100,00% | Nenhuma ação possui simultaneamente Front-end `verified` e Back-end `done`. |

O avanço técnico local é material, mas não permite converter testes de widget,
goldens, pgTAP local, rota `/dev` ou fail-closed em conclusão ponta a ponta.

## Git, commits e worktrees

- `dev` recebeu o hardening de mídia de Acontece em `50473bd8` e a evidência
  consolidada em `c12005d1`. O gate fresco passou 16/16 e o analyzer terminou
  sem issues.
- O pacote visual novo da Agenda passou 31/31 na worktree, mas falhou em quatro
  goldens após integração no `dev`; foi revertido por `fe6f6b51` e permanece
  preservado na branch remota `codex/e2e-agenda-operacoes` em `ca4c82ab`.
- Formulários foi preservado em `f84d1dd7`: 100 testes passaram e um falhou no
  cenário de duplicação dependente. Não foi integrado.
- O preflight de autoria Forms foi preservado em `97769124`: 48/71 passaram e
  23 falharam. Não foi integrado.
- O cutover candidato de Locais foi preservado em `9e689374`; o runner não
  descobriu casos no teste focal (0 executados), portanto não foi promovido.
- Todas as sete branches de trabalho e a branch de preservação
  `codex/pre-consolidation-wip-20260908` foram publicadas no `origin`, com HEAD
  local idêntico ao remoto.
- As duas worktrees criadas dentro de `.worktrees/` foram removidas após a
  publicação. As cinco worktrees sob `.codex/worktrees/` pertencem ao Codex;
  estão limpas e serão encerradas pelo arquivamento das respectivas tarefas,
  sem remoção manual do diretório gerenciado pelo aplicativo.

## Estado por tela, subtela e backend

| # | Tela e subtelas | Feito na Etapa 2 | Primeiro trabalho restante ponta a ponta |
|---:|---|---|---|
| 1 | Auth — login, recuperar, redefinir, sair, MFA | Corridas de sessão, recovery confinado, guards e limpeza local protegidos. | Provar SMTP/link/token/revogação no Auth real, MFA conforme decisão, voltar/deep link e reload. |
| 2 | Shell — home, menu, contexto, negado, reload | Navegação e fail-closed receberam hardening local. | Fechar troca de contexto, foco/deep links e ausência de dados antes da autorização real. |
| 3 | Instituições — lista, filtros, detalhe, CRUD, status, arquivos | Lista/formulários e lifecycle local amplamente cobertos. | Fechar detalhe/erros/reload, sete baselines e CRUD/RLS/auditoria no backend nominal. |
| 4 | Unidades — lista, filtros, CRUD, status, arquivos | UI e adapters candidatos locais. | Criar RPCs para ator interno; provar tenant A/B, reload e arquivos. Import/export permanece adiado. |
| 5 | Turmas — lista, CRUD, membros, arquivos | Painéis de detalhe e lifecycle local protegidos. | Substituir RPCs people-based por gateways internos e provar membros/negativas/reload. |
| 6 | Locais — catálogo, criar/editar, vínculos, mapa/foto | DTO/reader/painéis candidatos e diagnóstico de drift remoto preservados. | Corrigir o teste não descoberto, replay LOC, contrato de mapa/privacidade e mídia R2 real. |
| 7 | Pessoas — lista, criar, editar, vínculos, reload | Formulários e descarte de callbacks locais protegidos; detalhe read-only candidato. | Fechar identidade/vínculos, goldens, autorização interna, tenant A/B e persistência real. |
| 8 | Perfis de acesso — lista, detalhe, criar, editar, atribuir, excluir | Negativas, rascunho, conflito e cache por época de autorização endurecidos. | Resolver Access Extended/capabilities, paginação real, RLS e E2E de comandos. |
| 9 | Modelos de acesso — lista, filtro, CRUD, duplicar | Consumers e cache de save/duplicate protegidos localmente. | Resolver realm/anti-escalation, wrappers v2, auditoria, replay e UI produtiva completa. |
| 10 | Usuários internos — lista, criar, editar, suspender, MFA | Directory/detail e minimização receberam provas locais. | Decidir domínio dos comandos, executar Auth real, suspensão/MFA e cross-tenant. |
| 11 | Convites — lista, detalhe, criar, reenviar, revogar | `/dev` filtra escopo e bloqueia combinações cross-institution. | Contrato interno de issuer, RPC/email, expiração/revogação, auditoria e E2E. |
| 12 | Atividades — lista, wizard, detalhe, editar, publicar, avaliação | Contrato v2 teve forte prova local de banco; cliente recebeu guards. | Integrar adapter v2, fechar catálogo/avaliação, remoto nominal e UI→PostgREST→reload. |
| 13 | Avaliações — lançamento, diário, detalhe, fechar/reabrir | Controllers locais e estados fail-closed existem. | Implementar os RPCs ausentes, revalidar páginas/goldens e provar concorrência/auditoria. |
| 14 | Alunos — lista, gerenciar, transferir, editar, revogar | Lista read-only local. | Aprovar comandos e justificar ausência; implementar RLS, vínculos e negativas. |
| 15 | Assiduidade — dashboard, chamada, marcar, corrigir, concluir, exportar | 55 testes funcionais e dois goldens locais registrados. | Backend nominal, tenant A/B, idempotência, reload; exportação geral permanece adiada. |
| 16 | Rotina diária — lista, criar, editar, aplicar, publicar | 48 testes locais, quatro skips justificados e nove goldens. | Ligar gateway produtivo, provar autorização, conflito, publicação e reload. |
| 17 | Agenda — calendário, lista/detalhe, CRUD, solicitações/permissões | Cliente local amplo; reader parcial e novo view preservados em branch. | Corrigir quatro goldens no `dev`, implementar três readers/backend e provar notificações/reload. |
| 18 | Chat — lista, conversa, enviar, editar, anexos, recibos, revogar | Ordem, launcher, retry e descarte de mídia/contexto endurecidos localmente. | RPCs ausentes, R2 de anexos, paginação, receipts/revogação, Realtime e E2E. |
| 19 | Avisos — lista, criar, editar, agendar, publicar, arquivar | Diretório, formulários e envelopes locais endurecidos. | Materializar audiência antes de ativar, resolver `notice_events`, job, RLS e reload. |
| 20 | Circulares — diretório, CRUD, publicar, arquivos | Navegação, preview e isolamento local preservados. | Adapter produtivo, ator interno, persistência/publicação, R2 e negativos. |
| 21 | Formulários/autoria — lista, criar, overview, editar, publicar, testar | Editor, autosave, branching e recibos tiveram grande cobertura local. | Corrigir o teste de duplicação, executar F-AUTHOR01/02, ligar DI e provar publicação/reload. |
| 22 | Respostas — monitor, responder, listar, detalhe, exportar XLSX | Paginação por seção, autosave/review e ramos explícitos cobertos localmente. | Fonte autorizada, worker XLSX, artefato R2 privado, expiração/auditoria e E2E. |
| 23 | Arquivos de Forms — upload, resolver, baixar, expirar, excluir | Estados locais e validações de ticket existem. | Media Gateway, R2 real, MIME/checksum, revogação, órfãos e imagem de resposta. |
| 24 | Acontece — feed, criar/publicar, remover | Feed/overlays e lifecycle de ticket/cache passaram 16/16 no `dev`. | CRUD/publicação, audiência, R2 master, Stream somente por métrica e E2E. |
| 25 | Agora — viewer, criar/publicar, expirar | Viewer, overlays e invalidação de contexto/mídia local protegidos. | R2 master, Stream HOT até 24 h, encoding/fallback, expiração e reload real. |
| 26 | Momentos — viewer, criar/publicar, remover | Viewer e descarte de draft/cache local fecharam 79 testes focais. | R2 progressivo, Stream por demanda medida, publicação/remover e E2E. |
| 27 | Coelo (Principal) — Para Você, Perfil, Circulares | Rotas dentro do Superadmin, contexto, retorno e responsividade locais. | Repositories produtivos, autorização, mídia R2 e edição conforme decisão; não criar `apps/principal`. |
| 28 | Segurança infantil — lista, criança, autorizações, suspender | CRUD local e isolamento de contexto cobertos parcialmente. | Suspensão/revogação sensível, vínculo familiar, auditoria e cross-tenant. |
| 29 | Perfis de cuidado — lista, criar, editar | UI local e descarte de callbacks protegidos. | Decisões clínicas, backend/RLS, mídia R2, retenção e E2E. |
| 30 | Medicação — lista, criar, detalhe, editar, evidência | Roundtrip `/dev` e respostas tardias protegidos. | Fechar OQs clínicas, gateways, RLS, trilha/evidência e E2E; produção segue indisponível. |
| 31 | Importações — hub, upload, preview, confirmar, status, download | Hub/wizard local e indisponibilidade honesta. | Operação real é pós-MVP; manter botões honestos, sem criar job/arquivo. |
| 32 | Arquivos de perfil — importar, preview, confirmar, status, exportar | Inventário e fail-closed. | Operação geral é pós-MVP; preservar UI honesta e não habilitar backend. |
| 33 | Auditoria — lista, filtros, detalhe, exportar | Guards de cursor/contexto e rota local. | Sanitização, paginação, detalhe, RLS e estados; exportação geral permanece adiada. |
| 34 | Suporte — criar, tabela, kanban, detalhe, responder, encerrar | Lista/kanban e acessibilidade local parcialmente fechadas. | Backend, estados negativos, reply/close, auditoria e goldens restantes. |
| 35 | Conta — perfil, configurações, tema, MFA, sessões, logout | Preferências, tema e corrida de sessão local endurecidos. | Perfil/mídia R2, sessões/MFA reais, oito goldens e revogação E2E. |
| 36 | Catálogo — lista, validar, sincronizar, publicar | Validação local e sincronização mecânica. | Resolver fingerprints Forms e proibir publicação antes do contrato aprovado. |
| 37 | Planos e Cardápios — CRUD, atribuir/publicar, modelos | Wizards e versionamento/roundtrip de Cardápios reforçados localmente. | Decisões comerciais, backend de Planos, publicação de Cardápios, mídia e E2E. |
| 38 | Páginas de erro — 403/404/409/500/503/retry | Componentes e mensagens honestas existem. | Reexecutar rotas, teclado, reload/retry e matriz visual conjunta. |

## Bloqueios transversais

1. O projeto remoto é produção; nenhuma migration ou configuração pode ser
   aplicada sem lease do pacote nominal, hashes, ordem e recuperação.
2. A composição produtiva ainda não fecha nenhum par Front-end `verified` +
   Back-end `done`; por isso `ready-for-e2e` permanece zero.
3. Mídia exige Supabase como catálogo/autorização e Cloudflare R2 como master
   privado. URL curta, revogação, retenção, checksum e cleanup são obrigatórios.
4. Existem decisões abertas sobre comandos internos, saúde/medicação, catálogo
   e algumas ações destrutivas. Trabalho independente deve continuar sem
   inventar essas decisões.

## Evidência mínima para a próxima rodada

Cada ação deverá registrar Passo X/Y, tela/subtela, arquivos, banco/RPC/RLS,
R2/Stream quando aplicável, RED→GREEN, testes com contagem, permitido/negado,
tenant A/B, sessão/vínculo revogado, persistência, reload, auditoria, cleanup,
commit e atualização dos três rastreadores no mesmo turno.

Os sete prompts prontos para a nova rodada estão em
`prompts-retomada-etapa-2-2026-09-08.md`.
