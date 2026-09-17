---
title: "R16 — fila única consolidada da Etapa 2"
source: "Owner em 2026-09-17 (fechar a R15 e abrir a R16 com tudo o que ficou pendente de R01 a R15; decisions/0043-r15-closure-r16-opening-20260917.md); R15-pendencias.md (congelado; 53 Owner IDs, H02–H28, itens da ADR 0038); inventario-etapa-2.json; R15-checkpoint-20260917.md; R15-fechamento.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R16 — fila única consolidada

> **Este é o único arquivo vivo de pendências da Etapa 2.** `R15-pendencias.md`
> passa a histórico congelado (como R12/R13/R14). A tabela de Owner items abaixo é a
> fonte lida por `sync-r12-owner-records.cjs` (53 linhas, IDs preservados);
> `docs/reviews/inventario-etapa-2.json` continua a fonte dos estados por
> `action_id`. Item `done` fica aqui só para contagem e não volta à execução;
> item `open`/`partial`/bloqueado é a fila. Não criar cópias em outros arquivos.

Contadores certificados pelo inventário e `validate-trackers.cjs` após a Mesa R16
(17/09/2026, ADR 0044; 33 ações fora do MVP passaram a `v1` e saíram dos denominadores):
FE 198/199 (99,5%), BE 185/186 (99,5%), E2E 184/186 (98,9%), Owner 39/53 (73,58%);
no fechamento da R15 os mesmos numeradores eram 207/232, 185/219 e 184/186. Abertura da R15 em
16/09: FE 189/232, BE 172/219, E2E 162/186, Owner 21/53. Fila: 2 ação(ões) não
terminal(is) no MVP, 14 Owner items abertos/parciais, 19 resíduos H, 2 itens da ADR
0038 e os resíduos operacionais listados abaixo. Nenhum item foi
renumerado; nenhum estado mudou na abertura.

## Mesa R16 — decisões do Owner (17/09, ADR 0044)

91 itens decididos no artefato `QsXjfhhDGjrXAF1yCPaoEs`. **Critério de encerramento da
Etapa 2 = E2E do MVP**; FE/BE por code review e revisão tela a tela na Etapa 3. As 33
ações fora do MVP viraram `v1` (fora dos denominadores). Destinos:

- **R16** — E2E: `agora.publish`, `forms.location-answer`; Owner items: owner.r12-04, owner.r12-05, owner.r12-06, owner.r12-08, owner.r12-18, owner.r12-33, owner.r12-49;
  H: H18, H19, H20, H21, H22, H24, H25, H27, H28, H08, H13, H23; contrato/dívida: oq048-membership, testes-vermelhos, recipients-bug, can-remove, momentos-ux, celular-mascara, orfaos-cardapio, form-diario, forms-v2-qa, espelho-cli, h02-aal2;
  `participants-vazio` reprovado com nota (atividade sem participantes é válida; prova de r12-05 com massa sintética).
- **Etapa 3 (tela a tela)** — Owner items: owner.r12-10, owner.r12-19, owner.r12-23, owner.r12-29, owner.r12-30, owner.r12-46, owner.r12-53; H: H02, H03, H04, H07, H09, H10, H12, H14, H16, H26;
  ADR 0038 Local interno; goldens, cors-r2, deploy-publico, activity-msg, smtp-reset, specs-064-069. Goldens: componentizar o
  cabeçalho e substituir referências antigas (nota do Owner).
- **Sem necessidade** — Stream genérico.

## Abertura (Owner, 17/09/2026 — ADR 0043)

O Owner determinou em 17/09/2026 o fechamento da R15 e a abertura da R16 como fila
única, levando **tudo o que ficou pendente de R01 a R15** com os mesmos IDs, e a
unificação do repositório em `dev` (branches e tags remotas apagadas com bundle de
recuperação e manifesto). A R15 rendeu +22 E2E, +18 FE, +13 BE e +18 Owner
items num dia, com lotes 75–80 em produção (PT409 sistêmico, Chat multi-anexo,
leitor "Para você", B5/B6/Cardápios R2, projeção do Agora, fixture QA R15) e
decisões E10–E14 do Owner (adendo da ADR 0042). O que ficou aberto está nas
seções abaixo; a ordem de execução proposta considera o que já tem código e só
falta prova.

## Abertura da R15 (histórico, Owner, 16/09/2026 — ADR 0042)

O Owner encerrou a R14 no fim de 16/09 e determinou que **tudo o que ficou
pendente de R01 a R14** seja levado para a R15, para acelerar o fechamento. A
varredura de abertura confirmou que R01–R07 já estavam reduzidas a H02–H28 (R07),
R08–R11 às ações do inventário e aos Owner items herdados da R11 (R12), e
R12/R13 à R14; **nenhum item fora dessas três famílias ficou órfão**, exceto os
resíduos operacionais sem `action_id` registrados na seção própria abaixo. As
dúvidas de abertura foram respondidas pelo Owner no mesmo dia (artefato
`M13t2csojoBnGt4sGWY4QM`, ADR 0042 E1–E7); ver a seção seguinte.

## Mesa R15 — respostas do Owner (16/09, ADR 0042 E1–E7; histórico)

- **Produção e permissões resolvidas no mesmo dia**: o Owner liberou a escrita
  em produção para a coordenação; as seis migrations foram aplicadas (lote 74,
  ledger 302–309) e o incidente do PostgREST terminou com a primeira delas
  (`PT409` no lugar de 40001). A API respondeu 401/0,5 s na sondagem seguinte.
- **E1 OQ-047 = A**: migration única 40001 → `PT409` em todas as famílias, com
  pgTAP por família no espelho antes (Bloco B, antes das provas de negativa).
- **E2 massa = A**: responsável + 2 crianças sintéticas vinculadas e 2 usuários
  internos (admin de unidade, educador) no tenant QA R04, prefixo `QA R15`.
- **E3 Chat r12-52 = B**: contrato de vários anexos por mensagem (migration +
  Edge `chat-media` + compositor em lote) — Bloco C, antes da prova de
  `chat.attach`.
- **E4 goldens = A**: regravar todas as suítes com diff só de cabeçalho, uma a
  uma, com registro.
- **E5 ordem = A** (Bloco A → B → C), executada com quatro prompts: coordenadora
  + um por bloco.
- **E8**: reset de senha no MVP, provado com a caixa do Owner (`auth.recover` BE
  done em 16/09); SMTP próprio → Etapa 3. **E9**: MFA fora do MVP
  (`deferred-post-mvp`).
- **E6 = a** (publicar no Histórico); **E7 = b** (responsável recebe o sino em
  atualização e dose — ajustar `20260916190000` por migration v2 + pgTAP + FE
  antes da prova de r12-33).
- **17/09 (adendo ADR 0042, E10–E13)**: reset de senha aceito por decisão do Owner
  (prova detalhada do link → Etapa 3; `auth.recover` fecha pela tela + entrega real);
  conta `qa-r15-responsavel@coelo.me` criada (fixture AP-1 pelo rito, lote 80); lote 78 e
  redeploy de `child-safety-media` (v2) autorizados e aplicados; CORS de
  `coelo-documents-prod` só com origens locais de QA no MVP.
