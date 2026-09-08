---
source:
  - "Gate central de preparação de probe Auth47, 2026-09-08"
  - "LOC-PARSE02: snapshot c80be689, falha real SQLSTATE55000"
  - "Candidata 6b0cbb3009c7184896cfd2aebd6c7a7ca0fafe10, loop de sete helpers"
status: preparado_aguarda_review_e_gate_local
generated_at: "2026-09-08"
---

O probe nominal identifica qual das sete assinaturas do preflight LOC diverge e compara o fingerprint bruto com a versão que normaliza somente CRLF para LF. Essa normalização existe apenas na consulta diagnóstica: não altera funções, migrations, fingerprints exigidos ou ACLs.

O pacote usa **AuthOnly47**, target **20260901200206**, com somente a fixture `loc_legacy_helper_fingerprint_catalog_test.sql`. A base continua Auth45 + dois preflights existentes. Não inclui candidata LOC, bootstrap de capacidades, grant, reparo ou helper novo. O catálogo informa usuário, versão PostgreSQL, posição/assinatura/OID, owner, SECURITY DEFINER, volatility, config, ACL completa, hash esperado/bruto/LF e contagens de bytes/CR/LF/CRLF. Corpos de função e valores de dados não são emitidos.

Os sete TAP verificam exclusivamente a existência das sete funções. Um resultado 7 PASS não significa que seus fingerprints correspondam; essa conclusão depende dos campos `matches_raw` e `matches_lf` do diagnóstico, por posição. Uma função ausente produz FAIL de existência, sem chamada da função. BEGIN/ROLLBACK delimitam a fixture; a extensão pgtap segue o padrão das fixtures existentes.

Critério de parada: pins, revisão independente e gate central antes de qualquer execução. Após o gate, registrar identidade, resultado real, primeira divergência e cleanup independente. Estimativa operacional: 3–5 minutos. Nenhuma correção de produto ou permissão foi feita nesta preparação; não há conhecimento aprovado novo para projetar.

Comando proposto, ainda não executado:

~~~powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 -AuthOnly -TargetVersion 20260901200206 -TestPath packages/coelo_database/supabase/tests/loc_legacy_helper_fingerprint_catalog_test.sql
~~~

A revisão independente E2E2 conferiu integralmente as duas listas de sete assinaturas/hashes contra a candidata6b e não identificou bloqueador. Para evitar que o próprio contexto de formatação produza drift, o diagnóstico fixa **search_path=public,pg_catalog**, exatamente como a candidata, e registra esse valor. Plan/ok/finish usam public,extensions,pg_catalog; o JSON é emitido como comentário TAP diretamente durante o catálogo. O reviewer conferiu novamente esse delta. Não houve execução SQL nesta revisão.

Pin final da fixture UTF-8/CRLF: **4b73dad4d61fd00d20c8ed73c205ed0c909654f8c3cfac84bfd01add102e05bc**. O resultado anterior está documentado em93304747, incluindo consulta real do ledger49 às05:06:46 UTC e cleanup independente zero às05:08:25 UTC.
