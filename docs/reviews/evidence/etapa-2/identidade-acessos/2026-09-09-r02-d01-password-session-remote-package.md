---
title: "D01 — pacote remoto proposto para exigir sessão password no contexto interno"
source: "packages/coelo_database/migrations/20260909173000_superadmin_password_session_context.sql; r02-d01-20260909/password-session-context-local-package.md; r02-d01-20260909/password-session-remote-schema-readonly.md; r02-d01-20260909/local-auth-recovery-boundary-receipt.md"
status: "superseded-by-v2; not-authorized-not-executed"
generated_at: "2026-09-09"
---

# Pacote nominal proposto (histórico)

Substituído por [pacote v2](2026-09-09-r02-d01-password-session-remote-package-v2.md), com173000+173100 e gate explícito de atomicidadeDDL/histórico. Este v1 não é executável; seus comandos não constituem transporte final aprovado.

**D01-PASSWORD-SESSION-CONTEXT-20260909173000-v1**, exclusivamente para o
projeto Supabase Coelo `evvbomzejfijozbtgvpt`, **produção**. Etapa 2 →
apps/superadmin → Auth → Redefinir senha → recovery sem contexto interno →
`auth.reset`, dependência de `auth.login`/contexto protegido.

Único arquivo implantável:
`packages/coelo_database/migrations/20260909173000_superadmin_password_session_context.sql`.
Único objeto de aplicação substituído:
`app_private.require_superadmin_internal_context(text)`.
O mecanismo de migrations também registra a aplicação no histórico do projeto.

Este pacote está **proposto**. Reserva local r9, autorização de Git/integração,
commit/push e ferramentas disponíveis não autorizam deploy. A autorização do
Owner deve nomear este pacote, projeto e SHA final, com janela exclusiva D00.
Não foi efetuada chamada remota nesta preparação documental.

O pacote da persona/SMTP, executor integrado por D00 no commit `8847c974`,
continua independente em
[pacote Auth remoto](2026-09-09-r02-d01-auth-remote-package.md).
Esta migration não cria persona, altera senha/conta do Owner, fornece mailbox,
envia email nem concede autorização para executar aquele pacote.

## Problema e efeitos exatos

O [discriminante local real](r02-d01-20260909/local-auth-recovery-boundary-receipt.md)
observou contexto interno concedido a recovery com método OTP, antes do PUT e
após refresh. É evidência local; não constitui demonstração funcional remota.

Após validar usuário e existência/ownership/validade da sessão em
`auth.sessions`, o helper passa a exigir uma linha em `auth.mfa_amr_claims`
da **mesma session_id**, com `authentication_method = 'password'`. Ausência
gera `SAI_SESSION_INVALID`. O método vem do estado mantido pelo provedor;
claims AMR do JWT ou metadata editável não substituem essa prova.

Preservar integralmente os demais guards: usuário e realm interno, identidade,
auth link, membership, papel, escopo/hierarquia, capability e grant ativo.
AAL1/AAL2 continuam conforme adiamento MVP da ADR 0019; o nome da tabela AMR
não introduz MFA. O achado separado sobre AAL ausente não integra este pacote.

Função continua `STABLE SECURITY DEFINER`, owner `postgres` e
`search_path = ''`. A migration reafirma `REVOKE ALL` para `PUBLIC`, `anon`,
`authenticated` e `service_role`; não adiciona grants. Não escreve em tabelas
Auth/AMR, memberships ou auditoria nem altera RLS, RPCs públicas, frontend,
SMTP, TTL, redirects ou configuração Auth. Chamadas futuras aos wrappers
continuam usando sua auditoria de negação existente.

## Artefatos e hashes a fechar