- Ambiente resolvido (Owner, 16/09): CORS das Edge Functions para `127.0.0.1:3014–3024` aplicado nas seis `*_ALLOWED_ORIGINS` de produção; preflight 200/204 em 3016/3018/3022/3024, 3030 segue 403.

## Ordem de execução proposta (R16, conforme ADR 0044)

1. **E2E remanescente (2)**: `forms.location-answer` (publicar a v4 do form 4555ba07, ocorrência única, responder como `qa-r06-formularios`) e `agora.publish` (corrigir `now_actor` para reconhecer o responsável por `guardian_links`/`guardian_context_permissions`, OQ-048; provar leitura pela responsável `qa-r15-responsavel`).
2. **Owner items R16 (7)**: owner.r12-04, owner.r12-05, owner.r12-06, owner.r12-08, owner.r12-18, owner.r12-33, owner.r12-49 — Assiduidade (r12-05 negativa + participantes sintéticos; r12-08 ≥2 alunos; r12-04 Histórico; r12-06 snapshot), Medicação r12-33 (E7, com `recipients-bug` corrigido antes), B6 r12-18 (envio final pela tela; upload do documento quando houver CORS), r12-49 close/reopen.
3. **Contrato e dívida técnica R16**: `oq048-membership` (onboarding cria membership `guardian`), `recipients-bug`, `can-remove` (decidir feed × RPC), `momentos-ux`, `celular-mascara`, `orfaos-cardapio`, `form-diario`, `forms-v2-qa`, `espelho-cli`, `h02-aal2`, `testes-vermelhos` (21 testes funcionais).
4. **Resíduos H R16 (12)**: H18, H19, H20, H21, H22, H24, H25, H27, H28, H08, H13, H23 (H08/H13/H23 pela spec 069).
5. **Não entram na R16**: itens de Etapa 3 e V1 listados na Mesa R16 (acima); Stream encerrado.

## Ordem de execução proposta (R16, versão de abertura — substituída pela Mesa R16)

1. **E2E remanescente** (2): agora: `agora.publish`; forms_responses: `forms.location-answer`. Provar na rota real com a massa `QA R15`
   (responsável com conta `qa-r15-responsavel`, crianças 93457405…/14d70a25…, turma 368a5cea) — sem
   contrato novo.
2. **Owner items abertos/parciais** (14): Assiduidade (`r12-05` contexto Atividade —
   `ACTIVITY_INVALID_REFERENCE` a isolar; `r12-08` ≥2 alunos; `r12-04` Histórico; `r12-06`
   snapshot), Medicação `r12-33` (sino do responsável, E7 — provar com `qa-r15-responsavel` por
   PostgREST), Conta `r12-46` (máscara/normalização do Celular), B5/B6/Cardápios R2
   (`r12-17/18/38` — backend em produção desde o lote 78; falta a prova E2E completa), Perfis
   de acesso `r12-20` (rolagem em viewport baixo), Perfis de cuidado §5 (`r12-29/30`, spec
   065), perfil transversal (`r12-19/23`, spec 064), `r12-49` close/reopen na rota real,
   `r12-53`/OQ-034 (spec 067), `r12-10` (revisão da Table canônica).
3. **Specs decididas com implementação pendente**: 064 (OQ-044), 065 (§5), 066 (OQ-033 +
   `institutions.status`), 067 (OQ-034), 068 (OQ-032), 069 (Avisos H08/H13/H23) — implementar
   com pgTAP + FE + rota real; OQ-048 (contexto do Principal para responsável sem membership).
4. **Resíduos H** (19) com gate de medição e os itens da ADR 0038 (Local interno em
   Formulários; allowlist de redirect → concluída em produção para `127.0.0.1:8765`).
5. **Operação**: censo completo de suítes (registrado no fechamento da R15 — corrigir as
   falhas pré-existentes), goldens fora do E4 (notice_directory, forms, invites, meal_plans,
   platform_users), CORS dos buckets R2 (decisão E13: só na Etapa 3 com a origem pública),
   deploy público do frontend, espelho CLI de migrations.

**Fora da R16:** SMTP próprio e prova detalhada do link de reset (Etapa 3, E8/E10); MFA ×3
(`deferred-post-mvp`, E9); Planos comerciais e `catalog.*` (V1/V2); H11 autosave (V1); Stream
genérico (sem contrato); origem pública `superadmin.coelo.me` (Etapa 3).

## Ordem de execução da R15 (histórico)

**Bloco A — rota real que ficou pronta na R14 (sem SQL novo; só exige produção respondendo):**
1. Perfis de acesso `access-profiles.edit/assign` + `owner.r12-20/21/22/24/25/26/27` (build e roteiro em `R14-handoff-sessao-5.md`).
2. Instituições `institutions.error/access-denied` (deep link + `cdp_block`).
3. Conta `owner.r12-46` / `account.profile` (foto R2; CORS da porta resolvido em 16/09).
4. Formulários `forms.expire-file/delete-file`, `forms.create/edit` + `owner.r12-39/40`, `forms.location-answer` (roteiro em `R14-handoff-sessao-6.md`).
5. Chat `chat.attach` + `owner.r12-52` — só depois do contrato E3 (Bloco C, item 12a).
6. Momentos `momentos.view/publish/remove` (`momentos.create` se o ambiente permitir; roteiro em `r14-sessao-7/momentos-bloqueado-20260916.md`).
7. `errors.409` (flutter-only, captura na rota real).
8. `auth.recover` / `auth.reset` + `owner.r12-47` (E8): pedir na tela `/recover` do app QA com o e-mail do Owner, abrir o link em `/reset-password` (após o push da allowlist `127.0.0.1:*`), senha nova, nova sessão, expiração/uso único; sem registrar link.

**Bloco B — migrations já aplicadas (lote 74); rota real + OQ-047 sistêmica:**
8. OQ-047 (E1): migration única 40001 → PT409 com pgTAP por família; depois Segurança da criança `child-safety.edit/suspend` + `owner.r12-13/15/16`.
9. Assiduidade contexto Atividade + `owner.r12-05` (criar atividade "QA R15" pela tela se não houver elegível); massa E2 (responsável + 2 crianças, admin/educador) para `owner.r12-08`, `agora.publish` e `owner.r12-33`.
10. `agora.remove` pela tela + negativa D5 (projeção `management_version`/`can_remove` — candidato no handoff 7 — e fixture executada como `postgres`).
11. B2 Histórico (`owner.r12-04`), B3 snapshot (`owner.r12-06`), B8 sino (`owner.r12-33`, com E7: v2 incluindo o responsável), B1 Arquivar (`owner.r12-01/02`): provar na rota real.

**Bloco C — contrato novo, especificar antes:**
12a. E3: vários anexos por mensagem no Chat (migration + Edge `chat-media` + compositor em lote), depois `chat.attach`/r12-52.
12. B5 busca de pessoa autorizada (`owner.r12-17`) e B6 pessoa sem conta (`owner.r12-18`).
13. B9 "ver como" (`principal.for-you`, `principal.profile-edit`).
14. Specs R15 já decididas: perfil transversal/funcionário (OQ-044; `owner.r12-19/23`), Perfis de cuidado §5 (`owner.r12-29/30`), ciclo de vida OQ-033 (inclui `institutions.status`), Locais com mapa por imagem (OQ-034), perfis oficiais (OQ-032).
15. H08/H13/H23 (Avisos: duplicar, CTA, visual) e demais H com gate de medição.
16. `owner.r12-38` Cardápios imagem R2 (migrar adapter para Media Gateway).

