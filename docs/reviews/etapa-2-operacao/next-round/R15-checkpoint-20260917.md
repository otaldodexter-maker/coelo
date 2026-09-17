---
title: "R15 — checkpoint de 17/09/2026 (fechamento)"
source: "R15-handoff-bloco-a.md; R15-handoff-bloco-b.md; R15-handoff-bloco-c1.md; R15-handoff-bloco-c2.md; R15-apoio-bloco-b.md; relatórios finais das sessões (mensagens de 17/09); validate-trackers.cjs em 37d762976"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — checkpoint de 17/09/2026

Corte final integrado em `dev` pela coordenadora. A fila vigente passa a ser
`R16-pendencias.md` (ADR 0043).

## Contadores (validate-trackers, `37d762976`)

| Métrica | Abertura 16/09 | Fechamento 17/09 | Δ |
|---|---|---|---|
| FE verificado | 189/232 | **207/232** | +18 |
| BE concluído | 172/219 | **185/219** | +13 |
| E2E verificado | 162/186 | **184/186** | +22 |
| Owner items done | 21/53 | **39/53** | +18 |

## action_ids certificados nesta rodada (evidência em produção)

- `chat.attach`
- `access-profiles.edit`
- `access-profiles.assign`
- `institutions.error`
- `institutions.access-denied`
- `account.profile`
- `principal.for-you`
- `principal.profile-edit`
- `forms.create`
- `forms.edit`
- `forms.delete-file`
- `momentos.create`
- `momentos.publish`
- `momentos.view`
- `momentos.remove`
- `child-safety.edit`
- `child-safety.suspend`
- `agora.expire`
- `agora.remove`
- `auth.recover`
- `auth.reset`
- `forms.expire-file`

## Produção (lotes e Edges)

- Lote 75 — `20260917090000_pt409_stale_version_v1` (B, 12:30 UTC).
- Lote 76 — `20260917120000_chat_attachment_batch_v2` + Edge `chat-media` (C1).
- Lote 77 — `20260917130000_principal_for_you_reader_v1` (C1).
- Lote 78 — `20260917160000/170000/180000` + Edges `child-safety-media`, `meal-plan-media`,
  `meal-plan-image-cleanup` (coordenadora, autorização nominal E12); `child-safety-media` v2.
- Lote 79 — `20260917140000_now_feed_removal_projection_v1` + Edge `now-media` (B).
- Lote 80 — `20260917110000_qa_r15_guardian_fixture_v1` (migration + execução da fixture, B);
  conta `qa-r15-responsavel@coelo.me` criada pela Admin API (E11).
- `form-media` v23 com `verify_jwt=false` (E14) — cron de expiração voltou a executar.
- Candidato não aplicado: `20260917113000_qa_r15_guardian_membership_v1` (AP-2, OQ-048).

## Bloqueios por causa (o que ficou)

- **massa/contrato**: `forms.location-answer`, `agora.publish`; conta só-responsável sem tela (OQ-048).
- **decisão do Owner**: reset detalhado e SMTP (Etapa 3, E10); CORS dos buckets R2 (E13);
  MFA (E9); membership de responsável não criada (OQ-048).
- **ambiente**: CORS `coelo-documents-prod`/`coelo-media-prod` (só 3014/3016);
  `superadmin.coelo.me` inexistente.
- **RPC**: `ACTIVITY_INVALID_REFERENCE` na criação de atividade pela tela (r12-05, B; a isolar).
- **sessão**: incidente da instância duplicada da Sessão B (09:00–09:06; sem efeito em produção).

## Censo de suítes (apps/superadmin, 17/09)

`flutter test` completo em `apps/superadmin` (17/09, dev `3391d0a1a`, 18 min): **6939 passaram, 8 pulados, 160 falharam**. Das falhas, 139 são goldens em 33 suítes (deriva do cabeçalho global C1/E4 e diffs por família: agenda 16, principal_happens/_publication 21, groups 11, principal_circulars 10, activities 9, institutions 10, meal_plans 5, invites 5, imports 4, health_care 4, circulars 6, attendance 4, account 4, notices 3, forms 5, units/support/platform_users/people/audit/plans/help_center) e 21 são funcionais pré-existentes ou de fixture: `invite_responsive_test` ×9 (procura `CoeloAdminDirectoryViewToggle` removido quando Convites virou tabela-only), `model_save_completion_routes_test` ×3, `principal_real_route_test`, `principal_profile_for_you_production_routes_test`, `activity_routes_test`, `directory_composition_test` (arquitetura), `forms_directory_internal_reader_test`, `production_circular_attachments_test` (cota de 4 arquivos), `superadmin_circular_pages_test` (375 px/200 %), `location_consumer_routes_test`, `principal_moments_publication_page_test` (rascunho vazio não deve injetar mídia de demonstração — coincide com o achado UX da C1). Nenhuma falha nova atribuída às fatias da R15 além dessas já conhecidas; corrigir na R16 antes do próximo censo.

## Relatórios finais das sessões

