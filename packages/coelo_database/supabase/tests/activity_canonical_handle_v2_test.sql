-- Prova pgTAP da migration 20260920030000_activity_canonical_handle_v2 (lote 98).
-- Fixture com rollback total (prefixo 9c8): owner interno, instituicao "ch-inst" (slug com hifen).
-- Cobre o nascimento dos tres @ (unidade, turma, atividade nos dois escopos), unicidade global,
-- disponibilidade enquanto digita, cooldown de 30 dias, propagacao da troca do @ da unidade e o
-- backfill das atividades legadas sem perder o alias.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into public.institution_types(id,code,name,status) values ('9c800000-0000-4000-8000-000000000001','ch-test','CH test','active');
insert into public.unit_types(id,code,name,status) values ('9c800000-0000-4000-8000-000000000002','ch-unit','CH unit','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c800000-0000-4000-8000-000000000010','CH Instituicao','ch-inst','active','9c800000-0000-4000-8000-000000000001');
insert into public.activity_taxonomies(id,code,name,status,taxonomy_kind) values
 ('9c800000-0000-4000-8000-000000000003','ch-esporte','Esporte CH','active','category');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c800000-0000-4000-8000-000000000101','authenticated','authenticated','ch-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c800000-0000-4000-8000-000000000201','9c800000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9c800000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c800000-0000-4000-8000-000000000401','9c800000-0000-4000-8000-000000000301','9c800000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9c800000-0000-4000-8000-000000000501','9c800000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9c800000-0000-4000-8000-000000000101',
 'session_id','9c800000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);

create temporary table r(label text primary key, body jsonb not null);

-- 1. @ da unidade nasce sem hifen a partir do nome e do slug da instituicao
insert into r values('u1', app_private.create_unit_for_superadmin('9c800000-0000-4000-8000-000000000901',
  '{"institution_id":"9c800000-0000-4000-8000-000000000010","name":"CH Unidade","slug":"ch-unidade","unit_type_id":"9c800000-0000-4000-8000-000000000002"}'));
select is((select handle from public.units where slug='ch-unidade'),'chunidade.chinst','@ da unidade: nomedaunidade.instituicao sem hifen');

-- 2. @ da turma nasce a partir do @ real da unidade
insert into public.groups(id,institution_id,unit_id,name,status,management_version) values
 ('9c800000-0000-4000-8000-000000000030','9c800000-0000-4000-8000-000000000010',(select id from public.units where slug='ch-unidade'),'CH Turma','active',1);
select is((select handle from public.groups where id='9c800000-0000-4000-8000-000000000030'),'chturma.chunidade.chinst','@ da turma: nomedaturma.@daunidade');

-- 3. atividade criada pela instituicao: stem.@dainstituicao, stem sem hifen
insert into r values('a1', public.superadmin_activity_create_v2('9c800000-0000-4000-8000-000000000911',
  jsonb_build_object('institution_id','9c800000-0000-4000-8000-000000000010','name','Educação Física','initials','EF',
    'taxonomy_id','9c800000-0000-4000-8000-000000000003','unit_ids',jsonb_build_array((select id from public.units where slug='ch-unidade')))));
select is((select body->>'ok' from r where label='a1'),'true','atividade criada');
select is((select canonical_handle from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from r where label='a1')),
  'educacaofisica.ch-inst','@ padrao da atividade: segmento do nome + @ da instituicao');

-- 4. @ explicito: primeiro segmento normalizado, restante ignorado
insert into r values('a2', public.superadmin_activity_create_v2('9c800000-0000-4000-8000-000000000912',
  jsonb_build_object('institution_id','9c800000-0000-4000-8000-000000000010','name','Xadrez','initials','XA','handle','@Xadrez Avançado.ch-inst',
    'taxonomy_id','9c800000-0000-4000-8000-000000000003','unit_ids',jsonb_build_array((select id from public.units where slug='ch-unidade')))));
select is((select canonical_handle from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from r where label='a2')),
  'xadrezavancado.ch-inst','@ explicito vira stem sem acento/espaco + @ da instituicao');

