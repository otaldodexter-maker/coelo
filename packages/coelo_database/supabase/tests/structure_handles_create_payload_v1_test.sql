-- Decisao 16 (complemento sobre 20260911180000): @ opcional na criacao de
-- turma, unidade e atividade; padrao hierarquico quando ausente; detail_v2
-- de Unidades e Turmas devolvem o @.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into public.institution_types(id,code,name,status) values
 ('9f0a0000-0000-4000-8000-000000000001','handles-payload','Handles payload','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f0a0000-0000-4000-8000-000000000010','Escola Aurora','escolaaurora','active','9f0a0000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status) values ('9f0a0000-0000-4000-8000-000000000002','hp-unit','Unidade HP','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('9f0a0000-0000-4000-8000-000000000011','9f0a0000-0000-4000-8000-000000000010','9f0a0000-0000-4000-8000-000000000002','Centro','centro','active','centro.escolaaurora');
insert into public.activity_taxonomies(id,code,name,status,taxonomy_kind) values
 ('9f0a0000-0000-4000-8000-000000000003','hp-esporte','Esporte HP','active','category');

-- identidade interna owner de plataforma (a ponte 220400 cria a pessoa de servico e a
-- platform_membership espelhada, entao current_person_id/has_platform_permission resolvem)
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f0a0000-0000-4000-8000-000000000101','authenticated','authenticated','hp-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f0a0000-0000-4000-8000-000000000201','9f0a0000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f0a0000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f0a0000-0000-4000-8000-000000000401','9f0a0000-0000-4000-8000-000000000301','9f0a0000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f0a0000-0000-4000-8000-000000000501','9f0a0000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in ('groups.manage','units.create','units.read','groups.read','activities.create','activities.link_units','activities.read')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f0a0000-0000-4000-8000-000000000101','session_id','9f0a0000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);

create temporary table hp(label text primary key, body jsonb not null);

