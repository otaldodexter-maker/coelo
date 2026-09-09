---
source: "Supabase MCP execute_sql; project evvbomzejfijozbtgvpt; catalog-only READ ONLY transactions"
status: "schema-qualified-readonly; functional-remote-proof-open"
generated_at: "2026-09-09"
---

# Qualificação somente leitura do catálogo remoto

09/09/2026, aproximadamente14:34 BRT. Projeto Coelo
`evvbomzejfijozbtgvpt`, produção. Duas consultas em transações
`BEGIN TRANSACTION READ ONLY`/`COMMIT`; somente `information_schema.columns`,
`pg_proc`, `to_regclass`, `to_regprocedure`, `pg_get_functiondef`, hashes e
funções de inspeção de privilégios. Não foram consultadas linhas de usuários,
sessões ou tokens. Nenhum helper de autorização/auditoria foi executado.

| Verificação | Resultado observado |
| --- | --- |
| auth.mfa_amr_claims existe | true |
| session_id é uuid | true |
| authentication_method é text/varchar | true |
| authenticated tem INSERT/UPDATE/DELETE na tabela | false |
| anon tem INSERT/UPDATE/DELETE na tabela | false |
| Owner require_superadmin_internal_context(text) | postgres |
| SECURITY DEFINER / volatilidade | true / s |
| Configuração | search_path="" |
| MD5 pg_get_functiondef do helper | 1fbed851b3af3f623273243153891b0d |
| Corpo contém auth.mfa_amr_claims | false |
| Corpo contém SAI_MFA_REQUIRED | false |
| EXECUTE direto por anon/authenticated/service_role | false/false/false |

Esses resultados qualificam metadata e ACL esperadas pelo candidato. Não
provam igualdade integral do helper com a base local, comportamento de uma
sessão real remota, ausência de controles adicionais ou exploração remota.
O RED funcional continua exclusivamente local; aplicar a migration e executar
o fluxo nominal remoto continuam dependentes da decisão e serialização D00.

O MCP retornou apenas o último SELECT da primeira transação; a segunda
consulta recuperou o resumo da tabela/colunas/ACL que não veio na primeira
resposta. Não houve escrita, bootstrap, login, envio de email ou deploy.

Consulta focal adicional às14:37 BRT, também READ ONLY: o corpo `prosrc`,
normalizado de CRLF para LF, tem4711caracteres e MD5
`5cdb28081d40e15232ef50912edd8082`. Esse fingerprint foi encaminhado para
comparação com o corpo da migration canônica antes de fixar o preflight;
o propósito é recusar substituição de uma função com alteração inesperada,
mesmo que ainda contenha os nomes de verificações conhecidos. Nenhum corpo
de sessão/usuário ou token foi lido.

## Verificação nominal do successor de auditoria — 15:32 BRT

Consulta somente catálogo pg_proc/pg_namespace, projeto evvbomzejfijozbtgvpt, sem leitura de pessoas/sessões nem execução de RPC de produto. Ambos wrappers: owner postgres, security definer true, volatile v, search_path vazio. Corpos normalizados CRLF→LF:

| Função | MD5 | Caracteres |
| --- | --- | ---: |
| public.superadmin_auth_bootstrap_context() | cf411ecb47a0e3e42aeb4ee654f6b079 |1929|
| public.superadmin_auth_resolve_institution_context(uuid) | e16a3b61cffba4230c7fb4235da9382d |2093|

Os pins coincidem com a definição canônica20260901190927. Esta leitura não aplica a correção, não comprova comportamento remoto e não autoriza escrita. Successor173100 em preparação após falha TAP35 local.