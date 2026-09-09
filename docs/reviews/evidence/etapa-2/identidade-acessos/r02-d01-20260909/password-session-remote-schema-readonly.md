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
