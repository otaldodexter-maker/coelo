---
source: "Sessão 7 da R14 (Opus 5), 16/09/2026; ADR 0040; ADR 0041 D5; r14-sessao-4/agora-remove-cross-tenant-blocked-20260915.md; briefing comum R14"
status: evidence
generated_at: 2026-09-16
action_id: "agora.remove"
---

# Agora › Remover (`agora.remove`) — avanço local do FE e bloqueio da rota produtiva, 16/09/2026

## Resultado

- **FE (local-green):** a rota normal de remoção imediata foi implementada no Agora hospedado
  (opção "Remover este Agora" na folha "Opções deste Agora", confirmação, estados de sucesso /
  negado / conflito / indisponível, releitura do feed após o recibo). 67/67 testes de
  `test/features/principal_now` verdes (6 novos de tela + 2 novos de repositório); `dart analyze`
  limpo. Não há prova na rota real: a opção depende de uma projeção do servidor que produção
  ainda não devolve (abaixo), então em produção a opção simplesmente não aparece (fail-closed).
- **BE (pending):** a negativa cross-tenant pela fixture QA (ADR 0041 D5) **não foi executada**.
- **E2E (pending):** sem tela produtiva e sem negativa produtiva.

## Por que a tela não pôde ser provada em produção

`public.remove_now_publication` exige `p_expected_version` não nulo (trava otimista) e a Edge
`now-media` (`action: remove`) valida `expected_version >= 1`; `list_visible_now_publications`
não projeta `management_version` nem qualquer sinal de autoria/capacidade, e `load_now_draft` só
devolve rascunhos. Logo nenhuma tela consegue chamar a remoção sem um contrato adicional. O
diagnóstico da coordenadora ("prova positiva integrada") vale para a prova por script
(`now-immediate-removal-production-proof.cjs`, Sessão E), não para uma tela: **não existia
consumidor de `agora.remove` em `apps/superadmin/lib`** antes desta sessão.

Candidato de backend preparado e provado no espelho da sessão (não aplicado em produção):

- Migration candidata `20260916155500_now_feed_removal_projection_v1.sql` — `drop/create` de
  `public.list_visible_now_publications(uuid,uuid,uuid,integer)` com o corpo vigente em produção
  (dump `schema-producao-20260916-r14-coord-before.sql`, SHA `f1f677ca…`) mais duas colunas de
  saída: `management_version bigint` e `can_remove boolean` (autor = ator **e**
  `app_private.has_institution_permission(institution,'now.publications.remove',unit,group,false)`,
  o mesmo predicado de `app_private.now_actor`). Grants preservados (`authenticated` execute;
  `public/anon` revogados). Preflight exige `remove_now_publication` e a permissão
  `now.publications.remove`. Sem direito novo: a autorização segue exclusivamente na RPC.
- O classificador de permissões desta sessão **recusou criar o arquivo** em
  `packages/coelo_database/migrations/` e também em `docs/reviews/evidence/.../candidatos/`
  ("Modify Shared Resources"); o texto integral ficou no scratchpad da sessão
  (`candidato-20260916155500_now_feed_removal_projection_v1.sql`) e é reproduzível a partir da
  definição vigente + o diff descrito acima. Bloqueio classificado: **ambiente (permissão da
  sessão)**, não decisão nem RPC.
- Espelho `coelo_mirror_r14_agora` (portas 618xx) restaurado do dump de 16/09 (schema-only) e
  semeado apenas com a pessoa `Coelo` (`c0e10000-…0001`, exigida pelo trigger de follow) e as
  quatro permissões `now.publications.*` (o dump de dados de produção também foi recusado pelo
  classificador). pgTAP no espelho, **antes → depois** do candidato (as falhas de baseline são
  ACL/grant do dump schema-only, idênticas nos dois lados):
  `now_publication_removal_test` 16/19 (9, 18) → 16/19 (9, 18);
  `now_publication_removal_cross_tenant_test` 6/6 → 6/6;
  `now_publication_mvp_test` 66/70 (18, 19, 38, 52) → 65/70 (+ **58**);
  `now_media_private_r2_v1_test` 20/23 (10, 16, 17) → 20/23;
  `now_publication_expiry_transition_test` 15/16 (10) → 15/16;
  `now_publication_expiry_dispatch_v1_test` 3/6 (2, 3, 4) → 3/6.
  A única regressão é o guard **58 "Agora feed exposes only its minimum presentation
  projection"**, que compara a assinatura de saída literalmente: o candidato amplia a projeção
  por desenho (ADR 0040 exige `expected_version` da tela), então aplicar o candidato implica
  atualizar esse guard no mesmo lote — decisão da coordenadora, não desta sessão.
- Verificação comportamental no espelho (fixtures do `now_publication_removal_cross_tenant_test`
  + papéis de leitura, em transação com `rollback`), 4/4: autor A vê `management_version 2` e
  `can_remove true`; ator B (tenant B) recebe `42501` sem vazamento; segundo membro de A sem a
  capacidade de remoção vê o item com `can_remove false`.

## Negativa cross-tenant (ADR 0041 D5) — não executada

O rito exige (a) uma migration mínima forward-only ou `supabase db query` para preparar a
fixture (`app_private.seed_qa_r14_chat_cross_tenant_user` só é chamável como `postgres`),
(b) um usuário Auth `qa-r14-chat-cross-tenant@coelo.me` com senha conhecida (a Sessão E o criou
pelo Auth Admin e revogou os vínculos; a senha não está em `Coelo-backups`), e (c) a revogação
ao fim pelo mesmo SQL (`r14-e-revoke-cross-tenant.sql`). Nesta sessão: criar migration foi
recusado pelo classificador; `supabase db query --linked/--project-ref` foi recusado
("Production Reads"); não há chave de serviço (e o briefing a proíbe). Bloqueio classificado:
**ambiente (permissões da sessão) + sessão (senha da identidade sintética não disponível)**.
A rota alternativa por PostgREST com identidade QA de outro tenant (`qa-r06-*` são todas
`platform`) não produz negativa cross-tenant real, então não foi usada como prova.

Além disso, a partir das 12:35 (BRT) o PostgREST de produção ficou sem responder (pool
esgotado, `PGRST003`) por mais de 40 minutos — ver `agora-20260916.md`, seção "Incidente" —, o que
também impediu a chamada positiva `now-media remove` sobre `a4e65c73…` (publicada pela tela).

## O que a R15 precisa para fechar `agora.remove` pela tela

1. Aplicar a projeção `management_version`/`can_remove` (candidato acima) pelo rito
   espelho → pgTAP → dump → `db push --dry-run` → push → ledger/ordem (lote novo).
2. Rebuild QA e repetir: publicar (audiência visível ao autor — ver observação de audiência em
   `agora-20260916.md`), abrir "Opções deste Agora" → "Remover este Agora" → confirmar → story
   some na hora → reload sem a publicação → recibo `status removed`, `purge_status purged`
   relido pela Edge/auditoria.
3. Negativa D5 com a fixture (migration mínima + revogação) ou uma identidade QA de escopo
   `institution` em outro tenant com credencial no cofre local.

## Separação FE / BE / E2E

- FE: local-green (código + testes; sem rota real).
- BE: sem mudança aplicada; contrato existente intacto.
- E2E: pending-verification (bloqueio ambiente/sessão registrado acima).
