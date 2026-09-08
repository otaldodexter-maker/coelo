---
title: "LOC-LOCK01 — protocolo controlado de reautorização após espera"
source: "LOC-CATALOG01; revisão da coordenação; protocolo readonly independente"
status: "prepared-not-executed-engineer1-selection-required"
generated_at: "2026-09-07"
---

# Protocolo local de duas conexões

Somente Engineer1 executa no banco local descartável selecionado. Não é lease
remota. Não alterar helpers Auth, conceder capabilities em produção nem remover
auditorias. O setup usa as fixtures sintéticas da suíte authorization: Owner
institucional `81500000-0000-4000-8000-000000000001`, membership
`81700000-0000-4000-8000-000000000001`, instituições A/B `81100000-0000-4000-8000-000000000001`
e `81100000-0000-4000-8000-000000000002`, Auth user `81300000-0000-4000-8000-000000000001`
e sessão `81400000-0000-4000-8000-000000000001`.

O harness deve materializar e COMMITAR somente esse setup nominal antes das
duas conexões. Rodar a suíte pgTAP que termina em rollback não deixa essas
fixtures disponíveis. Engineer1 registra hashes e ordem de setup no perfil;
esta proposta não modifica o harness compartilhado automaticamente.

## Seis casos independentes

| Caso | request_id | Payload name | Preparação | Mutação durante espera | Negativa esperada |
| --- | --- | --- | --- | --- | --- |
| membership-new | `81800000-0000-4000-8000-000000000021` | Race membership new | sem receipt | membership revoked | SAI_MEMBERSHIP_REVOKED |
| membership-replay | `81800000-0000-4000-8000-000000000022` | Race membership replay | criar/commitar receipt antes | membership revoked | SAI_MEMBERSHIP_REVOKED |
| capability-new | `81800000-0000-4000-8000-000000000023` | Race capability new | sem receipt | grant inativo | SAI_PERMISSION_DENIED |
| capability-replay | `81800000-0000-4000-8000-000000000024` | Race capability replay | criar/commitar receipt antes | grant inativo | SAI_PERMISSION_DENIED |
| scope-new | `81800000-0000-4000-8000-000000000025` | Race scope new | sem receipt | escopo A para B | SAI_PERMISSION_DENIED |
| scope-replay | `81800000-0000-4000-8000-000000000026` | Race scope replay | criar/commitar receipt antes | escopo A para B | SAI_PERMISSION_DENIED |

Request e nome são parâmetros nominais do runner, nunca derivados de dados
reais. Todos usam scope_kind institution, institution_id A, unit_id null,
description/floor/address null, kind internal e visibility team.

## Ordem observável obrigatória

1. Registrar contagens e IDs de locais/receipts e auditorias location.create do
   ator. Casos replay exigem criação autorizada previamente confirmada e
   commitada, preservando payload e request exatos.
2. Conexão A postgres captura PID e adquire **lock de sessão** no hash
   `hashtextextended('81500000-0000-4000-8000-000000000001:' || request_id,0)`.
   Não usar lock transacional: A precisa commitar a revogação sem liberar o lock.
3. Conexão B registra PID, abre `BEGIN ISOLATION LEVEL READ COMMITTED`, define
   statement_timeout finito e claims sub/session_id acima, aal1/role authenticated;
   `SET LOCAL ROLE authenticated`. Chama create_v2 com payload nominal.
4. A exige **espera real comprovada**, não sleep presumido:
   pg_stat_activity(B).wait_event_type='Lock', pg_locks(B) com
   locktype='advisory' AND NOT granted e PID(A)=ANY(pg_blocking_pids(B)).
   Ausência de espera aborta o caso como não comprovado.
5. A executa e COMMita exatamente uma das mutações abaixo, ainda segurando o
   lock de sessão. A só libera o hash exato com pg_advisory_unlock após COMMIT.
6. B captura envelope sob o papel authenticated, então RESET ROLE antes de
   assertions TAP: ok=false, data=null, code conforme tabela. Exceção/timeout
   não substitui a negativa esperada. Confirmar que o request não retornou dados.
7. Comparar snapshots: nenhum novo local/receipt ou sucesso de auditoria;
   receipt anterior intacto. Registrar negativa de auditoria e verificar hash.
