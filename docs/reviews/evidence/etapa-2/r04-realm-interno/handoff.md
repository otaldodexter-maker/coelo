---
title: "Handoff — grupo realm-interno, Rodada 4 (E2-R04-20260911)"
grupo: "realm-interno"
branch: "work/etapa2-r04-realm-interno"
source: "comunicacao/realm-interno.json (revisoes 1-4); candidatos/realm-interno/README.md"
generated_at: "2026-09-10"
---

# Handoff — realm-interno (backend do chat interno v2)

## Recorte

Etapa 2 → apps/superadmin → menu Comunicação e menu Coelo (Principal) → Chat →
family `chat` (chat.list, chat.open, chat.send, chat.edit, chat.receipts,
chat.revoke; chat.attach fora, depende do gateway de mídia comum) e Criar grupo
(P8, ADR 0034 Decisão 12). Só backend; o cliente é do grupo
principal-chat-sistema.

## Medição de produção (somente leitura, 21:45)

O realm interno v2 já existe em produção (identidades, vínculos, memberships,
`require_superadmin_internal_context` sem gate de AAL2, auditoria com 13
argumentos). O chat contextual existe (tabelas e policies com
`can_access_conversation`). **Nada do chat interno v2 existe**: nenhuma das dez
RPCs `superadmin_chat_*_v2` que `SupabaseChatRepository` chama, nenhuma
permissão `chat.internal.*`, nenhuma coluna de autor interno em `messages`.
`chat_production_contract` também está ausente. Produção tem 0 instituições,
1 pessoa, 0 conversas.

## Entregue (pgTAP verde, prova integral do zero 111/111)

Cinco pacotes em `packages/coelo_database/candidatos/realm-interno/`, na ordem
`240000 → 240100 → 240200 → 240300 → 240400`, cada um com preflight de presença
de objeto (ver README da pasta). Todos reescritos do histórico para a forma
canônica de produção: labels NOT NULL nas permissões, `requires_mfa=false`,
auditoria com 13 argumentos, revoke explícito de PUBLIC/anon/authenticated/
service_role antes do grant mínimo, negativa cross-tenant por `CHAT_NOT_FOUND`.

O contrato (assinaturas, envelope, códigos, capacidades) está em
`comunicacao/realm-interno.json` → `contrato`. As dez RPCs não mudam de
assinatura em relação ao cliente atual; Criar grupo é
`superadmin_chat_create_group_v2` + `superadmin_chat_group_members_v2`.

## Achados

1. `anon` tinha `GRANT ALL` em `conversations`, `messages`, `message_edits` e
   `message_receipts` na baseline de produção (RLS barrava). Revogado no 240000.
2. `supabase db reset` com todas as `migrations/` falha em
   `20260910170100` (exige o catálogo antes do seed). O fluxo que reproduz
   produção é baseline-only + seed + `psql` das demais (README).
3. As três suítes históricas do chat (`*_chat_v2_test`, `*_receipts_edit_revoke_test`,
   `*_preferences_test`) não valem sobre a baseline; as `*_baseline_test.sql`
   as substituem. Arquivar as antigas é decisão do coordenador.

## Produção (lote 9, 22:25) e prova (22:32)

Os cinco pacotes foram aplicados pelo coordenador e provados com a sessão
`qa-r03@coelo.me` por PostgREST: 18 PASS / 0 FAIL, persistência conferida no
banco, limpeza feita (a instituição sintética ficou arquivada por FK da
auditoria). Detalhes em `prova-producao-2026-09-10.md`. Delta proposto:
`deltas-be-r04.json` (seis IDs → backend `done`, com certificação).

## Aberto e primeiro gate

| Item | Primeiro gate |
| --- | --- |
| chat.* E2E | grupo principal-chat-sistema ligar `SupabaseChatRepository` na composição e provar na rota normal |
| Criar grupo (P8) | criar `chat.create-group` no inventário; UI do grupo principal-chat-sistema; P24 (só identidades internas no MVP?) com o Owner, não bloqueia o backend entregue |
| chat.attach | gateway de mídia comum (fora do recorte) |
| escopo `activity` de Criar grupo | validado por código e trigger; sem pgTAP (fixture de atividades complexa); revisão profunda |
| Realtime | nenhuma publication configurada; o cliente não assina hoje |

## Delta proposto

`docs/reviews/evidence/etapa-2/r04-realm-interno/deltas-be-r04.json`: seis
IDs da família chat para backend `local-green` com pacote pronto. `done` só
depois da aplicação e da prova em produção.
