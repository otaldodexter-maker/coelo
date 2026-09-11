---
title: "Handoff — grupo formularios-cuidado-rotina, Rodada 5 (tarde de 11/09/2026)"
source: "Execução da frente G3 em 2026-09-11 12:00–15:45; comunicacao/formularios-cuidado-rotina.json revisões 34 a 40; deltas-r05-fcr.json, -2, -3 e -4; produção conferida por leitura"
status: "entregue; todos os pacotes SQL desta rodada aplicados pelo coordenador; Edge Functions form-media, form-operations e form-export-download implantadas"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff — formularios-cuidado-rotina (Rodada 5)

Recorte: 43 ações das famílias `forms_authoring`, `forms_responses`,
`forms_files`, `child_safety`, `health_care`, `medication`, `attendance` e
`daily_routine`. Branch `work/etapa2-r05-formularios-cuidado-rotina`, base
`origin/dev 2f6a6114f` (merge de `4bf0cfe51` em `7fe204565`). O handoff da R04
foi preservado em `docs/reviews/evidence/etapa-2/r04-formularios-cuidado-rotina/handoff-r04.md`.

## O que fechou (prova na rota real com `qa-r03`, produção)

| Ação | Estado proposto | Prova |
| --- | --- | --- |
| forms.publish, forms.overview | verified-e2e (aplicado) | `form_publish` 200, versão 3, auditoria; visão geral recarregada |
| forms.monitor, forms.respond, forms.responses, forms.response-detail | verified-e2e (aplicado) | distribuição a0ee4530 → ocorrência 6b0bd1ef pelo cron → resposta 1f365626 |
| forms.responses.export, forms.download | verified-e2e (deltas-3) | job 09f86ec7 succeeded (3975 bytes, R2), `form-export-download` 200 com URL presignada |
| child-safety.create/edit/suspend | verified-e2e (deltas-2) | `child_safety_request/edit_pending/decide/change_lifecycle` 200 com auditoria |
| health-care.create/detail/edit | verified-e2e (deltas-2) | perfil 5712371e, revisão 2 |
| attendance.dashboard/create/mark/finish/correct | verified-e2e (deltas-3) | chamada d3821901 (open → closed → corrected, versão 4) |
| daily-routine.create | verified-e2e (deltas-4) | modelo 176882c5 |
| daily-routine.edit | FE verified, BE done (deltas-4) | edição abre o modelo real |
| forms.list | FE verified | card Criar em produção |

## Código entregue (commits na branch, pequenos, em português)

- `f17c2fa15` card Criar de Formulários; `/respond` composto com api; botão Distribuir.
- `b05078dc3` distribuição nova com `id` nulo (P0002).
- `1f4b02e28`, `05968beef` e o commit de adesão a `ChildSafetyMutationSupport`: Segurança infantil criar/editar/gerenciar em produção.
- `30cb982ca`, `a1ca952cc`, `294a88780` Rotina: `can_manage` no topo, request_id uuid, duplicar/criar a partir do modelo.
- `f5d1f0c91` Cuidado: gravidade nula sem data de episódio (23514).
- `b7f61b571` Assiduidade: contrato de 14 RPCs (`20260911220100`) + pgTAP 141/141.
- `7323c9220` Edge Function `form-media` (question-image em R2) + cron `20260911230000`.
- `05968beef` pgTAP do `20260911220000` (15/15).
- Spec: `docs/superpowers/specs/2026-09-11-child-safety-medication-policies-and-notifications-design.md` (P32, regra alvo).

## O que ficou aberto (primeiro gate)

- **medication.create/detail/edit/evidence**: seletor de hora não fecha ao Aplicar sob CDP e o Chrome caiu; "Responsável: nenhuma opção"; imagem "Envio indisponível". FE.
- **forms.upload/resolve-file/expire-file/delete-file**: cliente Dart do editor ainda no fluxo legado por `occurrence_id`; adaptar ao ramo `question-image` da `form-media`. FE.
- **forms.location-answer**: exige formulário com item Local publicado; não exercitado.
- **daily-routine.apply/publish**: composição `onCreateFromModel` entregue em `294a88780` sem prova na rota real; aba Rotinas/Lançamentos vazia esconde o card Criar (regra do estado vazio).
- **child-safety.suspend (exibição)**: linha suspensa continua verde/"Aprovado" após reload; Relação em enum cru; etapa Pessoa pede UUID.
- **Decisão 7**: balão de chat cobre "Lançar/Concluir chamada" em `/attendance/new` e `/attendance/calls/:id`.
- **Harness**: rebuild na pasta servida derruba o app aberto; Chrome sob SwiftShader perde o canvas a cada ~20 min; servidor `node serve.js` morre com a chamada do shell (usar `Start-Process`).

## Dúvidas ao Owner

1. Medicação deve ter abas de status como Perfis de cuidado?
2. Detalhe do perfil de cuidado: manter o redirecionamento ao editor ou criar a tela somente leitura com histórico (spec 020)?
3. Títulos das telas de Formulários sem golden (visão geral, monitor, respostas, arquivos) são proposta da frente.

## Dados sintéticos criados nesta rodada (limpeza no fim da Etapa 2)

Listados em `dadosSinteticosCriados` do JSON: distribuição a0ee4530 e agendamento 2860c35a, ocorrência 6b0bd1ef, resposta 1f365626, job XLSX 09f86ec7 (+ media_asset), autorizações 7fcb6761 e 34d29829, perfil de cuidado 5712371e, chamada d3821901, modelo de rotina 176882c5. Nenhuma chave criada por esta frente.