**Fora da R15:** SMTP próprio (Etapa 3, E8); MFA ×3 (`deferred-post-mvp`, E9); Planos comerciais e `catalog.*` (V1/V2); H11 autosave (V1); Stream genérico (sem contrato).

## Owner items — abertos/parciais e atualizações da execução (14)


| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-04 | daily-routine.list, attendance.dashboard | partial / FE local-green (Sessão 10, 16/09): tela Acompanhamento › Assiduidade › Histórico em `/attendance/history` (tabela data/turma-atividade/quem lançou/presentes/ausentes/rotina/situação, filtros instituição/unidade/turma/atividade/situação/período, cursor, abre o detalhe; sem edição); aba Lançamentos retirada do diretório de Rotina (Lançar hoje → Histórico › Lançamentos de rotina); 280 testes verdes, 10 goldens pré-existentes (C1). / BE local-green: `20260916180000_attendance_call_history_v1` (leitor por cursor com escopo do painel, só agregados) + pgTAP 44/44 no espelho; NÃO aplicada em produção. / Pendente: aplicar a migration, rota real autenticada, reload e negativa cross-tenant (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/attendance-history-20260916.md; specs/052-superadmin-attendance-history-and-routine-snapshot.md | Aplicar `20260916180000` pelo rito (espelho verde) após o fim do incidente; provar `/attendance/history` com `qa-r06-operacoes`, reload e negativa; decidir se Publicar lançamento fica no Histórico ou volta a Rotinas (spec 052 §3). |
| owner.r12-05 | attendance.create | partial / FE verified: R15 B 17/09 — contexto **Atividade** exercitado na rota real com atividade real ("QA R15 Atividade Assiduidade" `1bd6bc74…`, criada pela tela após 2 defeitos de FE corrigidos): seleção, chamada criada (`bcd47ba2…`, open, `activity_id` preenchido) e reload. / BE done; `superadmin_attendance_create_call` aceita `p_activity_id`; **achado**: chamada em contexto Atividade nasce com `participants []` (turma com 3 crianças ativas, atividade em modo `all`). / verified-e2e (contexto Turma, R14); contexto Atividade: negativa não executada (prazo). | docs/reviews/evidence/etapa-2/r15-bloco-b/attendance-contexto-atividade-20260917.md; docs/reviews/evidence/etapa-2/r15-bloco-b/atividade-qa-r15-criacao-20260917.md; docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md | ADR 0041 D3: falta a negativa do contexto Atividade e esclarecer `participants []` (derivação por `activity_group_participants` vs modo `all`) — R16 | R16: negativa do contexto Atividade (instituição alheia/atividade inelegível) e esclarecer `participants []` na chamada em contexto Atividade (3 crianças ativas, modo all); depois r12-05 → done. |
| owner.r12-06 | attendance.create, daily-routine.apply | partial / FE local-green (Sessão 10, 16/09): detalhe da chamada e Histórico mostram a rotina (snapshot "registrada na conclusão"; aberta = vigente; legado concluído sem snapshot = "rotina atual (não registrada na época)"); repositório mapeia PT409; FE verified anterior (wizard sem etapa de rotina) preservado. / BE local-green: `20260916183000_attendance_routine_snapshot_v1` (colunas de snapshot, `attendance_effective_routine`, complete_call grava só na primeira conclusão, call_detail expõe routine_snapshot/routine_current/routine_source, histórico projeta a rotina, 40001 → PT409 na família) + pgTAP 43/43 no espelho; NÃO aplicada em produção. / Pendente: aplicar a migration, concluir/reabrir chamada real, reload do detalhe e negativa 409 PT409 (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/attendance-routine-snapshot-20260916.md; docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; specs/052-superadmin-attendance-history-and-routine-snapshot.md | Aplicar `20260916183000` pelo rito após `20260916180000` e o fim do incidente; provar na rota real: concluir grava snapshot, reabrir/concluir preserva, legado mostra a indicação; negativa de versão defasada responde 409 PT409. |
| owner.r12-08 | attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | partial / FE verified em mark/finish na rota real 15/09 (chamada cd60f2d8: presente salvo, reload, concluída). / Contratos preservados; set_participant v2 e complete_call v3 em produção. / Pendente só a massa: as turmas do escopo têm no máximo 1 aluno; múltiplos alunos/turmas e rotina vinculada não exercitados. | docs/reviews/evidence/etapa-2/r14-sessao-1/attendance-create-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-behavior-diagnostic-r12.md | ADR 0041 D6: Owner não autoriza massa fictícia agora; prova com ≥2 alunos fica para depois. Bloqueado por decisão, não por ambiente. |
| owner.r12-10 | child-safety.list | deferred / FE local-green (S9 16/09): causa da deriva observada no shell (`3945394f3` trocou a identidade estática por `headerProfile` da sessão; sem host o golden renderizava o placeholder `–`/`Conta`); cabeçalho estabilizado por `SuperadminHeaderProfileScope` + `SuperadminHeaderProfile.preview()` e golden `child_safety_directory_light_1440` regravado (C1), suíte 30/30 verde. / Contrato preservado; nenhum SQL/RPC novo. / Pendente: rota real da tabela e revisão contra a Table canônica. | docs/reviews/evidence/etapa-2/r14-sessao-9/goldens-cabecalho-global-20260916.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-table-golden-diagnostic-r12.md | Revisar a tabela do diretório contra a Table canônica e capturar na rota real quando o PostgREST voltar; golden não certifica aceite. **Mesa R16 (ADR 0044): Etapa 3, tela a tela.** |
| owner.r12-19 | gate/mapeamento pendente | deferred / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | ADR 0041 B7: perfil transversal/funcionário no Principal vira spec própria na R15 (OQ-044). Na R14, provar somente o diretório atual (r12-20/21) sem tocar no conflito. **Mesa R16 (ADR 0044): Etapa 3, tela a tela.** |
| owner.r12-20 | access-profiles.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Resíduo BE (não bloqueia): "Vínculos" conta platform_memberships. Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (S5 16/09 e Bloco A 17/09): 8 cards após carga completa em 1424×1125 e após salvar edição. / BE inalterado. / E2E: negativa aceita = versão defasada 409 PT409 (lote 75) e capability/instituição inválida 400 22023; perfis Superadmin não têm tenant. |
| owner.r12-21 | access-profiles.detail | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Resíduos BE: rótulo "Excluir" × nome "Inativar modelos Admin."; reason mascarado como [redacted] no detalhe. Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (Bloco A 17/09): detalhe traduzido módulo › tela › ação ("Acessos › Modelos de perfil › Ver"), relido após carga completa com v2 e 2 permissões. / BE inalterado; catálogo em inglês e CardÃ¡pios (resíduo). / E2E verified-e2e via access-profiles.edit. |
| owner.r12-22 | access-profiles.create, access-profiles.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Detalhe da prova (R15 Bloco A, 17/09): FE verified: criação (S5) e edição (Bloco A 17/09) sem campo Código; code do servidor preservado ao renomear. / BE done. / E2E verified-e2e: save v1→v2 relido por PostgREST, reload, 409 PT409 em versão defasada. |
| owner.r12-23 | access-profiles.create | deferred / Planejado R12, não implementado. / Contrato a verificar; conflito Principal em R12-23. / Sem nova prova. | docs/reviews/etapa-2-operacao/next-round/R12-perfis-permissoes-owner.md | ADR 0041 B7: transferido para spec própria na R15 (OQ-044). Não executar na R14. **Mesa R16 (ADR 0044): Etapa 3, tela a tela.** |
| owner.r12-24 | access-profiles.create, access-profiles.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Resíduo visual: tooltip aberto por foco não fecha quando o foco avança (fica empilhado); corrigir em _PermissionActionCell. Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (Bloco A 17/09): tooltip de sensibilidade por hover (S5) e por foco de teclado (Tab) em "Excluir" (sensível) e "Criar/Importar" (risco elevado). / BE inalterado. / E2E verified-e2e via access-profiles.edit. |
| owner.r12-25 | access-profiles.create, access-profiles.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (Bloco A 17/09): matriz em 1424 (empilhada por tela, cabeçalho sem estouro) e em 600×900 (stepper à esquerda, sem estouro horizontal, rodapé empilhado); persistência/reload. / BE inalterado. / E2E verified-e2e via access-profiles.edit. |
| owner.r12-26 | access-profiles.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (Bloco A 17/09): Continuar FilledButton laranja preenchido no passo 1 da edição, tema claro; Salvar alterações preenche após motivo. / BE inalterado. / E2E verified-e2e via access-profiles.edit. |
| owner.r12-27 | access-profiles.create, access-profiles.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/access-profiles-edit-assign-20260917.md | Concluído 17/09 (Bloco A). Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (Bloco A 17/09): revisão "Acessos › Modelos de perfil › Inativar modelos Admin.", texto configuração × acesso efetivo, vínculos impactados, MFA, motivo obrigatório; salvo sem perder permissões e relido. / BE inalterado. / E2E verified-e2e via access-profiles.edit. |
| owner.r12-29 | health-care.create, health-care.edit, health-care.detail | deferred / Sessão D provou em produção a coleção independente de alergias, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | docs/reviews/evidence/etapa-2/r14-sessao-2/block-d-20260915.md; docs/reviews/etapa-2-operacao/next-round/R14-handoff-sessao-2.md | ADR 0041 A2/§5: não aceito ainda — Owner quer prova com mais registros e redesenhou o contrato (wizard Alimentos × Restrições, nome de lista categorizada, reordenar, "O que fazer se consumido?"). Spec para R15; coleção + limite 100 já em produção são a base. **Mesa R16 (ADR 0044): Etapa 3, tela a tela.** |
| owner.r12-30 | health-care.create, health-care.edit, health-care.detail | deferred / Sessão D provou em produção a coleção independente de orientações, com IDs, adicionar/remover/reload e compatibilidade legada; pgTAP remoto 6/6 e limite backend de 100, com rejeição do 101º. / BE done. / verified-e2e das ações; aceite central ainda pendente. | docs/reviews/evidence/etapa-2/r14-sessao-2/block-d-20260915.md; docs/reviews/etapa-2-operacao/next-round/R14-handoff-sessao-2.md | ADR 0041 A2/§5: idem r12-29 para orientações de cuidado (lista pré-definida, reordenar). Spec para R15. **Mesa R16 (ADR 0044): Etapa 3, tela a tela.** |
| owner.r12-33 | medication.create, medication.edit, medication.detail | partial / FE local-green (Sessão 10, 16/09): sino já lia `context_notification_*`; rótulos para plano criado/atualizado/status e dose registrada (resumo por desfecho). / BE local-green: `20260916190000_medication_in_app_notifications_v1` (destinatários = admins da unidade + educadores da turma, sem responsáveis; editar plano → `medication.plan.updated`; cada dose → `medication.dose.recorded`; `not_tracked` silencia) + pgTAP 29/29 no espelho; criar plano já notificava em produção (trigger existente, audiência mantida); NÃO aplicada em produção. / Pendente: aplicar a migration, editar plano e registrar dose reais e observar o sino com identidade da unidade/educador (bloqueio: incidente PostgREST 504). | docs/reviews/evidence/etapa-2/r14-sessao-10/medication-notifications-20260916.md; specs/053-superadmin-medication-in-app-notifications.md | Aplicar `20260916190000` pelo rito após o incidente; provar o sino na rota real com duas identidades (admin da unidade e educador da turma); sem e-mail/push. |
| owner.r12-39 | forms.edit, forms.create | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/forms-create-edit-delete-file-20260917.md | Concluído 17/09 (Bloco A). Arraste não exercitado por CDP; botão de mover prova a posição final. Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (Bloco A 17/09): pergunta movida por botão (B antes de A), rascunho salvo, carga completa preserva a ordem (position 0/1 no servidor). / BE done (form_save_draft). / E2E verified-e2e via forms.create/edit (409 PT409 em versão defasada). |
| owner.r12-40 | forms.edit, forms.create | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/forms-create-edit-delete-file-20260917.md | Concluído 17/09 (Bloco A). Detalhe da prova (R15 Bloco A, 17/09): FE verified na rota real (Bloco A 17/09): "Renomear seção" por diálogo (contador /120), nome na lista, no título da seção, no editor após reload e na prévia. / BE done (form_save_draft). / E2E verified-e2e via forms.create/edit. |
| owner.r12-46 | account.profile | deferred / FE verified na rota real (Bloco A 17/09): foto PNG real pelo seletor nativo, avatar do cabeçalho atualizado só após confirmação do servidor, remover foto, sigla QR, celular inválido bloqueado × válido gravado, layout A+ "Meu acesso" na mesma linha com rolagem interna. / BE done: Edge account-media (prepare/finalize/read/remove) + save_v2/get em produção; asset alheio/removido → denied (422). / E2E verified-e2e: reload e nova sessão veem a foto do R2; remoção relida. | docs/reviews/evidence/etapa-2/r15-bloco-a/account-profile-20260917.md | Falta só a máscara/formatação de entrada e a normalização do Celular (cliente valida 7–40 caracteres; servidor grava como digitado). Decidir formato (E.164 × exibição) e implementar; opcional: mapear denied da Edge para 403. **Mesa R16 (ADR 0044): Etapa 3, tela a tela.** |
| owner.r12-49 | assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | partial / FE verified em entry/gradebook/detail (rota real 14/09): participante listada, nota 8.5 salva e relida. / BE done em entry/gradebook/detail (lote 63 + save pela tela); close/reopen local-green. / verified-e2e em entry/gradebook/detail; close/reopen pendentes na rota real. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Aplicar candidato após gate SQL; usar o mesmo diário d2c945d8, lançar/reler nota, fechar/reabrir com versão e provar escopo real. Não duplicar participante, vínculo, configuração ou diário. |
| owner.r12-52 | chat.attach | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-c1/chat-attach-e3-20260917.md; specs/058-superadmin-chat-multi-attachment-message.md; docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md | Concluído 17/09 (R15 C1, ADR 0042 E3 = B): FE verified (rota real 17/09, R15 C1): seletor múltiplo, diálogo de lote com progresso e falha tratada, mosaico 3 e 3+1 (+N), tile único (PDF e imagem), reload. / BE done (lote 76): contrato E3 `superadmin_chat_attachment_prepare_v2`/`finalize_v2`/`discard_v1` — uma mensagem por lote de 1–10, 11º recusado (422), publicação só quando todos terminam; Edge `chat-media` em lote; pgTAP 51/51 + 28/28 + 9/9. / E2E verified-e2e em produção: mídia R2 real, reload por `thread_v2`, negativas 404/422/409 por PostgREST. Mosaico alcançável pela rota normal com vários anexos na mesma mensagem. |
| owner.r12-53 | gate/mapeamento pendente | deferred / Não iniciada; condição de abertura não atendida. / Não iniciado. / Pendente; transferência documental não certifica execução. | docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Não promover `institutions.status` ou `institutions.locations-map` na R14: estão fora do MVP/escopo ativo. OQ-034 (Locais com mapa por imagem) fica preparado para a R15, sem abrir outro macrotema. **Mesa R16 (ADR 0044): Etapa 3, tela a tela.** |
| owner.r12-18 | child-safety.create | partial / FE verified (R15 C2, 17/09): cadastro de pessoa sem conta no wizard com CPF mascarado, contato e documento obrigatório; wizard percorrido na 3016 até a revisão. / BE done (lote 78): tabela/RPC com dedupe por (instituição, CPF) provado pela tela e por RPC, documento em R2 privado `ready` pelo gateway (prepare/PUT/finalize/read 200 com `child-safety-media` v2), pgTAP 40/40. / E2E parcial: envio com `authorized_person_id` provado pela RPC com o payload exato do wizard (pendente b729f6b8 relido); o clique final "Enviar" pela tela não concluiu (aba do Chrome parou no CDP) e o upload do documento pelo navegador depende do CORS de `coelo-documents-prod` (E13). | docs/reviews/evidence/etapa-2/r15-bloco-c2/rota-real-b5-b6-r12-38-20260917.md; docs/reviews/evidence/etapa-2/r15-bloco-c2/person-search-and-person-without-account-20260917.md; specs/062-superadmin-child-safety-person-without-account.md | R16: repetir o envio final pela tela e o upload pelo navegador quando o CORS do bucket existir; PERSON_HAS_ACCOUNT só por pgTAP (massa). |

## Owner items — concluídos (39; não voltam à execução)


| ID | action_ids | Estado (status / FE / BE / E2E) | Evidência | Próximo gate |
|---|---|---|---|---|
| owner.r12-34 | meal-plans.model-create, meal-plans.model-edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2; imagem R2 segue em owner.r12-38. |
| owner.r12-35 | meal-plans.model-create, meal-plans.model-edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-37 | meal-plans.create, meal-plans.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-2/meal-plans-20260915.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: aceite do Owner (ADR 0041 A1) sobre a prova da Sessão 2. |
| owner.r12-09 | child-safety.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-directory-diagnostic-r12.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: Owner aprovou o card atual sem campo alerta/restrição (ADR 0041 B4). |
| owner.r12-11 | gate/mapeamento pendente | done / Cards já têm situação + Escopo máximo/Vínculos/Tipo em composição compacta; pages 15/15 PASS. / Contrato preservado; nenhum SQL/RPC novo. / Visual golden pendente de reconciliação; sem action_id novo. | docs/reviews/evidence/etapa-2/r12-coordenacao/access-profiles-cards-diagnostic-r12.md; decisions/0041-owner-decisions-r14-mesa-20260916.md | Concluído 16/09: Owner aprovou a composição atual dos cards (ADR 0041 C2); golden regrava com o cabeçalho (C1). |
| owner.r12-03 | activities.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/activities-list-publish-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/activities-list-tabs-r12.md | Concluído 15/09 (rota real, Sessão 1): abas "Modelos de atividade"/"Atividades", busca, filtros, cards/tabela, status, paginação e reload com dados reais; negativa por id inexistente e escopo pgTAP. |
| owner.r12-07 | attendance.mark, attendance.correct, attendance.finish | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-12 | child-safety.child | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-authorization-status-r12.md | Concluído 15/09 (rota real, Sessão 1): tabela distingue "Aprovado · Suspensa" e mantém validade com dados reais; reload e negativa P0002. Golden 1440 permanece em r12-10. |
| owner.r12-14 | child-safety.child | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-relationship-r12.md | Concluído 15/09 (rota real, Sessão 1): mother/father reais exibidos como Mãe/Pai na tabela e no diálogo, em pt-BR, com dados de produção. |
| owner.r12-28 | health-care.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): edição com o nome real da criança (correção 165d3df8c), sinal salvo (version 1→2) e relido após reload. |
| owner.r12-31 | medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): criação Paracetamol R13 (10 ml, oral, vigência, 08:00, Seg/Qua) e edição da dose 5→7 ml da Dipirona R06, persistidas e relidas. Responsável depende de owner.r12-33 (R14). |
| owner.r12-32 | medication.list, medication.detail, medication.create, medication.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/evidence/etapa-2/r12-coordenacao/health-medication-r12-28-32.md | Concluído 14/09 (rota real): diretório lista os planos reais por criança com contexto explícito; detalhe/criação/edição provados e relidos. |
| owner.r12-41 | forms.list | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-42 | agenda.request | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/agenda-request-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/agenda-approvals-r12-42.md | Concluído 15/09 (rota real, Sessão 1): tabela canônica, decisão aprovar/recusar com justificativa, histórico em diálogo, reload e negativa; defeito de rótulos pós-decisão corrigido (teste vermelho→verde). Golden de calendário loading dark 375 fica fora deste action_id. |
| owner.r12-43 | chat.open | done / verified / not-applicable / flutter-only | docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md | Ajuste visual entregue; não refazer |
| owner.r12-44 | invites.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/invites-list-resend-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/invites-list-table-only-r12.md | Concluído 15/09 (rota real, Sessão 1): tabela-only, busca/filtros/paginação/Novo convite/ações por linha, reload; convite real expirado e renovado na mesma tabela. |
| owner.r12-45 | invites.resend | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r14-sessao-1/invites-list-resend-20260915.md; docs/reviews/evidence/etapa-2/r12-coordenacao/invites-resend-discovery-r12.md | Concluído 15/09 (rota real, Sessão 1): convite expirado real (emitido com 1 h por RPC autorizada), reenviado uma vez pela tela, link de uso único (mascarado), reload e negativas SAI_INVALID_ARGUMENT/SAI_CONCURRENT_CHANGE; sem SMTP. |
| owner.r12-48 | activities.assessment, activities.publish | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): rascunho b04c879e carregado e salvo pela tela (version 2→3), reload relê, negativa por id inexistente; activities.publish já era done. Capturas em r13-coordenacao/capturas. |
| owner.r12-50 | groups.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Concluído 14/09 (rota real): /groups com Alunos 1 e Atividades 3 na turma 4214106c, busca "R05" (hotfix lote 64), reload mantém, negativa por instituição alheia. Capturas em r13-coordenacao/capturas. |
| owner.r12-51 | gate/mapeamento pendente | done / Não aplicável. / Done (lote 63, 14/09): quatro candidatos aplicados em produção com dump SHA-256, espelho e pgTAP verdes, ledger 283→287. / Não aplicável. | docs/reviews/evidence/etapa-2/r13-coordenacao/lotes-63-64-provas-producao-20260914.md; docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md | Owner resolve exigência PITR da R11 versus ADR0034D8; C0 confirma regra vigente, configuração real, backup atualizado e ordem serial antes de aplicar. Transferir rodada não concede exceção ou autorização nova. |
| owner.r12-13 | child-safety.create, child-safety.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-b/child-safety-edit-suspend-20260917.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-composition-r12.md | Concluído 17/09 (rota real, Bloco B): criar e editar pela rota normal com escopo real (busca server-side), revisão, persistência (3f3650b0 v1→v2) e reload; negativa PT409 sem 504 (lotes 74/75). |
| owner.r12-15 | child-safety.child, child-safety.edit, child-safety.suspend | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-b/child-safety-edit-suspend-20260917.md; docs/reviews/evidence/etapa-2/r14-sessao-1/child-safety-child-20260915.md | Concluído 17/09 (rota real, Bloco B): diálogo Gerenciar nos três estados — pendente (Aprovar/Rejeitar/Editar/Concluir), aprovado-ativo (Situação Ativa, Suspender, Concluir) e suspenso (só Concluir); aprovar e suspender pela tela (v3/v4), reload, PT409. Observação: o diálogo mostra o contexto do cabeçalho da criança, não o da autorização (composição; tabela e revisão corretas). |
| owner.r12-16 | child-safety.create | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-b/child-safety-edit-suspend-20260917.md; docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md | Concluído 17/09 (rota real, Bloco B): clicar etapa futura (Revisão) na etapa 1 não avança; voltar da Revisão para Pessoa autorizada preserva os dados; sem salto e sem perda. |
| owner.r12-01 | daily-routine.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-c1/arquivar-b1-20260917.md; docs/reviews/evidence/etapa-2/r14-sessao-9/daily-routine-cards-r12-01-20260916.md | Concluído 17/09 (R15 C1, ADR 0041 C3): cards de Modelos de rotina na rota real em 1440 com altura uniforme, "Efetivo: —" e Arquivar em todos; reload. |
| owner.r12-02 | activities.list, daily-routine.list | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-c1/arquivar-b1-20260917.md; docs/reviews/evidence/etapa-2/r14-sessao-9/archive-models-b1-20260916.md; specs/054-archive-activity-routine-models.md | Concluído 17/09 (R15 C1, ADR 0041 B1): lote 74 em produção; Arquivar/Restaurar pela tela em Atividades › Modelos (aba Arquivados) e Rotina › Modelos (filtro Arquivado), reload, negativas PT409/P0002/55000 por PostgREST. Sobra: diretório de Atividades do Owner de plataforma não alcança modelos institucionais (observação FE). |
| owner.r12-47 | auth.recover, auth.reset | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-a/auth-recover-reset-20260917.md | Concluído 17/09 (Bloco A) por decisão E10; Etapa 3: provar link real, senha nova/nova sessão, expiração e uso único com SMTP próprio. Detalhe (R15 Bloco A, 17/09; E10): FE verified (R02/R11) + rota real 17/09: /forgot-password com o e-mail do Owner → 200 e "Confira seu e-mail"; e-mail inexistente → mesma tela e 200 (sem enumeração); redirect 127.0.0.1:8765 na allowlist; nenhum link/token registrado. / BE: auth.recover done (entrega real 16/09); auth.reset done por contrato Auth + allowlist. / E2E verified-e2e: recover pela tela; reset aceito por decisão do Owner de 17/09 (ADR 0042 E10) — verificação detalhada na Etapa 3 com SMTP próprio. |
| owner.r12-17 | child-safety.create, child-safety.edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-c2/rota-real-b5-b6-r12-38-20260917.md; docs/reviews/evidence/etapa-2/r15-bloco-c2/person-search-and-person-without-account-20260917.md; specs/061-superadmin-child-safety-person-search.md | Concluído 17/09 (R15 C2, lote 78, ADR 0041 B5): busca única com mínimo por tipo (22023 abaixo do mínimo), resultado minimizado sem CPF, seleção preenche criança + pessoa, autorização pendente criada e relida no detalhe da criança, limite de taxa 422 na 31ª chamada, escopo vazio fora do ator. Resíduo (massa): celular/CPF e responsável → crianças provados só por pgTAP 33/33. |
| owner.r12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | done / verified / done / verified-e2e | docs/reviews/evidence/etapa-2/r15-bloco-c2/rota-real-b5-b6-r12-38-20260917.md; docs/reviews/evidence/etapa-2/r15-bloco-c2/person-search-and-person-without-account-20260917.md; specs/063-superadmin-meal-plan-images-r2.md | Concluído 17/09 (R15 C2, lote 78, ADR 0032): imagem enviada pelo Media Gateway R2 a partir do navegador (3016), defeito `simpleImageMeta` corrigido, prévia após reload real, cardápio publicado (revisão 8), model-edit sem regressão; pgTAP 26/26. Resíduo: 2 ativos órfãos em cardápio publicado (imutável) para limpeza na R16. |

