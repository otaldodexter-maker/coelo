---
title: "Avisos — duplicar (H08), destino do CTA de Comunicação (H13) e atualização sem sumir a lista (H23)"
source: "decisions/0038-owner-decisions-etapa2-backlog-20260914.md (H08 A, H13 B, H23 A); R15-pendencias.md (resíduos H08/H13/H23); docs/reviews/etapa-2-operacao/next-round/R07-varredura-r01-r07.md; docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md (ciclo de vida; duplicar cria rascunho); dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.platform_notices (cta_label, cta_url, audience_json, recurrence…), superadmin_notice_save_draft_v2/publish_v2/change_status_v2/detail_v2/directory_v2; apps/superadmin PlatformNotice (sem URL no cliente)"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Avisos: duplicar, destino do CTA e atualização contínua

Spec **sem prova**, fixando os contratos que a R14 não podia inventar
(H08/H13 sem `action_id` e sem contrato produtivo; H23 dependente deles).

## H08 — Duplicar aviso (ADR 0038: opção A, no MVP)

- Ação "Duplicar" no ⋯ do diretório e no detalhe, **em qualquer status**
  (inclusive `expired`/`inactive`).
- RPC `superadmin_notice_duplicate_v2(p_request_id, p_notice_id)` no contexto
  interno (`notice.publish`; AAL2 como nas demais escritas): cria **rascunho**
  com título `Cópia de <título>` (truncado a 120), `body_text`, `notice_type`,
  `priority_code`, `behavior`, `target_device`, `content_format`, cores,
  `popup_size`, `has_outer_inset`, `recurrence`/`recurrence_config`,
  `image_orientation`, `audience_json`/`audience_label` e CTA copiados;
  **sem** `starts_at`/`ends_at`, sem recibos de audiência, `management_version=1`,
  `status='draft'`. Auditoria `superadmin.notices.duplicate` com
  `object_id` = novo e `after_json.source_notice_id` = origem. Recibo
  idempotente por `p_request_id`; envelope `{ok,data,error}` v2.
- FE: após duplicar, abre o rascunho em edição; `action_id` novo
  `notices.duplicate` (família `notices`, escopo MVP) a registrar no inventário
  pelo recorte que implementar.

## H13 — Destino do CTA de Comunicação (ADR 0038: opção B)

- `PlatformNotice` (Principal/Superadmin) ganha **destino por tipo**, nunca URL
  livre: `cta_target = {kind: 'circular'|'invite'|'form'|'notice'|'none',
  id: uuid?}`. O backend valida que o alvo existe e pertence ao escopo da
  audiência; `cta_url` continua reservado a link **externo** apenas quando
  `kind='external'`, permitido só para Owner e exibido com aviso de saída.
- Projeção: `superadmin_notice_detail_v2`/`directory_v2` e o leitor do
  Principal expõem `cta_target`; o cliente resolve a rota interna
  (circular → leitura da circular; convite → convite; formulário →
  resposta; aviso → detalhe) e, sem alvo, mostra o rótulo desabilitado com
  mensagem honesta (comportamento atual).
- Migration: coluna `cta_target_kind`/`cta_target_id` em `platform_notices`
  + check; `save_draft_v2` aceita e valida; `action_id` `notices.cta` (a
  registrar) para a prova no Principal hospedado.

## H23 — Atualização sem sumir a lista (ADR 0038: opção A, padrão para todos)

- Refresh do diretório de Avisos mantém a **lista visível** e mostra uma
  **barra fina de progresso** no topo; erros aparecem como banner sobre a
  lista, sem trocar por estado vazio. Vira padrão `coelo-ui`
  (`CoeloAdminRefreshingList`/equivalente) aplicado a todos os
  diretórios/listas do Superadmin.
- Sem contrato de backend; depende só do compositor (E4/goldens regravados
  suíte a suíte quando o diff for do cabeçalho).

## Aceite (futuro recorte)

pgTAP: duplicar copia os campos listados, zera datas/recibos, funciona em
status terminal, cross-scope negado, idempotente; CTA com alvo inexistente ou
de outro escopo é rejeitado; FE: ação Duplicar → rascunho aberto; CTA navega
por tipo; refresh sem sumir a lista (teste de widget); rota real: duplicar
aviso publicado, editar e publicar a cópia; CTA de circular no Principal
hospedado abre a circular.