8. A restaura somente a mutação nominal e COMMITA. Para caso new, B repete o
   mesmo request após restauração e exige sucesso, provando que a negativa não
   consumiu o request. Encerrar B e liberar lock A antes do próximo caso.

## Mutações nominais da conexão A

Membership:

```sql
begin;
update app_private.superadmin_internal_memberships
set status='revoked',revoked_at=now(),suspended_at=null
where id='81700000-0000-4000-8000-000000000001';
commit;
```

Restauração: mesmo ID, status active, revoked_at/suspended_at null.

Capability:

```sql
begin;
update public.platform_role_permissions rp set status='inactive',revoked_at=now()
from public.platform_roles r,public.platform_permissions p
where rp.role_id=r.id and rp.permission_id=p.id
  and r.code='owner' and p.code='locations.create';
commit;
```

Restauração: mesmo role/permission nominal, status active, revoked_at null.

Escopo:

```sql
begin;
update app_private.superadmin_internal_memberships
set scope_institution_id='81100000-0000-4000-8000-000000000002'
where id='81700000-0000-4000-8000-000000000001';
commit;
```

Restauração: mesmo ID, scope_institution_id A. Exigir uma linha afetada por
cada mutação; qualquer cardinalidade diferente aborta, sem correção ampla.

## Limite e cleanup

### Expiração wall-clock durante espera

Repetir cada tipo de bloqueio acima substituindo a mutação por:

```sql
begin;
update auth.sessions set not_after=clock_timestamp()
where id='81400000-0000-4000-8000-000000000001';
commit;
```

Exigir uma linha afetada, espera já comprovada e retorno SAI_SESSION_INVALID,
sem dados/novo receipt. Restaurar o not_after nominal do setup antes do próximo
caso. A suíte authorization também prepara contraprova sem sleep: not_after
entre o início da transação e o próximo statement deve ser negado pelos três
gateways, embora now() transacional ainda seja anterior. Um caso de not_after
NULL confirma ausência de expiração; não se inventa duração nem se altera o
helper Auth global. Os demais gates globais de Auth não foram certificados.

### Contraprovas de leitura e locks posteriores ao advisory

Repetir membership/capability/escopo para detail e directory, substituindo o
lock de sessão pelo lock transacional de recurso abaixo. Capability de leitura
é `locations.read`, não create. A adquire o lock antes de B entrar na RPC,
comprova B bloqueado por seu PID e só então muta a autorização e COMMITA. Esse
COMMIT torna a revogação visível e libera o recurso atomicamente.

| RPC B | Lock prévio A | Resultado após mutação |
| --- | --- | --- |
| detail de fixture existente em A | SELECT desse activity_locations.id FOR UPDATE | negativa, data null, nenhuma auditoria de leitura success |
| directory institucional A | SELECT institutions.id=A FOR UPDATE | negativa, data null, nenhuma auditoria de leitura success |
| create com receipt existente | SELECT activity_locations.id do receipt FOR UPDATE | negativa, receipt intacto e nenhum success novo |

Para provar o último caso, o advisory lock deve estar livre; a espera observada
precisa ocorrer no recurso depois dele. Exigir pg_blocking_pids e lock não
concedido, sem presumir locktype advisory para os locks de linha/transação.
Snapshots, restauração nominal e TAP somente após RESET seguem os casos acima.
O isolamento incompatível tem suíte nominal própria
`superadmin_location_catalog_v2_isolation_test.sql`, com REPEATABLE READ e ator
interno válido; os três gateways devem recusar sem retornar dados ou receipt.

As provas acima são READ COMMITTED. Um segundo require_context não renova o
snapshot de REPEATABLE READ; não declarar esse isolamento coberto. A coordenação
aprovou precondição local READ COMMITTED para os três gateways, com envelope
seguro SAI_INVALID_ARGUMENT nos demais isolamentos, sem alterar defaults globais.

Em falha, rollback de transação B, unlock explícito do hash A e fechamento das
conexões. Engineer1 descarta o banco local conforme seu protocolo após
preservar evidência. Não apagar auditorias para obter cleanup verde. Protocolo
preparado e guards estáticos não são execução de concorrência nem entrega E2E.
