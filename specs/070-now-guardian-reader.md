---
title: "Leitor do Agora para Famílias reconhece o responsável por vínculo (OQ-048)"
source: "decisions/0044-owner-decisions-mesa-r16-20260917.md (agora.publish executar na R16; oq048-membership); docs/open-questions.md OQ-048 e complementos de 17/09; R15-handoff-bloco-b.md AP-2; R15-apoio-bloco-b.md; decisions/0040-agora-immediate-removal.md; migrations 20260910190400_now_custom_role_audience_hardening_baseline e 20260917140000_now_feed_removal_projection_v1; dump de schema de produção de 17/09/2026 (schema-producao-20260917-r16-agora-before.sql, SHA-256 0c6c6468…): app_private.now_actor, app_private.now_viewer_role_class, app_private.has_context_permission, public.list_visible_now_publications, public.redeem_now_media_read_ticket"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Leitor do Agora para Famílias reconhece o responsável (`agora.publish`, OQ-048)

## Problema e decisão

Uma publicação do Agora com audiência **Famílias** (`families`/`guardians_only`) existe
para ser lida pelos responsáveis das crianças da instituição. Em produção (17/09/2026)
nenhum responsável "puro" consegue ler o feed: `list_visible_now_publications` passa por
`app_private.now_actor`, que exige `has_institution_permission(inst,'now.publications.read')`
e uma `institution_memberships` ativa **antes** de `now_viewer_role_class` — o classificador
que já responderia `guardian` a partir de `guardian_links` + `guardian_context_permissions`.
`now.publications.read` só existe em papéis de equipe; uma membership `guardian` também não
resolve. O Owner decidiu (ADR 0044) corrigir o **contrato**, sem override nem membership
sintética para a massa.

## Regra

O leitor do Agora reconhece dois tipos de ator, nesta ordem:

1. **Equipe** (inalterado): permissão institucional `now.publications.read` no contexto
   pedido e membership ativa; classe de leitor por `now_viewer_role_class` com a membership.
2. **Responsável**: quando o ator **não** tem a permissão institucional, o leitor tenta o
   caminho de responsável: `guardian_links` ativo (não revogado) para uma criança com
   `child_contexts` ativo na instituição pedida e `guardian_context_permissions` ativa com
   `can_view` (vigente por `starts_at`/`expires_at`). Se `p_unit_id`/`p_group_id` forem
   informados, a criança precisa de `child_unit_links`/`child_group_links` ativos nesse
   escopo (o mesmo predicado `guardian_context` de `now_viewer_role_class`). O ator é
   devolvido com `membership_id null` e classe `guardian`; **nenhuma membership é exigida
   nem criada**.

Invariantes preservados:

- **Isolação entre audiências**: a classe `guardian` casa só com `families`/`guardians_only`;
  equipe (`school_staff`) não vê Famílias e o responsável não vê publicações de equipe.
- **Cross-tenant negado**: responsável de outra instituição, ou sem vínculo na instituição
  pedida, recebe `42501 now_permission_denied`; unidade/turma fora da instituição recebem
  `42501 context_not_authorized` como hoje.
- **Escrita continua de equipe**: `app_private.now_actor` (criar, publicar, remover, mídia
  de autor) não muda; o responsável não ganha nenhuma capacidade de escrita e `can_remove`
  é sempre `false` para ele.
- **Mídia**: os tickets de leitura emitidos pelo feed são resgatados por
  `redeem_now_media_read_ticket` com a mesma classificação (`now_viewer_role_class` com a
  membership ativa quando existir, `null` para o responsável); o ticket continua único,
  vinculado ao visitante autenticado e revalidando audiência e vigência.
- **Vigência**: publicações expiradas, removidas ou agendadas para o futuro continuam
  fora do feed para qualquer classe de leitor.

## Contrato

- Função irmã privada `app_private.now_reader_actor(p_institution_id, p_permission,
  p_unit_id, p_group_id) returns table(person_id, membership_id)`: mesma validação de
  contexto de `now_actor`; caminho de equipe idêntico; caminho de responsável descrito acima;
  sem grant a `anon`/`authenticated`/`service_role`.
- `public.list_visible_now_publications(uuid,uuid,uuid,integer)`: assinatura, projeção
  (`management_version`, `can_remove`) e grants inalterados; passa a obter o ator por
  `now_reader_actor` com `'now.publications.read'` e segue classificando por
  `now_viewer_role_class`.
- `public.redeem_now_media_read_ticket(uuid,uuid)`: assinatura e grants (`service_role`)
  inalterados; deixa de exigir membership como junção obrigatória e resolve a membership
  ativa (quando houver) para o classificador.
- Sem versão otimista envolvida; nada a sinalizar com PT409.

## Fora de escopo

Contextos do Principal para responsável sem membership (`list_my_principal_contexts`,
shell do Superadmin — OQ-048, spec 064/Etapa 3); destinatários de cuidado que contam
membership `guardian` como equipe (`recipients-bug`, item próprio da R16); onboarding que
crie membership de responsável; leitura por aluno sem membership.

## Prova

- pgTAP `supabase/tests/now_guardian_reader_v1_test.sql` (espelho fiel de dump novo):
  responsável com vínculo vê a story de Famílias e o resgate do ticket funciona;
  sem vínculo, cross-tenant e unidade sem vínculo → `42501`; equipe não vê Famílias;
  expiradas/removidas ausentes; `now_actor` continua negando escrita ao responsável;
  suítes existentes do Agora sem regressão.
- Produção (lote 81): leitura por PostgREST com a sessão de `qa-r15-responsavel` devolve
  a story `d9580375…`; segunda chamada estável; outra instituição → `42501`; equipe
  (`qa-r06-principal`) → `[]` para Famílias.
