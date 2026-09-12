# Revisao G7 - preflight API de Avaliacoes

- Data: 2026-09-12
- Escopo: leitura remota autenticada da fixture QA existente e revisao de
  `0a7642dca` / `754af0368` contra o repositorio e as RPCs vigentes.
- Fora do escopo: Chrome, Flutter, SQL, nova fixture, mutacao e rastreadores.

## Medicao somente leitura

Com a identidade QA existente, a autenticacao e
`superadmin_assessment_context_options` responderam com sucesso. O contexto
tem uma atribuicao e a forma esperada para a rota: `activity_group_link_id`,
atividade, unidade, turma e instituicao. Nenhum identificador ou credencial foi
registrado.

O mesmo preflight encontrou zero periodos. A leitura
`superadmin_assessment_configuration_read(target_activity, target_unit)` da
atribuicao respondeu sucesso com `data: null`; a fila de fechamento tambem
respondeu sucesso vazia. Logo nao ha configuracao, periodo aberto ou diario
remoto existente para reler. A fixture `53b9c6d29` e transacional do espelho,
com rollback; ela nao materializa esses dados em producao.

## Contrato e roteiro corrigido

1. A configuracao parte da atribuicao retornada e chama
   `superadmin_assessment_save_configuration` com `request_id`,
   `configuration_id: null`, `expected_version: 0` e payload de configuracao.
   O oraculo imediato e resposta de sucesso `draft`, seguida de
   `configuration_read(target_activity, target_unit)` nao nula.
2. A ativacao chama `superadmin_assessment_activate_configuration` com
   `request_id`, `configuration_id` e a versao retornada. O oraculo e
   configuracao `active`, seguida de novo `context_options` contendo o periodo
   `open` da mesma instituicao/unidade.
3. So entao o diario pode ser criado por
   `superadmin_assessment_save_gradebook`: `request_id`,
   `gradebook_id: null`, `expected_version: 0`, `reason: null` e payload
   estrito `{activity_group_link_id, period_id, configuration_id, students}`.
   O oraculo e `gradebook_read(target_gradebook)` nao nulo, com a linha de
   aluno devolvida pelo servidor e persistencia apos reload.
4. Os estados efetivos do diario sao `draft`, `submitted`, `reviewed` e
   `published`. Nao existem RPCs chamadas "close" ou "reopen": o caminho e
   submit, review e return-to-teacher, respectivamente
   `superadmin_assessment_submit_gradebook`,
   `superadmin_assessment_review_gradebook` e
   `superadmin_assessment_return_gradebook`, sempre com `request_id`,
   `gradebook_id`, `expected_version` e `reason`, seguidos de releitura.

## Veredito

O roteiro anterior citava os gateways certos, mas tratava a fixture local como
se ja existisse no ambiente remoto e chamava close/reopen genericamente. O
primeiro gate real e criar e ativar a configuracao na atribuicao medida; nao ha
base autorizada para certificar entrada, notas ou transicoes antes disso.
