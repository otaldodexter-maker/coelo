---
source:
  - "Gate central Auth47, commit cb416a6b6c37697466a653c11ba85418a9d16d39"
  - "Execução local do probe LOC de sete helpers em 2026-09-08"
  - "Candidata LOC 6b0cbb3009c7184896cfd2aebd6c7a7ca0fafe10"
status: catalogo_real_divergencias_identificadas
generated_at: "2026-09-08"
---

O probe **AuthOnly47** aplicou a base integralmente e passou nas **7 verificações de existência**. O catálogo identificou divergência de fingerprint nas posições **4 e 6** do loop LOC, tanto no texto bruto quanto após normalizar somente CRLF para LF. As posições **1, 2, 3, 5 e 7** coincidem no fingerprint bruto. Portanto, 7 PASS não significa que os sete fingerprints passaram.

A primeira divergência nesse catálogo é `app_private.superadmin_get_activity_form_options(uuid)`: esperado **65fe6408f0f2c6b0c1c9d71a809f2d80**, observado bruto **70700ddc38d42df4fae75765b7ff2617**, LF **b951e603ef34b7d26597356a16eb6d06**. A segunda é `app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)`: esperado **886752274164d0d435c9df8ced18d896**, bruto **063138f31cff9ec6b5a2fe24ba036c56**, LF **3167d90039df952c9ae561f28486223c**.

A comparação normaliza somente o texto local e mantém o hash esperado bruto. Sem o corpo ou o fingerprint LF da fonte que originou o valor esperado, essa comparação não exclui diferenças de quebra de linha entre as fontes, nem demonstra divergência semântica ou estrutural. Ela apenas confirma que os dois valores locais consultados não coincidem com o pin bruto exigido; não autoriza trocar os pins para os valores observados. A frente E2E2 recebeu o catálogo para confrontar as fontes canônicas e a proveniência do candidato.

| Posição | Assinatura | Hash bruto | Hash LF | Bytes bruto/LF |
|---|---|---|---|---:|
| 1 | app_private.activity_management_payload(uuid) | coincide | DIVERGE | 4693/4624 |
| 2 | app_private.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean) | coincide | DIVERGE | 6200/6103 |
| 3 | public.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean) | coincide | DIVERGE | 1209/1195 |
| 4 | app_private.superadmin_get_activity_form_options(uuid) | DIVERGE | DIVERGE | 5062/4982 |
| 5 | public.superadmin_get_activity_form_options(uuid) | coincide | coincide | 287/287 |
| 6 | app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid) | DIVERGE | DIVERGE | 3279/3221 |
| 7 | public.superadmin_create_activity_locations(uuid,uuid[],text,uuid) | coincide | DIVERGE | 356/355 |

O JSON integral em [loc-auth47-helper-fingerprints-2026-09-08.json](loc-auth47-helper-fingerprints-2026-09-08.json) contém hashes, ACLs, OIDs e contagens CR/LF/CRLF por assinatura. A consulta executou como postgres no PostgreSQL **170006**, com **search_path=public,pg_catalog**, exatamente como a candidata. Todos os sete helpers são SECURITY DEFINER, owner postgres, config search_path vazio. Os privados têm somente EXECUTE de postgres no ACL completo; os wrappers públicos têm também authenticated. Nenhum corpo de função, segredo, dado de usuário ou chamada funcional foi emitido.

| Evidência operacional | Valor |
|---|---|
| Início UTC | 2026-09-08T05:22:12.9858702+00:00 |
| Identidade | coelo_safe_74977b617bee4ce3bd788cd54dd92 |
| Criação UTC | 2026-09-08T05:22:18.6917330Z |
| Marker | .coelo-safe-replay lido e idêntico à identidade |
| Base / target | 45 canônicas + 2 preflights = 47 / 20260901200206 |
| TAP | 7 existência PASS, sem aborto |
| Saída | CLI/wrapper 0; sessão34314 encerrada |
| Cleanup independente UTC | 2026-09-08T05:25:07.1970416+00:00 |
| Recursos próprios | 0 containers, 0 volumes, 0 redes; staging ausente |
| Staging histórico alheio | coelo_safe_af5bdf571cff41309f5b6845b713a preservado |

Nesta execução, a aplicação das 47 entradas é sustentada pelo transcript do CLI, sem uma nova captura independente do ledger. A captura ledger49 do replay LOC anterior permanece uma evidência distinta, no commit93304747.

Foi executado somente `loc_legacy_helper_fingerprint_catalog_test.sql`, SHA UTF-8/CRLF **4b73dad4d61fd00d20c8ed73c205ed0c909654f8c3cfac84bfd01add102e05bc**. Não foram incluídos a candidata LOC, bootstrap de capacidades, grants ou reparos. Nenhum fingerprint foi alterado. Não há conclusão funcional de Locais nem alteração de regra de produto; a evidência técnica permanece nesta fonte canônica, sem projeção nova de conhecimento.