## Resíduos H (herdados de R01–R07) — na R16 (9; Mesa R16)


| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H18 | R06 | Unicidade global concorrente de `@` | Revisar concorrência entre tabelas. |
| H19 | R06 | Responsável vazio em Medicação | Reproduzir com contexto e destinatário válidos. |
| H20 | R06 | Imagem da dose sem gateway | Localizar consumidor e obter prova específica. |
| H21 | R07 | Limite de texto/rodapé de Circular | Parcial em 14/09: **backend concluído (lote 68)** — `save_draft_v2` e constraint de `circular_revisions` em 4.000 somando blocos de texto; pgTAP 10/10; produção recusa 4.001 (`CIRCULAR_INVALID_INPUT`). Cliente `CircularLimits.bodyCharacters = 4000` (contador já somava blocos). Falta H04: host/rodapé em card/Opções conforme referência e regravação dos goldens web (18 goldens de circular já falhavam antes desta mudança). |
| H22 | noturna/R01 | Descritor privado de Circular | Alinhar à ADR 0032 e provar ausência de bucket público. |
| H24 | noturna/R01 | Rótulos do Sobre | Comparar com referência vigente. |
| H25 | noturna/R01 | Alvo de redimensionamento de tabela | Medir teclado, semântica e toque. |
| H27 | noturna/R01 | Sinal de atualização de Momentos | Decidido (ADR 0038): saudação por hora do dia; ponto laranja na aba Momentos quando há momento não visto. Próximo gate: implementar no Principal + prova. |
| H28 | R01 | Filtros, avatar e buffers de Pessoas | Rever somente diferenças funcionais persistentes. |

