---
source: "Sessão A da R15 (Fable 5.1), 17/09/2026; R15-pendencias.md (ordem 2); ADR 0041 A4; modelo r14-sessao-1/units-error-access-denied-20260915.md"
status: evidence
generated_at: 2026-09-17
---

# Instituições › Erro (`institutions.error`) e Instituições › Acesso negado (`institutions.access-denied`) — rota real, 17/09/2026

Mesmo ambiente de `access-profiles-edit-assign-20260917.md` (produção, build QA de `r15/bloco-a` em
`900608be9`, `127.0.0.1:3014`, CDP 9414, tema claro), sessão `qa-r06-estrutura@coelo.me` (Owner de
plataforma). Os dois são estados de `/institutions/:id/edit` (`InstitutionFormPage`). Capturas em
`capturas/institutions-*.png`.

| action_id | Rota normal | Backend em produção | Reload | Negativa |
|---|---|---|---|---|
| institutions.access-denied | `/institutions/00000000-0000-4000-8000-000000000000/edit` (uuid inexistente, deep link) → painel "Acesso não autorizado · Você não tem permissão para acessar esta instituição." com "Voltar às instituições" e **nenhum dado** renderizado (00, tema escuro da sessão nova). | `superadmin_institution_detail_v2` devolve `{ok:false, error:{code SAI_PERMISSION_DENIED, http_status 403, "Acesso não autorizado."}}` para o uuid inexistente e para o id sintético `d0c40000-…0099` — inexistente e fora de escopo recebem a mesma negativa, sem enumeração; o id real `d0c40000-…0001` devolve `ok:true` com os dados da instituição. | Carga completa da mesma URL mantém "Acesso não autorizado" sem dado (01, tema claro). "Voltar às instituições" leva ao diretório (02: 4 cards). | É a própria negativa real. Negativa por tenant só existe no pgTAP: todas as identidades `qa-r06-*` têm escopo `platform`. |
| institutions.error | Com a RPC `superadmin_institution_detail_v2` bloqueada por CDP (`Network.setBlockedURLs`, `cdp_block.dart`, 75 s), abrir "QA R04 Cuidado (sintetico)" pelo diretório → `/institutions/d0c40000-…0001/edit` mostra "Não foi possível carregar · Verifique sua conexão e tente novamente." com "Tentar novamente" e sem dado residual (03). | Falha de transporte → estado `unavailable` do formulário; nenhum envelope malformado é tratado como autorizado. | Após o desbloqueio, "Tentar novamente" recarrega e mostra o formulário real ("Identidade visual" de QA R04 Cuidado (sintetico), `@qa-r04-cuidado-sintetico`, cores) (05). | A negação do servidor (403) continua sendo `unauthorized`, não `unavailable` — os dois painéis não se confundem (00 × 03). |

## ADR 0041 A4 — flyout "Arquivos"

No diretório `/institutions`, o botão "Arquivos" abre o flyout com Importar / Exportar CSV / Exportar XLSX
(04); qualquer item mostra o aviso "Arquivos em desenvolvimento: importar e exportar instituições chegam
depois do MVP." (06). Nenhum arquivo é gerado ou enviado.

## Observações

- Nenhum defeito de código; nenhum teste alterado; nenhuma escrita em produção (somente leituras).
- O diretório demora alguns segundos para carregar após navegação (spinner em 1424×1125); o clique em
  itens do flyout precisa esperar a animação de abertura.
- Não há navegação interna para o estado negado (o diretório só lista instituições visíveis); o estado é
  alcançado por deep link — registrado, sem alteração por inferência.