-- 1. turma: sem handle -> padrao @turma.unidade
insert into hp values('g1', app_private.superadmin_group_save('9f0a0000-0000-4000-8000-000000000901',null,0,
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","unit_id":"9f0a0000-0000-4000-8000-000000000011","name":"Turma Azul","group_type":"class"}'));
select is((select handle from public.groups where id=(select (body->>'id')::uuid from hp where label='g1')),'turmaazul.centro.escolaaurora',
  'turma sem @ recebe @nomedaturma.nomedaunidade');
-- 2. turma com handle escolhido
insert into hp values('g2', app_private.superadmin_group_save('9f0a0000-0000-4000-8000-000000000902',null,0,
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","unit_id":"9f0a0000-0000-4000-8000-000000000011","name":"Turma Verde","group_type":"class","handle":"@Verde.Centro"}'));
select is((select handle from public.groups where id=(select (body->>'id')::uuid from hp where label='g2')),'verde.centro','@ informado e normalizado e gravado');
-- 3. handle ocupado -> SAI_HANDLE_TAKEN
select throws_like($$select app_private.superadmin_group_save('9f0a0000-0000-4000-8000-000000000903',null,0,
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","unit_id":"9f0a0000-0000-4000-8000-000000000011","name":"Outra","group_type":"class","handle":"verde.centro"}')$$,
  '%handle already in use%','@ ja usado por outra turma e recusado');
select throws_like($$select app_private.superadmin_group_save('9f0a0000-0000-4000-8000-000000000904',null,0,
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","unit_id":"9f0a0000-0000-4000-8000-000000000011","name":"Outra","group_type":"class","handle":"centro.escolaaurora"}')$$,
  '%handle already in use%','@ de uma unidade nao pode virar @ de turma (unicidade global)');
select throws_like($$select app_private.superadmin_group_save('9f0a0000-0000-4000-8000-000000000905',null,0,
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","unit_id":"9f0a0000-0000-4000-8000-000000000011","name":"Outra","group_type":"class","handle":"coelo"}')$$,
  '%handle already in use%','@ reservado (coelo) e recusado');
-- 4. edicao: handle igual passa; diferente exige set_v1
create temporary table g2id as select (body->>'id')::uuid id, (body->>'management_version')::bigint v from hp where label='g2';
insert into hp values('g2edit', app_private.superadmin_group_save('9f0a0000-0000-4000-8000-000000000906',(select id from g2id),(select v from g2id),
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","unit_id":"9f0a0000-0000-4000-8000-000000000011","name":"Turma Verde 2","group_type":"class","handle":"verde.centro"}'));
select is((select name from public.groups where id=(select id from g2id)),'Turma Verde 2','edicao com o mesmo @ passa');
select throws_like($$select app_private.superadmin_group_save('9f0a0000-0000-4000-8000-000000000907',(select id from g2id),(select v+1 from g2id),
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","unit_id":"9f0a0000-0000-4000-8000-000000000011","name":"Turma Verde 3","group_type":"class","handle":"verde.novo"}')$$,
  '%superadmin_structure_handle_set_v1%','trocar o @ pela edicao e recusado (usa set_v1 com trava de 30 dias)');

-- 5. unidade: sem handle -> @unidade.instituicao; com handle -> gravado; colisao -> sufixo
insert into hp values('u1', app_private.create_unit_for_superadmin('9f0a0000-0000-4000-8000-000000000911',
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","name":"Zona Norte","slug":"zona-norte","unit_type_id":"9f0a0000-0000-4000-8000-000000000002"}'));
select is((select handle from public.units where slug='zona-norte' and institution_id='9f0a0000-0000-4000-8000-000000000010'),'zonanorte.escolaaurora',
  'unidade sem @ recebe @nomedaunidade.nomedainstituicao');
insert into hp values('u2', app_private.create_unit_for_superadmin('9f0a0000-0000-4000-8000-000000000912',
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","name":"Zona Sul","slug":"zona-sul","unit_type_id":"9f0a0000-0000-4000-8000-000000000002","handle":"@Sul.Aurora"}'));
select is((select handle from public.units where slug='zona-sul'),'sul.aurora','@ informado na unidade e normalizado e gravado');
select throws_like($$select app_private.create_unit_for_superadmin('9f0a0000-0000-4000-8000-000000000913',
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","name":"Zona Leste","slug":"zona-leste","unit_type_id":"9f0a0000-0000-4000-8000-000000000002","handle":"verde.centro"}')$$,
  '%handle already in use%','@ de turma nao pode virar @ de unidade');
insert into hp values('u3', app_private.create_unit_for_superadmin('9f0a0000-0000-4000-8000-000000000914',
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","name":"Zona Norte","slug":"zona-norte-2","unit_type_id":"9f0a0000-0000-4000-8000-000000000002"}'));
select ok((select handle ~ '^zonanorte\.escolaaurora_[0-9a-f]{4}$' from public.units where slug='zona-norte-2'),'colisao do padrao recebe sufixo curto');

-- 6. atividade: handle opcional vira handle_stem; canonical continua stem.instituicao
insert into hp values('a1', public.superadmin_activity_create_v2('9f0a0000-0000-4000-8000-000000000921',
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","name":"Natação Infantil","initials":"NI","taxonomy_id":"9f0a0000-0000-4000-8000-000000000003","unit_ids":["9f0a0000-0000-4000-8000-000000000011"],"handle":"@Nadar.Centro"}'));
select is((select body->>'ok' from hp where label='a1'),'true','atividade criada com @ opcional');
select is((select canonical_handle from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from hp where label='a1')),'nadar.escolaaurora',
  'primeiro segmento do @ vira handle_stem e o canonical segue stem.instituicao');
insert into hp values('a2', public.superadmin_activity_create_v2('9f0a0000-0000-4000-8000-000000000922',
  '{"institution_id":"9f0a0000-0000-4000-8000-000000000010","name":"Judô","initials":"JU","taxonomy_id":"9f0a0000-0000-4000-8000-000000000003","unit_ids":["9f0a0000-0000-4000-8000-000000000011"]}'));
select is((select canonical_handle from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from hp where label='a2')),'judo.escolaaurora',
  'sem @ o padrao continua o slug do nome');

-- 7. detalhes devolvem o @
select is((select app_private.superadmin_group_detail_payload_v2((select id from g2id))->>'handle'),'verde.centro','detail_v2 da turma devolve handle');
select is((select app_private.superadmin_group_detail_payload_v2((select id from g2id))#>>'{unit,handle}'),'centro.escolaaurora','detail_v2 da turma devolve o @ da unidade');
select is((select app_private.superadmin_unit_detail_payload_v2('9f0a0000-0000-4000-8000-000000000011')->>'handle'),'centro.escolaaurora','detail_v2 da unidade devolve handle');
select ok((select app_private.superadmin_unit_detail_payload_v2('9f0a0000-0000-4000-8000-000000000011') ? 'handle_last_changed_at'),'detail_v2 da unidade devolve handle_last_changed_at');

select * from finish();
rollback;
