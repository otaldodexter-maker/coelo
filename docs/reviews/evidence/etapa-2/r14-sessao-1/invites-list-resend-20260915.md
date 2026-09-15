---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md; owner.r12-44/45"
status: evidence
generated_at: 2026-09-15
---

# Convites › Lista (`invites.list`, owner.r12-44) e Convite › Reenviar (`invites.resend`, owner.r12-45) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `b5ebd527a`, 127.0.0.1:3014,
CDP 9414, sessão `qa-r06-publicacoes` na tela; RPCs de apoio com `qa-r06-acessos`). Não havia convite expirado em
produção (só dois revogados, inelegíveis) e a tela emite só com 48/72 h; por isso o convite `f1eb1cf7-a17e-41ae-b8e6-761fd5ccd2ed`
foi **emitido por RPC autorizada com o sintético** (`superadmin_invite_issue_v2`, instituição QA R04 Instituicao
Sintetica, perfil "Leitura", pessoa "QA R04 Profissional", canal `link`, `p_expires_in_hours=1` — mínimo do
backend) às 13:39 UTC e venceu naturalmente às 14:39 UTC. Nenhum SMTP/Admin API envolvido. O token do link nunca
foi gravado: a captura do diálogo está mascarada. Capturas em `capturas/invites-list-*.png` e `capturas/invites-resend-*.png`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| invites.list | `/invites`: diretório **tabela-only** (sem toggle de cards) com Destinatário / Contexto / Canais / Status / Criado em / Expira em / Ações, busca, filtros Status (Pendente/Aceito/Expirado/Revogado) e Canal, "Novo convite", paginação 8 por página (list-01). Filtro "Pendente" aplicado → só o convite `f1eb1cf7` (list-02); "Limpar filtros". | leitura: `superadmin_invite_directory_v2` (`p_statuses`), `superadmin_invite_options_v2`. | Carga completa relê a tabela (list-03); às 14:40 UTC o mesmo convite aparece como **Expirado** (resend-01). | `superadmin_invite_directory_v2`/`_detail_v2` só respondem a Owner com `platform.invites.manage`; RLS/pgTAP já certificados no BE. |
| invites.resend | Menu "⋯" da linha expirada oferece "Ver detalhes" e **"Reenviar convite"** (só para expirado/pendente vencido) (resend-02) → um clique → diálogo "Novo link do convite" com o link de uso único e "Copiar link" (resend-03, link mascarado) → "Fechar". | `superadmin_invite_resend_v2` pela tela: `management_version 1 → 2`, novo token, `expires_at 2026-09-17T14:41Z` (+48 h) relidos por `superadmin_invite_detail_v2`. | Carga completa relê **Pendente** com "Expira em 17/09/2026 · 14:41" (resend-04). | Novo reenvio do mesmo convite (agora pendente vigente) → `SAI_INVALID_ARGUMENT`; reenvio de convite **revogado** (`03e9c9d2`) → `SAI_INVALID_ARGUMENT`; reenvio com `p_expected_version` obsoleta (1) → `SAI_CONCURRENT_CHANGE`. O link só é devolvido na primeira chamada (uso único, contrato v2). |

Observações: nenhum defeito de código; nenhum teste alterado. O convite `f1eb1cf7` permanece em produção como massa
sintética (pendente até 17/09). Convites › Lista + Reenviar fecha a família (5/5) e conclui o Bloco A.
