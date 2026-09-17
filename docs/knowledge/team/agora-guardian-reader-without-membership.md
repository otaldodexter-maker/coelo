---
title: O leitor do Agora para Famílias reconhece o responsável por vínculo, sem membership
knowledge_id: agora-guardian-reader-without-membership
source: specs/070-now-guardian-reader.md
status: validated
lifecycle: "current"
generated_at: 2026-09-17
updated_at: 2026-09-17
audience: team
surfaces: [supabase, database, principal, agora, review]
visibility: internal
review_owner: Coelo Owner
---

# O leitor do Agora para Famílias reconhece o responsável por vínculo

Regra durável decidida pelo Owner na Mesa R16 (17/09/2026, ADR 0044, item
`agora.publish`; OQ-048) e aplicada em produção no lote 81
(`20260917203000_now_guardian_reader_v1`, spec 070): **um responsável lê o
Agora com audiência Famílias por ter `guardian_links` ativo com uma criança
que tem `child_contexts` ativo na instituição e `guardian_context_permissions`
vigente com `can_view` — sem precisar de `institution_memberships`**. Antes do
lote, `app_private.now_actor` exigia permissão institucional
(`now.publications.read`) e membership ativa antes de classificar o ator, o que
tornava o feed de Famílias inacessível a qualquer responsável real.

## Como o contrato ficou

- `app_private.now_reader_actor(institution, permission, unit, group)` é a
  função irmã de `now_actor` **só para leitura**: primeiro tenta o caminho de
  equipe (permissão + membership, como antes); sem permissão institucional,
  tenta o caminho de responsável pelo mesmo predicado de
  `now_viewer_role_class` e devolve `membership_id null` com classe `guardian`.
  Sem grant a `anon`/`authenticated`/`service_role`.
- `public.list_visible_now_publications` usa `now_reader_actor`; assinatura,
  projeção (`management_version`, `can_remove`) e grants não mudaram.
  `public.redeem_now_media_read_ticket` deixa de exigir membership como junção
  obrigatória (resolve a membership ativa quando existir; nula para o
  responsável). Tickets continuam únicos e vinculados ao visitante.
- `app_private.now_actor` (criar, publicar, remover, mídia de autor) **não**
  mudou: escrita continua exclusiva de equipe; `can_remove` é sempre `false`
  para o responsável.

## Invariantes que a prova cobre

- Isolação entre audiências: equipe não vê Famílias; responsável não vê
  publicações de equipe (`qa-r06-principal` → `[]`).
- Cross-tenant negado: responsável sem vínculo na instituição pedida, ou de
  outra instituição, recebe `42501 now_permission_denied`; unidade/turma fora
  da instituição → `42501 context_not_authorized`.
- Publicações expiradas, removidas ou agendadas continuam fora do feed para
  qualquer classe de leitor.
- Nenhuma membership, override ou fixture é criada para a massa de teste: a
  correção é de contrato, não de dados (o candidato
  `20260917113000_qa_r15_guardian_membership_v1` fica versionado e não aplicado).

## O que continua aberto (fila R16 / Etapa 3)

- O Principal ainda não abre para uma conta só de responsável
  (`list_my_principal_contexts` exige membership; shell do Superadmin só admite
  identidade interna) — OQ-048, spec 064 / Etapa 3. Provas de responsável em
  produção usam PostgREST com a sessão dele.
- `recipients-bug`: destinatários de cuidado contam qualquer membership como
  equipe; `can-remove`: feed só oferece remoção ao autor enquanto a RPC aceita
  administradores.
