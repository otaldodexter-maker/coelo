-- Prova pgTAP do candidato 20260911220000_daily_routine_directory_can_manage_v1
-- (F-R04-FCR-009): public.superadmin_routine_directory devolve `can_manage`
-- no topo do envelope, derivado de routine.manage_models, mesmo com o
-- diretorio vazio. Fixture sintetica (person_auth_links + platform_membership
-- em papeis temporarios), rollback total.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.rd_id(n integer) returns uuid language sql immutable as $$
  select ('8f1a0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.rd_id(integer) to authenticated, anon;

select has_function('public','superadmin_routine_directory',array['text','text','text','uuid','uuid','uuid','integer','integer'],'public.superadmin_routine_directory exists');
select ok(has_function_privilege('authenticated','public.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)','execute'),'authenticated can call the directory');
select ok(not has_function_privilege('anon','public.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)','execute'),'anon has no grant on the directory');
select ok(pg_get_functiondef('app_private.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)'::regprocedure) like '%''can_manage''%','app_private body projects can_manage');

-- Usuarios 121/122 -> pessoas 221 (gestor de modelos) e 222 (somente leitura).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.rd_id(n),'authenticated','authenticated','rd-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from unnest(array[121,122]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.rd_id(n),'adult','RD','Pessoa','RD pessoa '||n,'active' from unnest(array[221,222]) n;
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.rd_id(221),pg_temp.rd_id(121),'active'),(pg_temp.rd_id(222),pg_temp.rd_id(122),'active');

-- Papeis de plataforma temporarios: rd_manager (routine.read + routine.manage_models)
-- e rd_reader (so routine.read).
insert into public.platform_roles(id,code,name,status,max_scope_kind) values
 (pg_temp.rd_id(40),'rd_manager','RD gestor de rotina','active','platform'),
 (pg_temp.rd_id(41),'rd_reader','RD leitor de rotina','active','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.rd_id(40),p.id,'allow'::public.permission_effect,'active' from public.platform_permissions p where p.code in('routine.read','routine.manage_models');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.rd_id(41),p.id,'allow'::public.permission_effect,'active' from public.platform_permissions p where p.code='routine.read';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required) values
 (pg_temp.rd_id(221),pg_temp.rd_id(40),'active','platform',false),
 (pg_temp.rd_id(222),pg_temp.rd_id(41),'active','platform',false);

create temporary table rd(key text primary key,value jsonb);
grant select,insert on rd to authenticated;

-- (2) gestor: can_manage true com diretorio vazio.
select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into rd values('manager_model',public.superadmin_routine_directory('model','',null,null,null,null,20,0));
insert into rd values('manager_application',public.superadmin_routine_directory('application','',null,null,null,null,20,0));
insert into rd values('manager_launch',public.superadmin_routine_directory('launch','',null,null,null,null,20,0));
reset role;
-- (1) envelope
select ok((select value ? 'can_manage' from rd where key='manager_model'),'model directory envelope has can_manage');
select ok((select (select array_agg(k order by k) from jsonb_object_keys(value) k)=array['can_manage','items','limit','offset','total'] from rd where key='manager_model'),'envelope keeps items/total/limit/offset and adds can_manage');
select is((select jsonb_typeof(value->'can_manage') from rd where key='manager_model'),'boolean','can_manage is a boolean');
select is((select jsonb_array_length(value->'items') from rd where key='manager_model'),0,'directory is empty for the synthetic actor');
select is((select value->>'can_manage' from rd where key='manager_model'),'true','routine.manage_models actor gets can_manage true on an empty directory');
select is((select value->>'can_manage' from rd where key='manager_application'),'true','application directory carries can_manage too');
select is((select value->>'can_manage' from rd where key='manager_launch'),'true','launch directory carries can_manage too');

-- (3) leitor: can_manage false.
select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000122","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into rd values('reader_model',public.superadmin_routine_directory('model','',null,null,null,null,20,0));
reset role;
select ok((select value ? 'can_manage' from rd where key='reader_model'),'reader still receives the key');
select is((select value->>'can_manage' from rd where key='reader_model'),'false','routine.read only actor gets can_manage false');

-- Sem sessao: negado.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok('select public.superadmin_routine_directory(''model'','''',null,null,null,null,20,0)','42501',null,'no session is denied');
reset role;

-- (4) anon 42501.
set local role anon;
select throws_ok('select public.superadmin_routine_directory(''model'','''',null,null,null,null,20,0)','42501',null,'anon cannot execute the directory');
reset role;

select * from finish();
rollback;