-- 5. @ explicito repetido -> SAI_HANDLE_TAKEN; nome repetido -> sufixo curto
insert into r values('a3', public.superadmin_activity_create_v2('9c800000-0000-4000-8000-000000000913',
  jsonb_build_object('institution_id','9c800000-0000-4000-8000-000000000010','name','Xadrez 2','initials','X2','handle','xadrezavancado',
    'taxonomy_id','9c800000-0000-4000-8000-000000000003','unit_ids',jsonb_build_array((select id from public.units where slug='ch-unidade')))));
select is((select body#>>'{error,code}' from r where label='a3'),'SAI_HANDLE_TAKEN','@ explicito repetido e recusado');
insert into r values('a4', public.superadmin_activity_create_v2('9c800000-0000-4000-8000-000000000914',
  jsonb_build_object('institution_id','9c800000-0000-4000-8000-000000000010','name','Educação Física','initials','EF',
    'taxonomy_id','9c800000-0000-4000-8000-000000000003','unit_ids',jsonb_build_array((select id from public.units where slug='ch-unidade')))));
select diag((select body::text from r where label='a3'));
select diag((select body::text from r where label='a4'));
select ok((select canonical_handle ~ '^educacaofisica_[0-9a-f]{8}\.ch-inst$' from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from r where label='a4')),
  'colisao do @ padrao ganha sufixo curto');

-- 6. atividade criada pela unidade: stem.@daunidade
insert into public.activity_definitions(id,institution_id,name,origin_scope_kind,origin_unit_id,status,taxonomy_id,handle_stem,identity_mode,identity_initials,identity_color)
values('9c800000-0000-4000-8000-000000000040','9c800000-0000-4000-8000-000000000010','Yoga','unit',(select id from public.units where slug='ch-unidade'),'draft',
  '9c800000-0000-4000-8000-000000000003','Yoga','initials','YO','#D63C00');
select is((select canonical_handle from public.activity_definitions where id='9c800000-0000-4000-8000-000000000040'),'yoga.chunidade.chinst','@ da atividade da unidade: stem.@daunidade');

-- 7. disponibilidade enquanto digita (@ completo) e unicidade cruzada
insert into r values('av1', public.superadmin_structure_handle_availability_v1('activity','educacaofisica.ch-inst',null));
select is((select body#>>'{data,reason}' from r where label='av1'),'HANDLE_TAKEN','availability: @ completo de atividade em uso');
insert into r values('av2', public.superadmin_structure_handle_availability_v1('activity','@Nova.ch-inst',null));
select is((select body#>>'{data,available}' from r where label='av2'),'true','availability: @ completo livre');
insert into r values('av3', public.superadmin_structure_handle_availability_v1('activity','edu-fisica',null));
select is((select body#>>'{data,reason}' from r where label='av3'),'HANDLE_INVALID','availability: stem com hifen e invalido');
insert into r values('av4', public.superadmin_structure_handle_availability_v1('group','yoga.chunidade.chinst',null));
select is((select body#>>'{data,reason}' from r where label='av4'),'HANDLE_TAKEN','turma nao pode tomar o @ de uma atividade');
insert into r values('av5', public.superadmin_structure_handle_availability_v1('unit','chunidade.chinst',null));
select is((select body#>>'{data,reason}' from r where label='av5'),'HANDLE_TAKEN','unidade: @ em uso');

-- 8. troca do @ da atividade: recompoe, guarda alias, cooldown de 30 dias
insert into r values('s1', public.superadmin_structure_handle_set_v1('9c800000-0000-4000-8000-000000000921','activity','9c800000-0000-4000-8000-000000000040',
  (select management_version from public.activity_definitions where id='9c800000-0000-4000-8000-000000000040'),'@Yoga-Kids'));
select is((select body#>>'{data,handle}' from r where label='s1'),'yogakids','set_v1: stem normalizado sem hifen');
select is((select canonical_handle from public.activity_definitions where id='9c800000-0000-4000-8000-000000000040'),'yogakids.chunidade.chinst','set_v1: canonical recomposto');
select ok(exists(select 1 from public.activity_handle_aliases where activity_id='9c800000-0000-4000-8000-000000000040' and alias='yoga.chunidade.chinst'),'@ antigo vira alias');
insert into r values('s2', public.superadmin_structure_handle_set_v1('9c800000-0000-4000-8000-000000000922','activity','9c800000-0000-4000-8000-000000000040',
  (select management_version from public.activity_definitions where id='9c800000-0000-4000-8000-000000000040'),'yogateen'));
select is((select body#>>'{error,code}' from r where label='s2'),'SAI_HANDLE_COOLDOWN','segunda troca em 30 dias: SAI_HANDLE_COOLDOWN');
select ok((select (body#>>'{error,next_allowed_at}')::timestamptz > now() + interval '29 days' from r where label='s2'),'cooldown informa next_allowed_at');
-- @ ja usado por outra atividade da instituicao
insert into r values('s3', public.superadmin_structure_handle_set_v1('9c800000-0000-4000-8000-000000000923','activity',
  (select (body#>>'{data,activity_id}')::uuid from r where label='a1'),
  (select management_version from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from r where label='a1')),'xadrezavancado'));
select is((select body#>>'{error,code}' from r where label='s3'),'SAI_HANDLE_TAKEN','set_v1: @ completo repetido e recusado');
-- alias reservado: ninguem toma o @ antigo da atividade
insert into r values('av6', public.superadmin_structure_handle_availability_v1('group','yoga.chunidade.chinst',null));
select is((select body#>>'{data,reason}' from r where label='av6'),'HANDLE_TAKEN','alias de atividade continua reservado');

-- 9. troca do @ da unidade propaga para a atividade da unidade (alias preservado)
insert into r values('su', public.superadmin_structure_handle_set_v1('9c800000-0000-4000-8000-000000000924','unit',(select id from public.units where slug='ch-unidade'),
  (select management_version from public.units where slug='ch-unidade'),'novaunidade.chinst'));
select is((select body#>>'{data,handle}' from r where label='su'),'novaunidade.chinst','@ da unidade trocado');
select is((select canonical_handle from public.activity_definitions where id='9c800000-0000-4000-8000-000000000040'),'yogakids.novaunidade.chinst','@ da atividade acompanha o @ da unidade');
select ok(exists(select 1 from public.activity_handle_aliases where activity_id='9c800000-0000-4000-8000-000000000040' and alias='yogakids.chunidade.chinst'),'@ anterior da atividade vira alias na troca da unidade');

-- 10. backfill: atividade legada (stem com hifen, canonical stem.slug.slug) recebe o @ novo e guarda o alias
set constraints all immediate;
alter table public.activity_definitions drop constraint activity_definitions_handle_check;
alter table public.activity_definitions disable trigger activity_canonical_handle_before;
insert into public.activity_definitions(id,institution_id,name,origin_scope_kind,origin_unit_id,status,taxonomy_id,handle_stem,canonical_handle,identity_mode,identity_initials,identity_color)
values('9c800000-0000-4000-8000-000000000041','9c800000-0000-4000-8000-000000000010','Ballet Clássico','unit',(select id from public.units where slug='ch-unidade'),'draft',
  '9c800000-0000-4000-8000-000000000003','ballet-classico','ballet-classico.ch-unidade.ch-inst','initials','BC','#D63C00');
alter table public.activity_definitions enable trigger activity_canonical_handle_before;
set constraints all immediate;
select is(app_private.activity_canonical_handle_backfill_v2(),1,'backfill toca so a atividade legada');
select is((select canonical_handle from public.activity_definitions where id='9c800000-0000-4000-8000-000000000041'),'balletclassico.novaunidade.chinst','backfill: @ novo sem hifen com @ real da unidade');
select ok(exists(select 1 from public.activity_handle_aliases where activity_id='9c800000-0000-4000-8000-000000000041' and alias='ballet-classico.ch-unidade.ch-inst'),'backfill: @ antigo vira alias');

select * from finish();
rollback;
