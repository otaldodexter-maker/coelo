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
| `circulars.attach` | BE | Lote 43 (190000+190200+190300) em produção: prepare presign em R2 `coelo-media-prod` (chave `tenants/…/circulars/circular/…/attachment/…/original`) → PUT → finalize ready → rascunho com bloco de mídia no gateway v2 → detail devolve asset_id → publish com mídia → read signed_url → bytes conferem; anon 401; anexo publicado imutável. Prova 34/34 (14:36). |
| `circulars.edit` | FE + BE + E2E | Rascunho criado pelo compositor real, reaberto pela aba Rascunhos → Editar circular → título editado → Salvar rascunho; recarga completa mantém (ui-32..ui-39). |
| `circulars.schedule` | FE + BE + E2E | `66a52986f` liga o seletor (host produtivo não passava `onChooseSchedule`). Pela tela: data 25/09 + horário → "Alterar agendamento" → validação honesta de público → Agendar circular → Agendada; recarga lista 25/09/2026 na aba Agendadas; RPC `scheduled` (ui-41..ui-46). |

# Pacotes SQL (candidatos/publicacoes-agenda, aplicar nesta ordem)

1. `20260911190000_circular_actor_internal_bridge_v1` — em produção (lote 42/43).
2. `20260911190100_agenda_requests_labels_v1` — pgTAP 7/7 — em produção (lote 43).
3. `20260911190200_circulars_media_private_r2_v1_reapply` — 45/46 — em produção (lote 43).
4. `20260911190300_superadmin_circulars_v2_media_v1` — bridge 18/18, v2 34/34, delete 15/15 — em produção (lote 43).

Deltas no formato do aplicador: `deltas-r05-pa.json` (16 entradas, ensaio apply + validate PASS: FE 76, BE 78, E2E 53).

Prova limpa no descartável `coelo_pa_r05` (db 60522): baseline + seed + 107 migrations da ordem + 9 lotes de hoje + candidatos.

# Aberto, com o primeiro gate

- `circulars.attach` FE/E2E: anexar pela tela (composer real, FilePicker nativo não é dirigível por CDP; injetar `filePicker` no host de QA) com um Chrome.
- `circulars.respond` FE: não existe tela de resposta no Superadmin (fluxo do Principal); decidir se `respond` no Superadmin é só o resumo (já verified) — pergunta ao coordenador.
- `agenda.location` FE: achado de produto no wizard (ui-51/52): "Contexto principal" só escolhe o nível e o formulário usa o primeiro contexto daquele nível (`_selectedContext`), sem seletor da unidade/turma concreta — propor seletor antes do verified.
- Aprovação visual do Owner: P33/P34 em `duvidas-visuais.html` (R iPhone / A atual; detalhe: manter 48 px?).
- Delete do anexo após publicar responde `media_remove_denied` — comportamento correto (mídia publicada é imutável); coberto na prova como negativa.

# Achados fora do recorte

- Pastilha "Aviso" esticada no diretório de Avisos após o composto `11c4bfbef` (ui-19) — corrigida em `28acbe8c3` (altura própria da pastilha).
- Balão de chat sobre o compositor de Circular enquanto carrega o seletor de instituição (ui-22) — shell/Decisão 7.
- `agenda_internal_realm_compat_v1_test` falha 4/22 sobre a ordem real após o lote 29 (ponte do Principal): expectativas antigas de ator interno sem pessoa; falta asserção cross-tenant — G4/G5.
- Testes históricos `circulars_authorization_behavior_test` (fixture inválida) — pós-MVP.

# Dados sintéticos deixados em produção

`[R05-QA …]` avisos (2: um agendado 18/09 pela tela, um materializado pelo worker), eventos cancelados/aprovados na Agenda das instituições sintéticas, circulares excluídas (soft) com anexos `pixel.png` (70 bytes) no bucket legado. Limpeza no fim da Etapa 2 (P25/P42).
