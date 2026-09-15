---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md"
status: evidence
generated_at: 2026-09-15
---

# Shell › Troca de contexto (`shell.switch-context`, flutter-only) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `821e18b11`, 127.0.0.1:3014,
CDP 9414, sessão `qa-r06-publicacoes`, Owner). `list_my_principal_contexts` devolve dois contextos reais para o
usuário: A = "QA R04 Cuidado (sintetico)" (`@qa-r04-cuidado-sintetico`, `d0c40000…0001`) e B = "QA R04 Instituicao
Sintetica" (`@qa-r04-chat`, `9f040000…0010`). Capturas em `capturas/shell-switch-context-*.png`.

| action_id | Rota normal (FE) | Dado residual | Reload | BE/E2E |
|---|---|---|---|---|
| shell.switch-context | `/principal-happens` no contexto A mostra o post `ce6426cd` (01). Avatar do cabeçalho → menu "Abrir perfil / Ver como" → sheet "Ver como" lista A (marcado) e B com handles (02). Desmarcar A, marcar B, "Aplicar" → o feed é remontado com novo carregamento e mostra "Nenhuma publicação neste contexto" (03). | Nenhum item de A permanece em B; `list_visible_happens_feed` de B por RPC devolve `[]` (o post pertence a A). | Carga completa volta ao contexto A com o post (04): a seleção "Ver como" é preferência em memória, não persiste — comportamento já documentado (`Principal-pos-R10.md`), não é regressão. | Não aplicável (`flutter-only`; a autorização não muda com a seleção — o servidor filtra por `p_institution_id` do contexto escolhido). |

Observações: nenhum defeito de código; nenhum teste alterado. Após a troca, o cabeçalho do Principal não exibe qual
contexto está ativo (o chip `principal-context-selector` não aparece nesta composição do feed) — é lacuna de UX,
não de autorização; fica registrada como sobra para decisão de design, sem alteração por inferência.