| Item | Valor / estado |
| --- | --- |
| SHA-256 final autorizado da migration | **PENDENTE** de estabilização, revisão e campanha local |
| SHA do checkout consolidado implantável | **PENDENTE** D00 |
| Hash anterior exigido, MD5 de prosrc com CRLF→LF | `5cdb28081d40e15232ef50912edd8082`, 4711 caracteres |
| Hash posterior proposto, mesmo algoritmo | `6b3f7d0a6b374786137ed62ae8cf1c18`, 5250 caracteres; **PENDENTE** de prova local |
| Hash posterior final certificado pelo teste | **PENDENTE** |
| Recibo de revisão independente e local TAP/HTTP | **PENDENTE** |
| Autorização nominal Owner / janela D00 | **PENDENTE / PENDENTE** |
| Aplicação e prova posterior remotas | **NÃO EXECUTADAS** |

O SHA de preparação comunicado pelo executor foi
`A57E3F85C3906F2E83F28AE90BFBFD58E10BED6A25AFA8352019DF0210342BD8`;
é histórico de candidato, não SHA final autorizado. MD5 aqui identifica drift
de corpo no catálogo; SHA-256 identifica os bytes integrais implantáveis.
Nenhum campo pendente pode ser preenchido com resultado presumido.

## Pré-condições de execução

1. D00 recebe revisão independente da migration final, fixa SHA e materializa
   os mesmos bytes no checkout consolidado. O hash anterior exato, metadata,
   ACL e schema AMR devem permanecer válidos; qualquer drift interrompe.
2. Campanha local reservada aprovada: TAP exclusivo de autorização/auditoria
   e HTTP GoTrue/Mailpit/PostgREST com `AssertConfined`, conforme
   [pacote local](r02-d01-20260909/password-session-context-local-package.md).
   Deve provar password e refresh permitidos; recovery original/refresh e
   metadata mutável negados; reset legítimo ainda funcional; recovery após
   PUT continua sem contexto; logout e novo login password corretos. Registrar
   resultados únicos e cleanup. Esses testes ainda estão pendentes aqui.
3. Owner autoriza nominalmente projeto, pacote e SHA final. D00 fixa janela,
   escritor único, responsável pela verificação e integração do recibo.
4. Na janela, repetir somente o preflight necessário de catálogo e histórico,
   sem consultar linhas pessoais, sessions ou tokens. Conferir ausência de
   aplicação anterior/colisão e que nenhum outro escritor alterou o helper.
5. A CLI2.116.0 deve atuar no projeto exato e permitir a operação nominal como
   `postgres`, com histórico e dry-run de uma única migration qualificados.
   Ausência de acesso, drift ou timeout bloqueia a aplicação;
   não habilita um transporte alternativo nem supressão dos preflights.

O [recibo remoto somente leitura](r02-d01-20260909/password-session-remote-schema-readonly.md)
de 09/09, aproximadamente 14:34 BRT, já documenta tabela/colunas AMR presentes,
ausência de DML cliente, helper com owner/metadata esperados e EXECUTE direto
negado para os três papéis. Seu MD5 de `pg_get_functiondef` é
`1fbed851b3af3f623273243153891b0d`; é representação diferente de `prosrc`.
Esse recibo não prova aplicação, equivalência funcional remota ou vigência na
janela futura. O preflight usa o hash integral de `prosrc`, não comparação
parcial por palavras-chave.

## Chamadas futuras nominais, ainda não executadas

