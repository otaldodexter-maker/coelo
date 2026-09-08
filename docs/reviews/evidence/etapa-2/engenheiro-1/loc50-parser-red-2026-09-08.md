---
source:
  - "Gate central do snapshot6cd030f4f99df502a9771338cf082a52c773cbcd"
  - "Execução root de LocationCatalogV2, 2026-09-08"
  - "98d166d25d18d1d0b615e244ba8af7e93f11420e e bootstrap115df2ca"
status: red_de_compilacao_antes_pgtap
generated_at: "2026-09-08"
---

O replay **LocationCatalogV2/50**, target20260908031000, parou no candidato com **SQLSTATE42601, syntax error at end of input**, statement4/DOpreflight. **Nenhum pgTAP foi executado.** Esta é falha de compilação da migration; não demonstra reprovação dos contratos funcionais, ACLs ou fingerprints.

O harness preparou47canônicas+2preflights+1bootstraplocal. O CLI avançou pelos49arquivos anteriores, incluindo20260908030959_location_catalog_v2_capability_bootstrap_local.sql, e iniciou31000 antes de reportar o erro. A evidência é o transcript de aplicação do CLI. Não houve consulta independente do ledger antes do cleanup; não se apresenta uma captura de ledger inexistente.

A âncora exata é **packages/coelo_database/migrations/20260908031000_superadmin_location_catalog_v2.sql:93**:

~~~sql
is distinct from case when expected.client_execute then array['authenticated:EXECUTE:false'] else '{}'::text[] end then
~~~

O parser apontou para o CASE dessa comparação na verificação de ACL dos helpers legados. O DO inteiro precisa compilar antes de executar seus gates, portanto a execução não chegou a comprovar o vetorMAINTAIN nem os fingerprints do candidato. A observaçãoMAINTAIN anterior permanece sustentada somente pelo probeAuth47 do commit46a6077a.

O candidato foi preservado do commit98d166d25d18d1d0b615e244ba8af7e93f11420e, blob0d4223268de032d7e3536ba58b350b481f8db7c6, SHA LF7c7ca4da2aa4eece06f386aee9ada7c52db69eecd996bca18ed434a922f90538 eCRLF02fb69cbff42834ffa9a9cdebb60bab7e15c6cd0cf150175020de8c8d0f823f6. Não houve correção, derivação ou repetição local após a falha. A coordenação reservou à frenteE2E2 uma correção mínima própria, ainda sujeita a novos pins/review/gate.

| Evidência operacional | Valor |
|---|---|
| InícioUTC |2026-09-08T04:41:53.7367045Z|
| Identidade |coelo_safe_e0e5139d375049a983c1101b632c9|
| CriaçãoUTC |2026-09-08T04:42:00.5718221Z|
| Marker |.coelo-safe-replay lido, valor idêntico à identidade|
| Saída |CLI reset1; wrapper1; sessão34508 encerrada|
| pgTAP |0 executados|
| Cleanup independenteUTC |2026-09-08T04:44:41.7542373Z|
| Recursos próprios após cleanup |0containers,0volumes,0redes; staging ausente|
| Staging histórico alheio |coelo_safe_af5bdf571cff41309f5b6845b713a preservado|

Foram selecionadas somente as três fixtures LOC aprovadas (normal, authorization, isolation). A falha ocorreu antes de seu ponto de chamada. Os scripts Invoke/Prepare, perfis e fixtures foram comparados contra6cd030f4 antes do start, sem drift. A preparaçãoPester488PASS continua válida no escopo do harness; não equivale à compilação SQL do candidato.

Após o cleanup comprovado, o gate central permite o perfil independente Agenda53 na mesma fila serializada. Não permite adaptar/reexecutarLOC, acrescentar grants/bridges, executarF-AUTHOR/A01HTTP ou mutação remota. Nenhuma regra de produto foi alterada; este arquivo registra evidência operacional e encaminhamento da falha.
