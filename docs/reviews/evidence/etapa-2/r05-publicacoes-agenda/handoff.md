---
title: "Handoff R05 — publicacoes-agenda (Agenda, Avisos, Circulares)"
source: "comunicacao/publicacoes-agenda.json rev 31–36; branch work/etapa2-r05-publicacoes-agenda; prova-producao-r05.js; capturas ui/"
status: "entrega da frente ao coordenador; nada aqui certifica producao"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# O que fechou (por action_id, com prova)

| action_id | Camada | Prova |
| --- | --- | --- |
| `agenda.view` | FE (P33 aplicado) | `5edfccef9`: calendário conforme referência iOS; goldens `agenda_calendar_*`, `agenda_list_*`, `agenda_http_calendar_*` regravados no 3.44.2; rota real `ui-02` com dados de produção (hoje em círculo, cancelados hachurados, Hoje no rodapé). Aprovação do Owner pendente: `duvidas-visuais.html`. |
| `agenda.detail` | FE (P34 aplicado) | `16651dc88`: rodapé `SuperadminFormActionFooter` (igual a Instituição), destrutivo à esquerda, Editar à direita; goldens `agenda_detail_*` regravados. `2a982a453` corrige 2 testes pré-existentes (`agenda_remote_states_test`). |
| `agenda.request` | FE + BE + E2E | BE: prova RPC (rascunho → `request_publication` → lista pending → aprovar → evento published → reload). FE: `ui-05..ui-08` (/agenda/approvals com pedido real, Decidir → motivo → Aprovar pela tela, recarga completa mantém). Candidato `20260911190100` (rótulos) 7/7. |
| `agenda.location` | BE | prova RPC: evento com `contextKind: unit` + local persiste e reload mantém (QA R04 Cuidado, unidade d0c4…0002); pgTAP 200300 nega unidade fora do tenant. |
| `agenda.permissions` | FE | rota `/agenda/permissions` redireciona por design para Perfis e permissões (`dde3e6229`); `superadmin_agenda_contexts` lista instituições/unidades/turmas em produção. |
| `notices.schedule` | FE + E2E | `ui-13..ui-19`: data/hora pelo seletor Coelo (18/09 13:51), Publicar → "Publicação agendada", diretório após recarga completa mostra "Desde 18/09/2026"; RPC confirma `scheduled`. Worker real: aviso agendado para +2 min virou `active` com `reach 18` (P30 materializa sozinho). |
| `circulars.respond` | BE | `20260911190000` em produção: `save_circular_response_draft` → `submit_circular_response` → `response_summary_v2` `{response_count:1, submitted_count:1}`; pgTAP 18/18 com negativas (sem membership, cross-tenant, anon). |
| `circulars.attach` | BE (parcial) | prepare → PUT → finalize(ready) → read(signed_url) → bytes conferem → anon 401. **Ainda no bucket legado do Supabase** e o gateway v2 bloqueia o bloco de mídia: pacotes `20260911190200` e `20260911190300` verdes, aguardando aplicação. |
| `circulars.edit` / `circulars.schedule` | BE (reforço) | RPC: edição com versão, agendar (publish_at futuro) e reload. FE pela tela não exercido (Chrome morreu por memória). |

# Pacotes SQL (candidatos/publicacoes-agenda, aplicar nesta ordem)

1. `20260911190000_circular_actor_internal_bridge_v1` — **já em produção** (confirmado pela prova).
2. `20260911190100_agenda_requests_labels_v1` — pgTAP 7/7.
3. `20260911190200_circulars_media_private_r2_v1_reapply` — 45/46 (46º exige linha do bucket legado em `storage.buckets`).
4. `20260911190300_superadmin_circulars_v2_media_v1` — bridge 18/18, v2 34/34, delete 15/15.

Prova limpa no descartável `coelo_pa_r05` (db 60522): baseline + seed + 107 migrations da ordem + 9 lotes de hoje + candidatos.

# Aberto, com o primeiro gate

- `circulars.attach` FE/E2E: aplicar 190200/190300 e anexar pela tela (composer real) com um Chrome.
- `circulars.edit`, `circulars.schedule` FE: editar rascunho explícito e acionar o picker pela tela (o seletor Coelo responde à semântica — provado em Avisos).
- `circulars.respond` FE: não existe tela de resposta no Superadmin (fluxo do Principal); decidir se `respond` no Superadmin é só o resumo (já verified) — pergunta ao coordenador.
- `agenda.location` FE: criar evento com contexto de unidade pelo wizard na tela.
- Aprovação visual do Owner: P33/P34 em `duvidas-visuais.html` (R iPhone / A atual; detalhe: manter 48 px?).
- Delete do anexo por RPC após publicar responde `media_remove_denied` — comportamento correto (mídia publicada é imutável); o script de prova deve excluir antes de publicar.

# Achados fora do recorte

- Pastilha "Aviso" da coluna Tipo esticada no diretório de Avisos após o composto `11c4bfbef` (ui-19) — coelo-ui/composto.
- Balão de chat sobre o compositor de Circular enquanto carrega o seletor de instituição (ui-22) — shell/Decisão 7.
- `agenda_internal_realm_compat_v1_test` falha 4/22 sobre a ordem real após o lote 29 (ponte do Principal): expectativas antigas de ator interno sem pessoa; falta asserção cross-tenant — G4/G5.
- Testes históricos `circulars_authorization_behavior_test` (fixture inválida) — pós-MVP.

# Dados sintéticos deixados em produção

`[R05-QA …]` avisos (2: um agendado 18/09 pela tela, um materializado pelo worker), eventos cancelados/aprovados na Agenda das instituições sintéticas, circulares excluídas (soft) com anexos `pixel.png` (70 bytes) no bucket legado. Limpeza no fim da Etapa 2 (P25/P42).
