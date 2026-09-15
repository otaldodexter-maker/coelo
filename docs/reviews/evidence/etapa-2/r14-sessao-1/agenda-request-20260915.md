---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md; owner.r12-42"
status: evidence
generated_at: 2026-09-15
---

# Agenda › Solicitar / Aprovações de publicação (`agenda.request`, owner.r12-42) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab`, 127.0.0.1:3014,
CDP 9414, sessão `qa-r06-publicacoes`, Owner). Instituição do contexto: `QA R04 Instituicao Sintetica`
(`9f040000-…0010`). Como o Owner vê "Publicar evento" (nunca "Solicitar publicação"), o pedido pendente
foi criado por RPC autorizada com o mesmo sintético (`superadmin_agenda_command` `request_publication`),
como na prova R05. Capturas em `capturas/agenda-request-*.png`.

## Defeito encontrado e corrigido (teste vermelho → verde)

Na decisão pela tela, a linha era substituída pelo retorno de `superadmin_agenda_decide_publication`,
que não traz `title`/`institution_name`/`requested_by_name`/`decided_by_name`: até o reload a tabela
mostrava `Evento 19bc0e94…`, `9f040000…`, `92b97c39…` (captura 03, build anterior). Além disso a página
passa `decidedBy: 'Marina Oliveira'` fixo ao repositório. Correção mínima em
`supabase_agenda_repository.dart` (`decidePublicationRequest`): a linha carregada preserva os rótulos
(`existing.decided(...)`) e, após a decisão, `loadRequests()` relê do servidor (fonte dos rótulos de
decisão). Teste novo em `supabase_agenda_repository_test.dart` ("decisão preserva rótulos da linha
carregada quando a RPC devolve só ids") — vermelho antes (`Actual: Evento 300…`), suíte 55/55 depois;
`agenda_approvals_page_test` 6/6; `flutter analyze` limpo. Reprova no build corrigido: captura 05
(sem reload) já mostra "Novo evento · QA R04 Instituicao Sintetica · Operador interno db9ebfa5 · Recusado".

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| agenda.request | `/agenda/events/new` → título/descrição → "Salvar rascunho" (evento `19bc0e94`, rev 1). `/agenda/approvals`: tabela canônica 64 px com o pedido "Aguardando publicação / Aguardando decisão / Decidir" (captura 01); "Decidir" abre diálogo, aprovar sem justificativa → "Informe a justificativa da decisão." (02b); com justificativa → "Aprovar publicação" (02). Segundo ciclo no build corrigido: evento `19fc875d` → pedido `98b763e0` → "Recusar publicação" (05); "Ver histórico" mostra decisão, decisor real e justificativa (06). | `superadmin_agenda_save` (2 rascunhos), `superadmin_agenda_command request_publication` (pedidos `b82f6714`, `98b763e0`), `superadmin_agenda_decide_publication` pela tela: `b82f6714 approved` ("Aprovado pela Sessao 1 da R14 na rota real"), `98b763e0 rejected` ("Recusado pela Sessao 1 … rotulos"), `decided_by_name = Operador interno db9ebfa5` relidos por `superadmin_agenda_requests`. | Reload de `/agenda/approvals` relê Aprovado (04) e Recusado (07) com rótulos. | `superadmin_agenda_decide_publication` com pedido inexistente → `400 22023 publication_request_not_pending` (não enumerável); `superadmin_agenda_list` com instituição alheia → `items: []`; RLS por pgTAP `agenda_requests_labels_v1` 7/7 e 200300 (22 negativas), já certificados no BE. |

Observações: o golden "calendário loading dark 375" citado em r12-42 continua fora deste recorte (não é
`agenda.request`). O nome fixo `'Marina Oliveira'` na página permanece como argumento ignorado pelo
repositório Supabase; não é exibido em produção após esta correção (rótulos vêm do servidor).
