---
source: "D00 session47872; source CLI2.116.0; cli-atomicity-final-manifest.json"
status: "local-qualified-2-pass; canonical-four-lines-removed; remote-not-authorized"
generated_at: "2026-09-09"
---

# Atomicidade CLI e equivalencia canonica

A proposta de `proposed-cli-atomic-boundaries.patch` foi materializada por D00 na fonte canonica: somente os quatro BEGIN/COMMIT externos foram removidos. O patch permanece evidencia historica, nao deve ser reaplicado. Todos os demais bytes normalizados LF sao iguais a HEAD na verificacao, inclusive guards, prosrc, SET LOCAL e advisory locks. Os hashes RAW/LF finais e o recibo estao em [manifesto](cli-atomicity-final-manifest.json).

O transporte CLI2.116.0 com controles transacionais autorais seguia o caminho sequencial e inseria historico apos COMMIT. Sem esses controles, SQL e INSERT de historico seguem o mesmo batch. Fonte: [migration apply](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-migration-apply.ts), [driver](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-db-connection.sql-pg.layer.ts).

D00 executou V2 em session47872: exit0, CLI_LEDGER_FAILURE_ROLLBACK_PASS e CLI_LEDGER_SUCCESS_CONTROL_PASS. Fixture sintetica20990909000100 com SET LOCAL, advisory lock e DO/DDL, sem controle externo: trigger rejeitou exclusivamente o INSERT nominal no ledger, e conexao posterior confirmou DDL e linha ausentes. Controle positivo persistiu ambos. A propriedade qualificada e por arquivo; os dois arquivos de produto nao foram executados conjuntamente por essa fixture e nao formam uma transacao unica.

O runner confirmou cleanup; D00 conferiu separadamente tool7b0e22: tres inventarios Docker vazios e TEMP ausente. O log final e seu hash constam do manifesto. Primeiro ensaio84568 falhou antes dos markers, sem SQLSTATE registrado; nao atribuir causa retroativamente. V2 usa bootstrap genuino CLI deliberadamente falho quando ledger ausente, exige depois ledger vazio, sem CREATE/repair manual de historico. A fonte [history](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-migration-history.ts) confirma inicializacao do historico em transacao propria antes do batch; reset vazio nao a garante.

Produto: 36 TAP + 9 HTTP + 1 cold =46 PASS da session78850 sao reutilizados, nao repetidos nem somados. Justificativa: equivalencia completa dos bytes exceto delimitadores, acompanhada de dois gates discriminantes do transporte. Nao declarar nova execucao funcional dos payloads finais. Guards offline26 anteriores, diagnostico5 e bootstrap3 sao evidencias de ferramenta separadas, nao gates de produto nem substitutos dos dois gates reais.

O qualificador exige TEMP e marker exatos, sem reparse/vinculo remoto, configura port binding ao mesmo container e usa CLI fixada offline. V2 nega SUPABASE_EXPERIMENTAL e captura falhas SQL somente por fase e SQLSTATE permitido, sem saida bruta. O runner original e a versao inicial foram preservados para o recibo do ensaio falho.

Transporte pronto para revisao nominal do Owner, com executor CLI e [comandos concretos](password-session-versioning-qualification.md). Execucao remota ainda requer autorizacao nominal, credencial preprovisionada sem fallback, inventario novo, dry-run exatamente com os dois basenames, catalogo sem drift e janela D00. Nao usar MCP timestamp implicito, execute_sql para DDL, repair ou espelho completo. Se somente173000 persistir, reconciliar estado parcial e preparar recuperacao nominal forward-only, sem retirar o guard ou alterar ledger.

Knowledge: no-op; nenhuma politica de produto nova. Nenhuma credencial ou operacao remota usada nesta reconciliacao.
