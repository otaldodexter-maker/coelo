---
title: "D03 — gates nominais de backend"
source: "Catálogo Supabase consultado por D03 em 2026-09-09; candidato CHILD 2173cbd0; OQ-040; spec048; contrato CHILD-READ01"
status: "read-only-evidence; no-remote-mutation"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Etapa 2 → apps/superadmin → Acompanhamento → Alunos/Assiduidade/Rotina diária.
Executor D03, thread 01a086d8-bbc2-7df3-aae4-d04ffcd32a56. Base local inicial
56eb3f19de23e364ea5f7e4f73a6fbd9a851e230. Leituras em produção via MCP Supabase
`execute_sql`, projeto coelo `evvbomzejfijozbtgvpt`, entre 12:52 e 13:00 BRT.
Nenhum dado de pessoa/criança, sessão real, token ou conteúdo privado consultado.

## Disponibilidade dos gateways

Consulta executada:

```sql
select n.nspname as schema_name, p.proname,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and (
  p.proname='superadmin_child_context_directory_v2'
  or p.proname like 'superadmin_attendance_%'
  or p.proname like 'superadmin_routine_%'
  or p.proname like 'superadmin_daily_routine_%')
order by p.proname;
```

Resultado: `[]`. Evidência de catálogo, não chamada de negócio nem teste E2E.
Não atesta inexistência de tabelas, de outros nomes ou de implementação local.

## CHILD — dependências e divergência

Candidato preservado no commit 2173cbd0859e355191f1aaf54bf4370bc5a8dfe4:

- `packages/coelo_database/migrations/20260908051500_superadmin_child_context_directory_v2.sql`;
- `packages/coelo_database/supabase/tests/superadmin_child_context_directory_v2_test.sql`;
- `packages/coelo_database/scripts/tests/Test-ChildDirectoryCandidate.Tests.ps1`.

O candidato preserva identidade interna039, `people.read` Owner-only, escopos
platform/institution, paginação keyset, cinco campos mínimos, reautorização após
locks, auditoria sem nomes e erro seguro. Isso descreve o código; não certifica
replay, concorrência ou produção.

SELECT dos MD5 de prosrc com normalização CRLF→LF observou:

| Helper | Esperado candidato | Remoto atual |
| --- | --- | --- |
| require_superadmin_internal_context(text) | 5cdb28081d40e15232ef50912edd8082 | igual |
| superadmin_internal_error_envelope(text,uuid) | bfce7b85b8d5d43e93e5d3fba3a66dc8 | b89d2dc22f032a1c3f155a77f0eaaf08 |
| audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid) | d218f9e256e2dca89ed92cf7b702cc13 | igual |
| audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,audit_outcome,text,uuid,uuid,text,uuid) | 950412c5312aae7361164a95f35dfa43 | igual |
| audit_append_auth_session_denial(uuid,text,text,text,text,uuid) | 072e47ff682be44ca3fce7b0d80ea4a4 | igual |

Volatilidade, SECURITY DEFINER, SETOF/tipo retornado, owner postgres e
search_path vazio dos cinco helpers coincidem com o candidato. ACLs e schema
físico completo não foram certificados por essas consultas.

Leitura da definição do envelope mostrou diferença semântica: o remoto não
reconhece `SAI_INVALID_ARGUMENT`, enquanto o helper da migration canônica
`20260827235500_superadmin_internal_institution_list_filter.sql` o reconhece e
retorna HTTP semântico 400. Trocar apenas o hash perderia a garantia de entrada
inválida esperada pelo candidato. Não repinar nem aplicar a migration histórica
em lote para contornar esse gate.

SELECT do catálogo `platform_permissions` e grants ativos confirmou:
`people.read`, módulo people, tela directory, ação read, risco high, status
active, allow ativo exclusivamente owner. Essa fotografia não substitui a
revalidação de sessão/permissão de cada operação.

Próximo passo nominal solicitado a D00: recuperar os três arquivos preservados
na worktree D03, revisar/preparar replay local serializado com FoundationOnly
e AdditionalMigration fixada por hash, usando apenas o TAP CHILD. Nenhum
Docker iniciado por D03; `docker ps` inicial sem containers. Antes de produção,
resolver a dependência do envelope em pacote forward-only específico, repetir
preflight e obter autorização nominal do pacote exato. Wiring Flutter é reserva
separada de quatro arquivos comuns, sem nova rota e sem retirar Acompanhamento.

## Gestão de alunos, Assiduidade e Rotina

students.link/transfer/edit/revoke permanecem sem contrato nominal de comandos,
recibos, versionamento e autorização interna no material inspecionado. São MVP,
não operações adiadas; não implementar sucesso local sem persistência.

Assiduidade: OQ-040/spec048 mantêm abertas capability interna, matriz/AAL,
escopo e DTO. O draft não autoriza SQL/RED de detalhe v2 nem restauração da
cadeia people-based removida. O pedido D03 exige executar conforme specs;
não decide silenciosamente essa matriz. D01/D04/D00 precisam encaminhar a
decisão nominal. Correções de cliente continuam independentes.

Rotina: READ01 continua proposta e os endpoints históricos removidos pertencem
ao realm people-based. Não criar adapter que aparente um backend interno
autorizado. Manter a distinção entre editor local testável e operação produtiva.

Testes de produto remotos: não executados. Nenhuma certificação BE done ou E2E.
Esta nota é evidência operacional e pacote de dependências, não conhecimento
de produto aprovado nem nova decisão de autorização.