## Resíduos H — transferidos (14: 10 → Etapa 3 pela Mesa R16; H08/H13/H23 → R16; H11 → V1)


| ID | Origem | Motivo da transferência |
|---|---|---|
| H11 | noturna/R01 | **V1** por decisão do Owner em 16/09 (ADR 0041 B10): autosave de autoria de Formulários sai do MVP sem medir o limiar de 60%; testes locais preservados, nenhum aceite remoto exigido. |
| H08 | R02 | Autorizado pelo Owner em 15/09; falta contrato produtivo do item a duplicar e `action_id`, portanto não inventar RPC, payload ou coluna na R14. |
| H13 | noturna/R01 | Autorizado pelo Owner em 15/09; falta referência produtiva de item relacionado e `action_id` para o CTA. |
| H23 | noturna/R01 | Autorizado pelo Owner em 15/09; implementação visual depende do contrato de Avisos que será definido junto com H08/H13 na R15. |
| H02 | noturna/R01 | **Etapa 3 (Mesa R16, ADR 0044)**: Atualização oficial a partir do Sobre — revisão tela a tela; gate anterior: Decidido (ADR 0038): conectar no MVP. Próximo gate: consumidor produtivo de ProfileAboutOfficialUpdateRequest e prova na rota normal. |
| H03 | noturna/R01 | **Etapa 3 (Mesa R16, ADR 0044)**: Composição das quatro abas de Perfil — revisão tela a tela; gate anterior: Comparar referência vigente e decidir consumidor produtivo. |
| H04 | R02/R07 | **Etapa 3 (Mesa R16, ADR 0044)**: Compositor produtivo de Circular e blocos intercalados — revisão tela a tela; gate anterior: Unificar host e provar na rota normal. |
| H07 | noturna/R01 | **Etapa 3 (Mesa R16, ADR 0044)**: Hash de edição/revogação sem `conversation_id` — revisão tela a tela; gate anterior: Executar replay/contexto na revisão de segurança. |
| H09 | R04/R06 | **Etapa 3 (Mesa R16, ADR 0044)**: Disparo agendado de expiração Agora — revisão tela a tela; gate anterior: Medir trigger real; leitura não basta. |
| H10 | noturna/R01 | **Etapa 3 (Mesa R16, ADR 0044)**: Múltiplas regras de audiência em Formulários — revisão tela a tela; gate anterior: Decidido (ADR 0038): preservar todas as regras de audiência. Próximo gate: editor lista/edita regras sem perder as demais + teste. |
| H12 | noturna/R01 | **Etapa 3 (Mesa R16, ADR 0044)**: Controles de mínimo/máximo de seleção — revisão tela a tela; gate anterior: Localizar contrato e registrar aceite. |
| H14 | R06 | **Etapa 3 (Mesa R16, ADR 0044)**: Sino sem `action_id`/subaceite — revisão tela a tela; gate anterior: Mapear ao action_id-pai sem novo denominador. |
| H16 | R06 | **Etapa 3 (Mesa R16, ADR 0044)**: Leitura people-based de cuidado — revisão tela a tela; gate anterior: Provar escopo entre unidades. |
| H26 | noturna/R01 | **Etapa 3 (Mesa R16, ADR 0044)**: Opcional, escala legada e opções vazias — revisão tela a tela; gate anterior: Reconciliar contrato atual por caso. |

