---
title: "Perfis de cuidado — coleções redesenhadas (ADR 0041 §5, owner.r12-29/30)"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md (A2, §5); R15-pendencias.md (owner.r12-29, owner.r12-30); docs/reviews/evidence/etapa-2/r14-sessao-2/block-d-20260915.md; specs/020-superadmin-health-care.md; specs/049-superadmin-internal-care-profile-crud-v2.md; dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.health_care_profiles, public.health_care_allergies, public.health_care_profile_items (catalog_item_id + other_text), public.superadmin_health_care_save_profile"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Perfis de cuidado — coleções redesenhadas

Spec **sem prova** (ADR 0041 A2/§5). A base já em produção (coleção
independente de alergias e orientações, IDs próprios, limite defensivo de 100
por coleção, pgTAP 6/6 — Sessão D, 15/09) é preservada; esta spec descreve o
contrato novo do Owner para fechar `r12-29` e `r12-30`.

## Comportamento aprovado (§5)

1. Coleções nascem **vazias**; "+ Adicionar restrição" (e equivalentes
   "+ Adicionar alimento", "+ Adicionar orientação") cria **uma linha por vez**.
2. O wizard separa **Alimentos** de **Restrições**: o tipo vem do passo do
   wizard e é gravado (`allergy_type` = `food` | `restriction`); não há campo
   de tipo redundante na linha.
3. Cada registro tem **nome** escolhido de **lista pré-definida categorizada**
   (ex.: Frutas › Banana, Maçã; Bebidas › Leite), seleção única, com busca e
   opção **"Outro"** (texto livre obrigatório).
4. Registros são **reordenáveis** (arrastar/mover) e a ordem persiste.
5. Antes de Observações, campo **"O que fazer se consumido?"** (alimentos) /
   "O que fazer se exposto?" (restrições).
6. Limite de **100** por coleção mantido no backend (rejeição do 101º).

## Modelo de dados (forward-only, esboço)

- `public.health_care_catalog_items` (nova, catálogo read-only versionado):
  `id text` (slug), `collection` (`food` | `restriction` | `guidance`),
  `category_code`, `category_label`, `label`, `search_terms text[]`,
  `sort_order`, `status`. Carga inicial: ~100 alimentos mais comuns em
  alergia infantil, 50 intermediários, 50 menos comuns; o mesmo para
  restrições e orientações (listas ajustáveis por migration de catálogo).
- `public.health_care_allergies` ganha `catalog_item_id text` (FK lógica ao
  catálogo ou `'other'`), `other_text` (obrigatório só com `other`),
  `position int`, `what_to_do text` ("o que fazer se consumido/exposto").
  `label` passa a ser derivado do catálogo (ou do `other_text`) na gravação.
- Orientações reutilizam `health_care_profile_items` (já tem
  `catalog_item_id` + `other_text`) com `position` novo.

## RPCs (esboço)

- `superadmin_health_care_catalog_v1(p_collection, p_search)` → categorias e
  itens (busca ≥ 2 caracteres, resultado ≤ 50, sem PII).
- `superadmin_health_care_save_profile` (v2 forward-only): payload por
  coleção com lista ordenada `[{id?, catalog_item_id, other_text?,
  what_to_do?, notes?}]`; valida catálogo, `other_text` com `other`, limite
  100, ordem única; versão otimista (PT409); auditoria before/after
  minimizada (sem texto livre de saúde no `after_json`, só contagens e IDs).

## Frontend

Wizard do Perfil de cuidado com passos Alimentos → Restrições → Orientações
→ Observações; cada passo com lista vazia inicial, botão "+ Adicionar", campo
de busca no catálogo com categorias, "Outro", reordenação por arrastar e
mover, campo "O que fazer se consumido?" antes de Observações. Detalhe mostra
as coleções na ordem persistida.

## Aceite (futuro recorte)

pgTAP: catálogo read-only, `other` exige texto, ordem persiste, 101º rejeitado,
versão defasada PT409; FE: testes do wizard (adicionar/remover/reordenar,
busca, Outro); rota real (`qa-r06-operacoes`): perfil com ≥ 3 alimentos, ≥ 2
restrições e ≥ 2 orientações, reordenar, salvar, reload, e aceite do Owner
"com mais registros" → `r12-29`/`r12-30` done.
