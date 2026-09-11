---
title: "Handoff — R05 · Estrutura (E2-R05-20260911)"
source: "comunicacao/estrutura.json revs 41–46; deltas-r05-estrutura.json; capturas em rota-real/"
status: "entregue ao coordenador em 11/09/2026 15:0x"
generated_at: "2026-09-11"
---

# R05 · Estrutura — handoff

Branch `work/etapa2-r05-estrutura` (base `origin/dev` 2f6a6114f, merges de dev
62f284d9c e 15d98e9dc). Só o coordenador escreve em `dev`, inventário e
rastreadores; os deltas estão em `deltas-r05-estrutura.json` (49 entradas,
ensaio `apply-tracker-delta.cjs` + `validate-trackers.cjs` PASS, revertido).

## Fechou na rota real (produção, `qa-r03`, build release de `qa_main` + CDP)

| action_id | Prova | Persistência | Negativa |
| --- | --- | --- | --- |
| `activities.create` / `activities.location` | assistente completo com categoria de produção, unidade e local do catálogo | `activity_definitions` 95b98978 (local 82e92854) | activities v2 security_contract 37/37, activity_location_create 33/33 |
| `activities.detail` / `activities.edit` | detalhe recarregado; edição carrega categoria do catálogo, renomeia (mv 11) e vincula turma (mv 17) | `save_v2` | activity_save_v2 46/46, read 28/28 |
| `activities.publish` (só backend) | `save_v2` com `p_publish=true` após vincular turma (P36) → `active`, mv 24; detalhe mostra Ativa | produção | activity_save_v2 46/46, permissions_publish 18/18 |
| `units.edit` / `units.status` | Rascunho → Ativa pela etapa Hierarquia; lista e edição recarregadas | `update_unit_for_superadmin` | unit_detail 31/31 |
| `units.filter` / `units.reload` | filtro por instituição; reload completo | leitura | idem |
| `units.locations-map` / `units.copy-institution-location` | catálogo da unidade; Trazer da instituição copiou "Sala R04 Estrutura" | `activity_locations` d5461295 | copy 19/19, authorization 26/26, isolation 6/6, catalog 30/30 (reexecutados no espelho) |
| `institutions.edit` | CNPJ + representante + administradora; reload mostra pessoas mascaradas e @ | `superadmin_institution_contacts_edit_v1` (lote 28), mv 2 | pgTAP do lote 28 (38/38, G5) |
| `institutions.list` / `filter` / `detail` / `reload` | lista, busca, aba de status, detalhe pela edição, reload | leitura | lote 3, institution_detail 25/25 |
| `groups.create` (de novo) | "Turma R05 Estrutura" em Escola R04/Unidade Centro | `groups` 4214106c | (já E2E na R04) |

## Correções de código (commits na branch)

- df8ef50ca — `ActivityIdentityIcon.databaseKey`: o cliente mandava
  `icon_key: "activity"` e o CHECK do banco só aceita as 12 chaves legadas
  (`save_v2` respondia `SAI_INTERNAL_ERROR` sem detalhe); modo edição do
  formulário de Atividades combina `fetchTemplateOptions` (taxonomia) com
  `fetchFormOptions`; retry do catálogo também na edição.
- 9a9b6ee3f — rota de detalhe de Atividades passa `onEdit` (o botão nascia
  sempre desligado).
- fe2cf49f9 / 5a4a0213c — `institutions.edit`: contrato de contatos no
  repositório, `owner_*` fora dos campos sem contrato, `edit_core_v2` só
  quando o núcleo muda (o servidor rejeita no-op).
- 01a8c3e27 — parsers de `unit_detail_v2`, `group_detail_v2` e detalhe de
  Atividades toleram chaves aditivas: o lote 211100 (handle nos detail_v2)
  derrubava "Locais da unidade" e "Editar turma" no deep link.
- 57cd4b5b3 — pacote `20260911180000_structure_handles_v1` (aplicado em
  produção pelo coordenador no lote 42).

## Aberto, com o primeiro gate

- `activities.publish` no cliente: "Salvar alterações" fecha antes do HTTP
  (a edição não conhece o status corrente) e a falha congela o Salvar
  rascunho até recarregar. Gate: decidir `p_publish` pelo status do detalhe.
- `groups.location` (escrita): `SupabaseGroupLocationCreateRepository`
  existe sem consumidor; o assistente de Turmas não tem seção de local.
- `groups.members`: só o estado vazio e a busca foram abertos.
- `assessments.*`: `qa-r03` sem vínculo profissional ("Sem atribuições");
  pacote de vínculo não escrito.
- `institutions.status` ("indisponível até a definição das transições"),
  `institutions.files/error/access-denied`, `units.error/access-denied`,
  `locations.detail-links`: não exercidos.
- Regra do @ no cliente (campo Identificador = @ com disponibilidade
  enquanto digita e trava de 30 dias): backend pronto (180000 + 211100);
  cliente não feito — passos em `estrutura.json` rev 45 `ordemDaRodada[6]`.
- Goldens: 9 de `activity_golden_test` e 1 de `institution_directory_page`
  falham em dev pelo composto de tabela (G-SUP); regravar após o merge.

## Dados sintéticos em produção (P42: ficam até o fim da Etapa 2)

`activity_definitions` 95b98978 (ativa) e 2e45c8bd (rascunho de sonda);
`groups` 4214106c; `activity_locations` d5461295; `institutions` 190dd028 com
CNPJ 11444777000161 e pessoa "Rafaela Sintetica" (representante + owner);
`units` f5284f2f ativa.

## Ferramental que funcionou (scratchpad desta sessão)

`serve.js` (SPA na 3001), `cdp.js` (login por driver + cliques por
coordenada + capturas), `net.js` (grava as RPCs com corpo e resposta),
`rpc.js` (chama uma RPC com a sessão do próprio Chrome, sem imprimir token),
`espelho.sh` (só o `db` do Supabase + baseline + 116 lotes por psql).
Lição: o `flutter build web` apaga `build/web` e derruba o servidor estático
no meio da prova; religar depois do build.