## Resíduos H — concluídos (4)


| ID | Origem | Escopo pendente | Próximo gate |
|---|---|---|---|
| H05 | noturna/R01 | Denominador histórico de recibos do Chat | Decidido (ADR 0038): recibos contam participantes ativos atuais. Fechado sem mudança; aceite MVP mantido. |
| H06 | noturna/R01 | Revogar em Chat somente leitura | **Concluído em 14/09 (lote 65)**: `superadmin_chat_revoke_message_v2` recusa `CHAT_READ_ONLY` no servidor; pgTAP 14/14 + suíte base 36/36 no espelho; guard presente em produção; negativa `CHAT_NOT_FOUND` por RPC. `chat.revoke` já era verified-e2e; sem delta de estado. |
| H17 | R06 | Papel fixo versus capacidade em cuidado | **Concluído em 14/09 (lote 66)**: capacidade `care_policies.manage` nos catálogos Superadmin (Owner) e Admin (Administrador da instituição); `superadmin_unit_care_policy_set_v1` exige só a capacidade; pgTAP 15/15 + base 20/20; get/set/reload em produção na unidade f5284f2f e negativa por unidade alheia. Sem action_id próprio no inventário (sem tela no cliente); sem delta de estado. |
| H15 | R06 | Atribuição de Plano | **Concluído por decisão de escopo:** `plans.assign` fica fora do MVP; botão e operação permanecem honestamente indisponíveis. |