O MCP instalado expõe `supabase_list_migrations`, `supabase_execute_sql` e
`supabase_apply_migration`. Contrato confirmado por descoberta local de tools;
a [documentação oficial MCP](https://supabase.com/docs/guides/ai-tools/mcp)
lista ferramentas distintas para migrations e SQL. O índice changelog foi
solicitado, mas a ferramenta web recusou seu content-type; não foi considerado
verificado. Revalidar contrato/transporte na janela se houver mudança.

Histórico futuro:

```javascript
await tools.mcp__codex_apps__supabase_list_migrations({
  project_id: 'evvbomzejfijozbtgvpt',
});
```

Pre/postflight de catálogo, usando somente `supabase_execute_sql` com o
`project_id` acima e o SQL abaixo como `query`. Registrar a saída sanitizada
e comparar hash/owner/metadata/ACL aos valores aprovados. A verificação de
schema/ACL AMR do recibo também deve ser reconfirmada na janela.

```sql
begin transaction read only;
select
  pg_catalog.md5(pg_catalog.replace(p.prosrc, E'\r\n', E'\n')) as body_md5,
  pg_catalog.length(pg_catalog.replace(p.prosrc, E'\r\n', E'\n')) as body_chars,
  pg_catalog.pg_get_userbyid(p.proowner) as owner,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  p.proconfig as configuration,
  pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
  pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
  pg_catalog.has_function_privilege('service_role', p.oid, 'EXECUTE') as service_role_execute
from pg_catalog.pg_proc p
where p.oid = pg_catalog.to_regprocedure(
  'app_private.require_superadmin_internal_context(text)'
);
commit;
```

Para a única migration, o transporte proposto atualizado é a CLI oficial
2.116.0 em diretório nominal separado, conforme comandos completos da
[qualificação de versionamento](r02-d01-20260909/password-session-versioning-qualification.md).
Esse diretório contém somente a fotografia do histórico já aplicado e os
bytes aprovados da migration20260909173000. `migration fetch/list` devem
qualificar o histórico; `db push --dry-run --skip-vault` deve listar exatamente
esse único arquivo. Só depois dos demais gates pode ocorrer `db push` no
mesmo diretório congelado, sem include-all/roles/seed. A CLI registra a versão
nominal no histórico de migrations; esse registro é parte esperada da aplicação.

Não executar esses comandos no espelho completo do checkout ou no staging do
replay local. A sequência ainda não foi executada remotamente e depende do
inventário atual, acesso CLI e janela. O MCP continua disponível para leituras
de catálogo/histórico; seu apply_migration não expõe version e não é o
transporte selecionado nesta proposta. Não renomear a fonte canônica pelo
timestamp MCP nem fazer migration repair automaticamente. DDL também não
passa por execute_sql, SQL editor ou chamada genérica /database/query.

A migration contém transação, advisory lock da política interna de Auth,
`lock_timeout='5s'`, `statement_timeout='60s'`, preflight do corpo anterior,
schema/metadata/ACL e pós-condições antes do COMMIT. Falta de qualquer
pré-condição mantém este pacote não executável.

## Aceite posterior e risco operacional

Exigir confirmação da aplicação/COMMIT e histórico nominal; corpo posterior
exatamente igual ao hash final local, owner/metadata/ACL preservados e nenhum
grant adicional. Uma resposta ambígua não autoriza retry: primeiro reconciliar
histórico e catálogo em leitura. Verificar erros/latência do fluxo de contexto
no recorte, sem extrair logs pessoais ou credenciais.

Sessões já existentes cujo AMR não contenha password, inclusive OTP/recovery,
perdem acesso ao contexto interno e precisam de novo login por senha. A
migration não revoga essas sessões no Auth nem impede o endpoint legítimo de
reset. Não estimar quantidade afetada sem evidência nem consultar contas do
Owner para fabricá-la. Controles antigos de realm, tenant e capability seguem
obrigatórios; teste com persona sintética só usa autorização do pacote
independente. Enquanto essa prova remota estiver pendente, não declarar
backend `done` ou `verified-e2e`.

Em falha de preflight/lock/postcondition, registrar erro sanitizado e comparar
catálogo/histórico para confirmar se houve commit. Em regressão após commit,
interromper a promoção, preservar evidência e preparar correção **forward-only**
com novo nome, revisão, testes e autorização nominal. Não reaplicar migration
antiga, remover a exigência password ou editar a migration já registrada como
compensação automática. Nenhuma alteração de conta Owner ou mailbox integra
a recuperação deste pacote.

Responsável pela aplicação/serialização: D00 e executor nominal designado.
Responsável pelos hashes/provas locais: executor backend D01. Knowledge:
no-op nesta proposta, sem nova regra de produto aprovada.
