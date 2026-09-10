-- Alunos: contrato dos quatro comandos de vinculo.
begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

select has_table('app_private','student_link_command_receipts','recibos de comando');

select has_function('public','superadmin_student_link', array['uuid','uuid','jsonb'],
  'vincular tem comando proprio');
select has_function('public','superadmin_student_transfer', array['uuid','uuid','jsonb'],
  'transferir tem comando proprio');
select has_function('public','superadmin_student_edit', array['uuid','uuid','jsonb'],
  'editar tem comando proprio');
select has_function('public','superadmin_student_revoke', array['uuid','uuid','jsonb'],
  'revogar tem comando proprio');

select ok(
  not exists (
    select 1
    from (values
      ('superadmin_student_link'),('superadmin_student_transfer'),
      ('superadmin_student_edit'),('superadmin_student_revoke')
    ) as command(name)
    where has_function_privilege(
      'anon', 'public.'||command.name||'(uuid,uuid,jsonb)', 'EXECUTE')
  ),
  'anonimo nao executa comando nenhum de aluno'
);

select ok(
  (select bool_and(
     has_function_privilege('authenticated', 'public.'||command.name||'(uuid,uuid,jsonb)', 'EXECUTE'))
   from (values
     ('superadmin_student_link'),('superadmin_student_transfer'),
     ('superadmin_student_edit'),('superadmin_student_revoke')
   ) as command(name)),
  'sessao autenticada alcanca os quatro'
);

select ok(
  not has_table_privilege('anon','app_private.student_link_command_receipts','SELECT')
  and not has_table_privilege('authenticated',
    'app_private.student_link_command_receipts','SELECT'),
  'os recibos ficam fora do alcance do cliente'
);

select ok(
  not has_function_privilege(
    'authenticated','app_private.student_link_require_scope(uuid,uuid,uuid)','EXECUTE'),
  'o auxiliar de escopo nao e chamavel pelo cliente'
);

-- --------------------------------------------------------------------------
-- Autorizacao: o que impede mover uma crianca para o tenant errado
-- --------------------------------------------------------------------------

-- A instituicao e derivada do contexto infantil. Aceitar a instituicao enviada
-- pelo cliente permitiria mover a crianca de um tenant para outro.
select ok(
  pg_get_functiondef(
    'app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure)
    like '%from public.child_contexts child_row%'
  and pg_get_functiondef(
    'app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure)
    not like '%p_institution_id%',
  'a instituicao vem do contexto infantil e nunca do payload'
);

select ok(
  pg_get_functiondef(
    'app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure)
    like '%unit_row.institution_id = institution%'
  and pg_get_functiondef(
    'app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure)
    like '%group_row.unit_id = p_unit_id%',
  'unidade e turma sao conferidas contra a instituicao da crianca'
);

select ok(
  pg_get_functiondef(
    'app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure)
    like '%people.assign_children required%',
  'a capacidade exigida e people.assign_children'
);

select ok(
  (select count(*) from regexp_matches(
     pg_get_functiondef(
       'app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure),
     'student link unavailable', 'g')) >= 3,
  'crianca ausente, unidade de outro tenant e turma de outra unidade recebem a mesma negativa opaca'
);

-- Transferir autoriza os dois lados: quem so pode gerir o destino nao pode
-- retirar a crianca da origem.
select ok(
  (select count(*) from regexp_matches(
     pg_get_functiondef(
       'app_private.superadmin_student_transfer(uuid,uuid,jsonb)'::regprocedure),
     'student_link_require_scope', 'g')) = 2,
  'transferir autoriza a unidade de origem e a de destino'
);

-- --------------------------------------------------------------------------
-- Regras de dominio
-- --------------------------------------------------------------------------

select ok(
  pg_get_functiondef(
    'app_private.superadmin_student_transfer(uuid,uuid,jsonb)'::regprocedure)
    like '%transfer reason required%'
  and pg_get_functiondef(
    'app_private.superadmin_student_revoke(uuid,uuid,jsonb)'::regprocedure)
    like '%revoke reason required%',
  'transferir e revogar exigem motivo'
);

-- Uma crianca transferida deixa de pertencer as turmas da unidade que deixou,
-- senao continuaria aparecendo em chamada e rotina de onde ja nao esta.
select ok(
  pg_get_functiondef(
    'app_private.superadmin_student_transfer(uuid,uuid,jsonb)'::regprocedure)
    like '%update public.child_group_links set%',
  'transferir encerra as turmas da unidade de origem'
);

-- Revogar nao apaga: o historico continua legivel para auditoria.
select ok(
  pg_get_functiondef(
    'app_private.superadmin_student_revoke(uuid,uuid,jsonb)'::regprocedure)
    not like '%delete from%'
  and pg_get_functiondef(
    'app_private.superadmin_student_revoke(uuid,uuid,jsonb)'::regprocedure)
    like '%status = ''revoked'', revoked_at = now()%',
  'revogar marca e carimba, sem apagar'
);

select ok(
  (select bool_and(
     pg_get_functiondef(('app_private.'||command.name||'(uuid,uuid,jsonb)')::regprocedure)
       like '%insert into audit.audit_logs%')
   from (values
     ('superadmin_student_link'),('superadmin_student_transfer'),
     ('superadmin_student_edit'),('superadmin_student_revoke')
   ) as command(name)),
  'os quatro comandos gravam auditoria'
);

select ok(
  (select bool_and(
     pg_get_functiondef(('app_private.'||command.name||'(uuid,uuid,jsonb)')::regprocedure)
       like '%student_link_receipt(p_request_id%')
   from (values
     ('superadmin_student_link'),('superadmin_student_transfer'),
     ('superadmin_student_edit'),('superadmin_student_revoke')
   ) as command(name)),
  'os quatro comandos reconhecem a repeticao pelo recibo'
);

set local role anon;
select throws_ok(
  $call$select public.superadmin_student_link(
    '10000000-0000-4000-8000-000000000001'::uuid,
    '10000000-0000-4000-8000-000000000002'::uuid,
    '{}'::jsonb)$call$,
  '42501', null, 'anonimo nao vincula'
);

reset role;
select * from finish();
rollback;