## Itens da ADR 0038 sem ID H nem Owner item — aberto (1) e transferidos (2)


| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Reader de Planos comerciais no Principal (039) | Transferido para V1/V2 | Não executar na R14; preservar contrato e IDs como preparação futura. `units_with_override` só deve ser calculado quando o Owner abrir o escopo. |
| Local interno em Formulários (IDs fixados na publicação; revisão conserva valor) | Aberto | Verificar contrato atual de `form_publish`/resposta; pacote só se faltar. |
| Auth: localhost na allowlist de redirect (R12-47) | Transferido para Etapa 3 | Não executar na R14; pertence ao contrato futuro de recuperação/reset, com ambiente e prova próprios. |

## Itens da ADR 0038 — concluídos (5)


| Item (ADR 0038) | Estado | Gate / evidência |
|---|---|---|
| Catálogos globais de tipo (OQ-031) | Concluído 16/09 (aceite do Owner, ADR 0041 A3) | Sessão D aplicou a migration `20260915131500` em produção e confirmou pgTAP remoto 11/11, quatro catálogos com oito entradas e "Outros"; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Reader self da Conta (039) | Concluído 16/09 (aceite do Owner, ADR 0041 A3) | Sessão D aplicou a migration `20260915133000` em produção e confirmou pgTAP remoto 6/6, sessão autenticada e ausência de sobrecarga por UUID; evidência no branch `origin/r14/bloco-cd` (`b135c8f20`). |
| Anexos por mensagem no Chat (10 por envio) | **Concluído em 14/09 (lote 67)** | `superadmin_chat_attachment_prepare_v1` recusa o 11º pendente com `CHAT_ATTACHMENT_LIMIT` (422); pgTAP 9/9 + base 28/28; produção: 10 aceitos e 11º recusado na conversa 355a3403 (sintéticos arquivados); cliente mapeia `chat_attachment_limit` (243 testes do chat verdes). |
| Status de Suporte (OQ-028) | **Concluído em 14/09 (lote 69)** | `set_status` grava open/pending/resolved conforme o mapeamento A; trigger mantém `ticket_status` coerente (expired/revoked → Concluído); `closure_reason` em get/list; pgTAP 13/13 + bases 23/23, 28/28, 17/17; produção: chamado 6c5eb791 waiting→pending, completed→resolved. Cliente mostra “Concluído · Expirado/Revogado”. |
| Identidade da mídia do Chat (`asset_id` no envelope) | Concluído 16/09 (OQ-046, lote 72) | `superadmin_chat_thread_v2` devolve `asset_id` em produção (dump de 16/09); Edge `chat-media` publicada pela Sessão E; migration `20260915130100` no ledger remoto. |

## Ações não terminais por família (inventário: 2 ações; FE/BE/E2E)


Projeção regenerada em 17/09/2026 a partir de `inventario-etapa-2.json` (coordenadora R15): ações `mvp`/`gate-formal-mvp` cujo estado integrado
não é `verified-e2e` nem `flutter-only`. As 33 ações de escopo `v1` (Mesa R16, ADR 0044) ficam fora dos denominadores;
`errors.409` (flutter-only) provado na rota real em 17/09 (Sessão A).

