---
source: docs/reviews/etapa-2-operacao/comunicacao/coordenacao.json; docs/reviews/etapa-2-operacao/next-round/R09-backlog.md; codigo e evidencias R08 citados abaixo
status: gate-ui-bloqueado-por-runtime
generated_at: 2026-09-12
---

# G1 — primeira fatia da nova R09

Round `E2-R09-20260912-1542`; G1 `01a096ed-b723-78f0-ac64-84ea6b11be8b`,
host `local`; unico C0 `01a096ed-314b-7c13-a9e0-3e64649e66fc`.
Adocao da revisao C0 96 publicada em `0027fabe8` (JSON G1 r99).
Base inspecionada `7907453f0`; somente branch/worktree atribuidas.

## Fatia escolhida e prova restante

`apps/superadmin -> Estrutura -> Turmas -> Criar -> Vinculos e aparencia -> groups.location`.
O consumidor ja existe em `group_form_page.dart:1199`, somente na criacao;
o router produtivo o injeta em `superadmin_router.dart:2217`.
Seleciona catalogo da unidade, chama `superadmin_group_location_create_v2`,
retendo recibo/versao, e encadeia `superadmin_group_save`.
Nao tentar editar o Local por esse seletor: ele e ocultado na edicao.

Reutilizar `docs/reviews/evidence/etapa-2/r08-coordenacao/ciclo120.md`:
29 PASS/0 FAIL locais apos a correcao C0, sem certificado de UI/persistencia.
O residual de refresh label/kind descrito naquele recibo ja tem guarda no
codigo atual (`group_form_page.dart:1242`); nao reimplementar nem repetir
goldens/testes verdes por troca de rodada.

Primeiro gate operacional: G0 provar login/leitura/reload e C0 transferir
nominalmente o Chrome existente a G1. `slotsR09.e2eLiberado=false` na r96;
Chrome PID 22592 atribuido a G0. Nenhum browser, build ou teste Flutter
iniciado por G1. Espera externa sem ETA calculavel.

Com o slot: entrar normalmente como `qa-r06-estrutura`, abrir Criar turma,
selecionar a instituicao/unidade sinteticas retidas, escolher Local do catalogo
da unidade, salvar uma turma sintetica identificada R09 e reabrir detalhe/reload.
Conferir o mesmo vinculo e hierarquia nos leitores autoritativos, registrar
somente IDs/resultados sem sessao ou credencial. G5 fornece a negativa valida
da familia/contrato. Guardar o sintetico ate o encerramento formal da Etapa2.
Nao usar uma prova API isolada como substituta da UI.

## Independente inspecionado — Membros

`apps/superadmin -> Estrutura -> Turmas -> Pessoas da turma -> groups.members`.
Bloqueio de implementacao confirmado por leitura, ainda sem execucao de teste:
`_editPerson` e `_searchAndInvitePerson` produzem IDs `person-pending-*`
(`group_form_page.dart:1914,1978`). `_savePayload` envia-os como `person_id`
(`supabase_group_directory_repository.dart:231`). O corpo vigente versionado
em `20260911211100_structure_handles_create_payload_v1.sql:203` converte o ID
para UUID e exige identidade global ativa, alem de `role_code` existente.
O dialogo de busca nao resolve identidade real. Nao basta cadastrar nome
localmente para fechar a acao.

Pedido concreto G5/C0: confirmar o uso contextual de
`superadmin_people_identity_lookup_v1` (ja consumido por
`SupabasePersonIdentityRepository`) com `institution_id`/`unit_id` e a
capacidade aplicavel ao usuario autorizado a vincular membros; confirmar os
codigos de papeis validos para esta operacao e a negativa de hierarquia.
G1 e dono da correcao do consumidor; G5 apoia contrato/negativas; C0 aplica
eventual SQL. Nenhuma RPC nova ou permissao ampliada nesta entrega.
Implementar essa proxima fatia apos fechar Local ou transferencia C0 explicita.

## Limites e continuidade

Avaliacoes permanece depois da primeira fatia. Reutilizar configuracao
`833a89d8-466f-4ff4-8ab9-4ffb7f33a1cb`, periodo
`c4e38ada-e062-4466-a22d-88dca177fa30` e diario
`d2c945d8-3809-4d84-b836-2bc6da7c381d` da prova API R08; nao recriar cadeia.
Nenhum novo aceite FE/BE/E2E e nenhum teste de produto nesta abertura.
Sem delta de estado para aplicar; C0 conserva inventario/tres rastreadores.
Memoria: consulta `Search-CoeloKnowledge -Query hierarquia -Audience team`
executada com Root explicito; projecoes Turmas/Locais e fontes consultadas.
No-op: nenhuma regra duravel de produto mudou. Projecao antiga de Turmas
descreve demonstracao local; nao foi usada como prova do backend atual.
Sem codigo de produto alterado, WIP, segredos ou recursos remotos criados.
Nao ha polling ou timer; a continuacao depende de follow-up/transferencia C0.
