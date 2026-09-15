---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md"
status: evidence
generated_at: 2026-09-15
---

# Chat › Criar grupo (`chat.create-group`) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `d5f8bbe70`, 127.0.0.1:3014,
CDP 9414, sessão `qa-r06-publicacoes`, Owner). FE já `verified` (R04); esta fatia certifica o E2E.
Capturas em `capturas/chat-create-group-*.png`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| chat.create-group | `/communication/conversations` › ícone "Criar grupo" › diálogo: nome "Grupo R14 Sessao 1", Instituição "QA R04 Cuidado (sintetico)" (lista real de instituições), pessoas reais com vínculo ativo (Crianca QA R04, operadores internos) → 2 selecionadas (01) → "Criar grupo" → notice `Grupo "Grupo R14 Sessao 1" criado com 2 membros.` e a conversa no topo da inbox (02). | `superadmin_chat_create_group_v2` → conversa `7f54da12-37d2-42dd-b412-4d40b3ebfd87` (`group`, `institution`, `d0c40000…0001`) relida por `superadmin_chat_inbox_v2` (`p_search "R14 Sessao"`). | Carga completa relê a inbox com o grupo (03). | `superadmin_chat_create_group_v2` com `p_institution_id` alheia (`…0099`) → `404 CHAT_NOT_FOUND` (não enumerável); pgTAP `superadmin_internal_chat_groups_v1` 19/19 e `cross_tenant` já certificados no BE. |

Observações: nenhum defeito de código; nenhum teste alterado. O grupo `7f54da12` fica em produção como massa
sintética identificada por prefixo "R14 Sessao 1".