| Família | Qtd | action_ids |
|---|---:|---|
| agora | 1 | `agora.publish` (verified/done/pending-verification) |
| forms_responses | 1 | `forms.location-answer` (local-green/pending-verification/pending-verification) |

## Resíduos operacionais sem action_id (varredura R01–R15, 17/09/2026)

| Item | Origem | Estado | Gate |
|---|---|---|---|
| Migrations em produção | R14/R15 | **Lotes 74–80 aplicados** (ledger até `20260917180000`; fixture `20260917110000` executada; candidato AP-2 `20260917113000` versionado e **não aplicado**, OQ-048) | Provas E2E restantes sobre esses lotes (Assiduidade, Medicação, B5/B6/Cardápios). |
| Incidente PostgREST 40001 (OQ-047) | R14 Sessão 8 | **Encerrada em 17/09 (lote 75)**: 0 `raise serialization_failure`, 0 `errcode='40001'` em produção; regra durável projetada em `docs/knowledge` e skills | — |
| Goldens pré-existentes | R12–R15 | 55 regravadas (30 na R14, 25 Principal na R15, E4); restam falhas fora do E4: notice_directory (filtro Estado), forms (editor/operations/response), invites (golden + responsive), meal_plans (diretório), platform_users | Regravar só com diff decidido por família; `invite_responsive_test` procura toggle removido na R14 (corrigir o teste). |
| Testes pré-existentes vermelhos | anterior à R14 | `model_save_completion_routes_test` (3), `principal_real_route_test` (1), `principal_profile_for_you_production_routes_test` (1), `activity_routes_test` (1), testes de router `principal-context-selector` | Corrigir antes do próximo censo. |
| Censo completo de suítes (G8, R09) | R09 | **Executado em 17/09** no `apps/superadmin` (resultado em `R15-checkpoint-20260917.md`) | Repetir por pacote a cada fechamento. |
| Deploy público do frontend (R09 C0) | R09 | Sem deploy público; builds QA locais; `superadmin.coelo.me` não existe | Etapa 3: host, allowlist de Auth e CORS dos buckets com a origem pública. |
| CORS dos buckets R2 | R15 C2 | `coelo-media-prod` só 3014/3016; `coelo-documents-prod` nenhuma origem; Owner decidiu não alterar em 17/09 (E13) | Etapa 3 junto do deploy público; provas locais usam 3014/3016 ou o gateway por Node. |
| Conta `qa-r15-responsavel` e massa QA R15 | R15 B/B′ | Conta em produção (`ff3682a1…`), fixture AP-1 executada (responsável ativa com login, 2 crianças, permissões `can_view`); sem `institution_memberships` (OQ-048) | Usar nas provas de responsável por PostgREST; não criar membership. |
| `owner.r12-46` layout A+ "Meu acesso" e máscara do Celular | R13/R15 | Card A+ pendente; Celular sem máscara/normalização (só 7–40 caracteres) | coelo-ui + contrato de normalização; r12-46 permanece partial. |
| Stream genérico | R14 Sessão E | **Encerrado (Mesa R16, ADR 0044: sem necessidade)** | — |
| Espelho CLI `supabase/migrations` | R14/R15 | Cópias não rastreadas; `migration repair` exige a cópia em `supabase/migrations/` | `Sync-SupabaseCliMigrations.ps1 -Mode Clean`; corrigir o script. |
| Worktrees/branches/tags | R14/R15 | **Limpeza executada em 17/09/2026** (manifesto `docs/agent/branch-cleanup-manifest-20260917.md`; bundle `Coelo-backups/r15-fechamento/coelo-all-refs-20260917-pre-limpeza.bundle`) | Restam só `dev` remota e a pasta principal; sessões futuras criam worktree nova de `dev`. |

## Decisões de escopo do Owner (14/09, 15/09, 16/09 e 17/09; ver `docs/agent/backlog.md`)


Fora do MVP: operações de Planos comerciais (listar/criar/editar/arquivar/restaurar/
atribuir/vincular/entitlements), `plans.assign`, Financeiro, `institutions.status`,
`institutions.locations-map`, MFA ×3.
V1/Etapa 3: Catálogo de UI. Formulários autosave (H11): V1 se for caro, salvo se >60% pronto.
Etapa 3: `auth.recover`/`auth.reset`; 3 instituições fictícias com hierarquia para o Owner verificar "Para você" (nome a rever).
Antes do fim do MVP: perfis oficiais do Coelo (OQ-032). R15: OQ-033 (decidido em 15/09: opção B + regra de pessoas) e OQ-034 Locais com mapa por imagem (confirmado em 15/09; substitui `institutions.locations-map`).

**15/09/2026 — abertura da execução (artefato 89AVWHKEnq5hrvYN6SFv6M):** temas explicados e sete decisões registradas em `R14-execucao-paralela.md` (papéis, worktrees, portas, handoffs, Bloco B autorizado com E2E ativo 199 → 192, ordem do Bloco C e ordem original do Bloco D). A formalização posterior de `agora.remove` levou a base ativa a 193. Duas sessões executaram em paralelo; a coordenadora (Codex) atualiza este arquivo. A decisão posterior da ADR 0039 transfere recuperação/reset de Auth e a allowlist desse fluxo para a Etapa 3.

**16/09/2026 — Mesa do Owner (artefato Jrsk1XBe97MCLpeUBGAeYz, ADR 0041):** 27 decisões registradas; `institutions.files` fora do MVP; páginas de erro `flutter-only`; H11 → V1; perfil transversal e Perfis de cuidado redesenhados → specs R15; contratos B1–B9 fixados; autorizações D1–D5 concedidas, D6 negada.

**17/09/2026 — execução da R15 e abertura da R16 (adendo ADR 0042 E10–E14; ADR 0043):** reset de senha aceito por decisão (prova detalhada → Etapa 3); conta `qa-r15-responsavel` criada em produção; lotes 78–80 e redeploys (`child-safety-media` v2, `form-media` v23 com `verify_jwt=false`) autorizados; CORS dos buckets R2 mantido (Etapa 3); R15 fechada e R16 aberta com unificação do repositório em `dev`.

**17/09/2026 — Mesa R16 (ADR 0044):** 91 decisões; Etapa 2 medida pelo E2E do MVP; 33 ações → `v1` fora dos denominadores; 7 Owner items e 10 H → Etapa 3; Stream encerrado.

## Como atualizar

- Estado por `action_id`: só via `apply-tracker-delta.cjs` com evidência certificada (inventário → três rastreadores).
- Owner items: editar a linha aqui e rodar `node docs/reviews/etapa-2-operacao/next-round/sync-r12-owner-records.cjs`.
- H, itens da ADR e resíduos operacionais: editar a linha aqui. Nunca editar R12/R13/R14/R15 (históricos).
- Validar sempre com `node docs/reviews/validate-trackers.cjs`.
- Execução paralela: modelo em `R15-execucao-paralela.md` (histórico); uma R16 paralela exige arquivo próprio.
- Recuperação/redefinição de senha: `auth.recover` E2E pela tela e `auth.reset` por decisão E10 (17/09); prova detalhada do link na Etapa 3.
