from pathlib import Path
import json
root=Path('C:/Users/adrie/Documents/Coelo')
source=(root/'packages/coelo_database/supabase/tests/superadmin_assessments_internal_v2_test.sql').read_text(encoding='utf-8-sig')
fixture=source[source.index('-- Synthetic tenant'):source.index('create temporary table assessment_context_result')]
payload=json.loads((root/'docs/reviews/evidence/etapa-2/r11-coordenacao/assessment-update-red.json').read_text())['request']['payload']
payload.update(activity_id='8d200000-0000-4000-8000-000000000701',institution_id='8d200000-0000-4000-8000-000000000010',unit_id='8d200000-0000-4000-8000-000000000011')
sql="begin; create extension if not exists pgtap with schema extensions; select plan(8);\n"+fixture
sql+="\ncreate temporary table r11_payload as select '"+json.dumps(payload).replace("'","''")+"'::jsonb as value;\n"
sql+='''
create temporary table r11_active as select public.superadmin_assessment_save_configuration(gen_random_uuid(),null,0,value) body from r11_payload;
select is((select body->>'ok' from r11_active),'true','create first configuration');
select public.superadmin_assessment_activate_configuration(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_active),1);
create temporary table r11_book as select public.superadmin_assessment_save_gradebook(gen_random_uuid(),null,0,jsonb_build_object(
 'activity_group_link_id','8d200000-0000-4000-8000-000000000712',
 'period_id',(select id from public.assessment_periods where configuration_id=(select (body#>>'{data,id}')::uuid from r11_active)),
 'configuration_id',(select body#>>'{data,id}' from r11_active),'students','[]'::jsonb),null) body;
select is((select body->>'ok' from r11_book),'true','retained gradebook references active configuration');
create temporary table r11_draft as select public.superadmin_assessment_save_configuration(gen_random_uuid(),null,0,value) body from r11_payload;
select is((select body->>'ok' from r11_draft),'true','create second retained draft');
create temporary table r11_updated as select public.superadmin_assessment_save_configuration(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_draft),1,value) body from r11_payload;
select is((select body->>'ok' from r11_updated),'true','update same draft succeeds beside active gradebook');
select is((select body#>>'{data,id}' from r11_updated),(select body#>>'{data,id}' from r11_draft),'update preserves draft identity');
select is((select management_version::integer from public.activity_assessment_configurations where id=(select (body#>>'{data,id}')::uuid from r11_draft)),2,'draft version advances once');
select is((select count(*)::integer from public.assessment_periods where configuration_id=(select (body#>>'{data,id}')::uuid from r11_active)),1,'active configuration period survives draft update');
select set_config('request.jwt.claims',jsonb_build_object('sub','8d200000-0000-4000-8000-000000000102','session_id','8d200000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
select ok((select public.superadmin_assessment_save_configuration(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_draft),2,value || jsonb_build_object('institution_id','8d200000-0000-4000-8000-000000000020','unit_id','8d200000-0000-4000-8000-000000000021','activity_id','8d200000-0000-4000-8000-000000000702'))->>'ok' from r11_payload)='false','institution-scoped actor cannot move draft across tenants');
select * from finish(); rollback;
'''
out=root/'packages/coelo_database/candidatos/r11-estrutura/assessment-update-isolation-test.sql'
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(sql,encoding='utf-8')
print(out.relative_to(root).as_posix())