- A: A: HEAD 7439b84e3. Certificados: access-profiles.edit/assign; institutions.error/access-denied; account.profile; forms.create/edit/delete-file/expire-file; errors.409 (flutter-only); auth.recover; auth.reset (E10). Owner done: r12-20,21,22,24,25,26,27,39,40,47; r12-46 partial (mascara/normalizacao do Celular). Nao concluido: forms.location-answer — ocorrencias usam a versao publicada antiga 49c338d7 sem a pergunta Local (v4 so na versao de trabalho); falta Publicar agora, ocorrencia nova e responder como qa-r06-formularios (pessoa-ator elegivel). Defeitos FE corrigidos: catalogo de instituicoes ausente na edicao de usuario interno; PT409 no cliente. Massa residual: perfil 281699f2 v2; usuario interno bf6008f0 v4 (Owner restaurado); qa-r06-acessos sigla QR/celular sintetico/sem foto; form 90b905a1 draft v4 (asset 9e437fa9 deleted); form 4555ba07 com agendamento Diario (30 ocorrencias; voltar a "Uma vez"). Sobras: tooltip empilhado em Perfis; chip Mensagens sobre Continuar; rotulos padrao do editor; superadmin_forms_*_v2 negando QA; P0002 -> 500 em ids inexistentes; account-media 422 em vez de 403; 4 goldens platform_users (C1).
- B-APOIO: B′ (apoio ao B): HEAD 1d84bc4fb; 11 commits. AP-1 fixture (pgTAP 22/22) executada pelo B em producao (lote 80). AP-2 (membership guardian, pgTAP 16/16) NAO aplicado: now_permission_denied mesmo com membership (has_context_permission so via role_assignments/overrides) -> OQ-048. Zero escritas em producao. Achados R16: drift de ACL do espelho + receita restaurar-espelho.sh; catalogo pos-baseline; pt409_props com ACLs reais; mapa de ACTIVITY_INVALID_REFERENCE (taxonomia 'outros' recusada; set_groups_v2 exige activity_unit_links). Espelho parado; worktree limpa.
- B: B: HEAD b20b202fe. Lotes 75 (PT409 em 126 RPCs), 79 (projecao can_remove), 80 (fixture QA R15; executada 18:10Z); Edge now-media. Certificados: child-safety.edit/suspend; agora.expire; agora.remove. agora.publish: FE verified/BE done, E2E bloqueado por contrato (now_actor exige permissao de equipe; responsavel 42501) -> OQ-048. Owner: r12-13/15/16 done; r12-05 partial (contexto Atividade selecionavel, chamada bcd47ba2 com activity_id, reload; falta negativa; participants [] no contexto Atividade); r12-04/06/08/33 nao iniciados (prazo). Massa QA R15 (E2): responsavel da915f98 ativa (auth ff3682a1), criancas 93457405/14d70a25, turma 368a5cea, guardian_links; atividade 1bd6bc74; story d9580375 (Familias); autorizacao 3f3650b0 suspensa. Defeitos FE corrigidos em Atividades (participantes em modo all; status active na criacao). Achados: ACTIVITY_INVALID_REFERENCE mapeado para "Confira a conexao" (mensagem desonesta); can_remove so autor vs RPC aceita admins; D5 cross-tenant por fixture sem senha da identidade. Incidente de sessao: instancia duplicada 09:00-09:06 sem efeito em producao; `supabase stop` acidental do project_id coelo_database.
- C1: C1: SHAs d27a829db,57ffe51e8,c0482aedd,6e9234c87,b1664470f,045fa8edc,a23d5be49,f59fd267a,78b2c98bd,1c199f14c. Lotes 76 (chat batch v2), 77 (for_you reader); Edge chat-media. Certificados: chat.attach; principal.for-you; principal.profile-edit; momentos.create/publish/view/remove. Owner done: r12-52, r12-01, r12-02. Goldens E4: 25 refs Principal; notice_directory nao (filtro Estado). Massa: conversa 7f54da12; aviso f7ae82a4; Sobre 1d442fc9; momentos 74c56d7c/7a5865ac; modelo atividade d28ed0a9. Sobras: notice goldens; UX duplo toque Momentos + "Curtido por Maria e outras 531" demo; diretorio Atividades Owner plataforma nao alcanca modelos institucionais; H02 aprovacao institucional sem contrato + update_official_data AAL2; testes router principal-context-selector ja falhavam na base.
- C2: C2: HEAD bb2efb09e. Lote 78 (aplicado pela coordenadora) provado na rota real: B5 (minimo por tipo, resultado minimizado sem CPF, selecao, autorizacao pendente relida, rate limit 422 PT422 na 31a, escopo vazio fora do ator); B6 (cadastro com CPF mascarado, dedupe pela tela e por RPC, documento ready pelo gateway em coelo-documents-prod, wizard na 3016 ate a revisao; envio final pela RPC com payload do wizard -> pendente b729f6b8; clique final pela tela nao concluiu — aba travou no CDP/SwiftShader); r12-38 (upload pelo gateway a partir do navegador em 3016, achado corrigido simpleImageMeta, previa apos reload, publicado revisao 8, model-edit sem regressao). Deltas: meal-plans.create/edit/publish/model-edit e child-safety.create/edit recertificados em ece99cc3a. Owner: r12-17 done, r12-38 done, r12-18 partial (clique final pela tela nao concluido; upload pelo navegador depende do CORS E13). Specs 061-069. Massa residual: authorized_people e9f02f4b + documento 9a01711e; autorizacoes pendentes B5/B6 (b729f6b8); cardapio 6272879e publicado com imagem 362777eb + orfaos 35dd7c74/2541d4b5 (imutavel apos publicar). Sobra R16: upload B6 pelo navegador com CORS; limpeza de ativos orfaos; provas por massa; specs 064-069; robustez do driver web.

## Git

- `dev` = `origin/dev` = `37d762976`; stash vazio; gate PASS DOCUMENTED_PARTIAL.
- Worktrees e branches: ver `R15-fechamento.md` e o manifesto de limpeza.
