-- C02 / I003: synthetic rollback-only candidate; requires the nominal local
-- Forms + internal authoring + Acontece replay coordinated by C00.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.media_id(n integer) returns uuid language sql immutable as $$
  select ('8c020000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid;
$$;
insert into public.institution_types(id,code,name,status)
values(pg_temp.media_id(1),'c02-media-test','Synthetic media type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status)
select pg_temp.media_id(n),pg_temp.media_id(1),'Synthetic media '||n,'c02-media-'||n,'active'
from unnest(array[10,20]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.media_id(n),'adult','Synthetic','Media '||n,'Synthetic media '||n,'active'
from unnest(array[100,101]) n;
insert into app_private.superadmin_internal_identities(id) values(pg_temp.media_id(110));
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,
  created_by_person_id,updated_by_person_id)
select pg_temp.media_id(n),pg_temp.media_id(case when n = 220 then 20 else 10 end),
  'form',case when n = 240 then 'anonymous' else 'identified' end,'person',
  'Synthetic form '||n,pg_temp.media_id(100),pg_temp.media_id(100)
from unnest(array[210,220,240]) n;
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,
  created_by_internal_identity_id,updated_by_internal_identity_id)
values(pg_temp.media_id(230),pg_temp.media_id(10),'form','anonymous','person','Internal synthetic form',
  pg_temp.media_id(110),pg_temp.media_id(110));
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
select pg_temp.media_id(n+100),pg_temp.media_id(n),1,pg_temp.media_id(100)
from unnest(array[210,220,240]) n;
insert into public.form_versions(id,form_id,version_number,created_by_internal_identity_id)
values(pg_temp.media_id(330),pg_temp.media_id(230),1,pg_temp.media_id(110));
insert into public.form_sections(id,form_version_id,title,position)
select pg_temp.media_id(n+100),pg_temp.media_id(n),'Synthetic section',0
from unnest(array[310,320,330,340]) n;
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
select pg_temp.media_id(n+200),pg_temp.media_id(n),pg_temp.media_id(n+100),'photo','Synthetic photo',0
from unnest(array[310,320,330,340]) n;

-- Response reservations use the existing ownership realm, never a new actor.
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
select pg_temp.media_id(600+n),pg_temp.media_id(case when n=0 then 210 else 240 end),
  pg_temp.media_id(10),'Synthetic occurrence app '||n,pg_temp.media_id(100) from generate_series(0,1) n;
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
select pg_temp.media_id(610+n),pg_temp.media_id(600+n),'America/Sao_Paulo','2026-09-08 12:00'::timestamp,'once'
from generate_series(0,1) n;
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,
  scheduled_local,time_zone,opens_at,closes_at)
select pg_temp.media_id(620+n),pg_temp.media_id(600+n),pg_temp.media_id(610+n),pg_temp.media_id(10),
  pg_temp.media_id(case when n=0 then 210 else 240 end),pg_temp.media_id(case when n=0 then 310 else 340 end),
  '2026-09-08 12:00'::timestamp,'America/Sao_Paulo',now(),now()+interval '1 day' from generate_series(0,1) n;
insert into public.form_assets(id,institution_id,occurrence_id,item_id,prepared_by_person_id,
  anonymous_upload_secret_hash,storage_path,mime_type,expected_byte_length,expected_checksum_sha256)
select pg_temp.media_id(n),pg_temp.media_id(10),pg_temp.media_id(n-10),pg_temp.media_id(case when n=630 then 510 else 540 end),
  case when n = 630 then pg_temp.media_id(100) else null end,
  case when n = 631 then '$2b$12$'||repeat('a',53) else null end,
  '8c/'||pg_temp.media_id(n)::text,'image/png',100,repeat('a',64)
from unnest(array[630,631]) n;

-- One transaction creates the pending catalog entry and its authoritative use.
create function pg_temp.media_insert(n integer, patch jsonb default '{}'::jsonb, item integer default 510)
returns void language plpgsql as $$
declare data jsonb; asset public.media_assets;
begin
  data := jsonb_build_object('id',pg_temp.media_id(n),'institution_id',pg_temp.media_id(10),
    'form_id',pg_temp.media_id(210),'owner_person_id',pg_temp.media_id(100),
    'catalog_kind','form-image','media_purpose','question-image','storage_provider','r2',
    'bucket_id','coelo-media-prod','mime_type','image/png','byte_size',null,
    'original_name','','upload_request_id','synthetic-'||n,'status','pending') || patch;
  data := jsonb_build_object('object_key',
    'tenants/'||(data->>'institution_id')||'/forms/form/'||(data->>'form_id')||'/'
    ||(data->>'media_purpose')||'/'||(data->>'id')||'/original/'||pg_temp.media_id(n+10000)::text||'.png') || data;
  asset := jsonb_populate_record(null::public.media_assets,data);
  insert into public.media_assets(id,institution_id,post_id,owner_person_id,upload_request_id,
    storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,checksum_sha256,status,
    catalog_kind,form_id,source_form_asset_id,owner_internal_identity_id,media_purpose,pixel_width,pixel_height)
  values(asset.id,asset.institution_id,asset.post_id,asset.owner_person_id,asset.upload_request_id,
    asset.storage_provider,asset.bucket_id,asset.object_key,asset.original_name,asset.mime_type,asset.byte_size,
    asset.checksum_sha256,asset.status,asset.catalog_kind,asset.form_id,asset.source_form_asset_id,
    asset.owner_internal_identity_id,asset.media_purpose,asset.pixel_width,asset.pixel_height);
  insert into public.media_bindings(media_asset_id,form_version_id,item_id,purpose,position)
  values(asset.id,pg_temp.media_id(item-200),pg_temp.media_id(item),asset.media_purpose,0);
  set constraints all immediate;
  set constraints all deferred;
end;
$$;

select lives_ok($$select pg_temp.media_insert(1000)$$,'identified author catalog and typed binding persist');
select is((select byte_size from public.media_assets where id=pg_temp.media_id(1000)),null::bigint,
  'pending catalog does not misrepresent declared source size as measured master bytes');
select lives_ok($$select pg_temp.media_insert(1001,jsonb_build_object('form_id',pg_temp.media_id(230),
  'owner_person_id',null,'owner_internal_identity_id',pg_temp.media_id(110)),530)$$,
  'internal author uses internal identity without artificial People');
select lives_ok($$select pg_temp.media_insert(1002,jsonb_build_object('media_purpose','answer-image',
  'source_form_asset_id',pg_temp.media_id(630)))$$,'identified response preserves existing owner');
select lives_ok($$select pg_temp.media_insert(1003,jsonb_build_object('media_purpose','answer-image',
  'form_id',pg_temp.media_id(240),'source_form_asset_id',pg_temp.media_id(631),'owner_person_id',null),540)$$,
  'anonymous reservation needs no person identity');
select is((select owner_person_id from public.media_assets where id=pg_temp.media_id(1003)),null::uuid,
  'anonymous physical catalog contains no respondent person');

select throws_ok($$select pg_temp.media_insert(1010,jsonb_build_object('institution_id',pg_temp.media_id(20)))$$,
  '23514','media_catalog_scope_invalid','cross-institution asset is rejected');
select throws_ok($$select pg_temp.media_insert(1011,'{}',520)$$,
  '23514','media_catalog_binding_scope_invalid','cross-form item binding is rejected');
select throws_ok($$select pg_temp.media_insert(1012,jsonb_build_object('form_id',pg_temp.media_id(230)),530)$$,
  '23514','media_catalog_author_realm_invalid','person cannot be recorded as internal author');
select throws_ok($$select pg_temp.media_insert(1013,jsonb_build_object('owner_person_id',null,
  'owner_internal_identity_id',pg_temp.media_id(110)))$$,
  '23514','media_catalog_author_realm_invalid','internal identity cannot be recorded in person author realm');
select throws_ok($$select pg_temp.media_insert(1014,jsonb_build_object('media_purpose','answer-image',
  'form_id',pg_temp.media_id(240),'source_form_asset_id',pg_temp.media_id(631)),540)$$,
  '23514','media_catalog_response_owner_invalid','anonymous source cannot acquire a person identity');
select throws_ok($$select pg_temp.media_insert(1015,jsonb_build_object('media_purpose','answer-image',
  'source_form_asset_id',pg_temp.media_id(630),'owner_person_id',pg_temp.media_id(101)))$$,
  '23514','media_catalog_response_owner_invalid','another identified uploader cannot own source');
select throws_ok($$select pg_temp.media_insert(1016,jsonb_build_object('object_key','tenants/name/photo.png'))$$,
  '23514','media_catalog_scope_invalid','key cannot carry a name or bypass canonical scope');
select throws_ok($$select pg_temp.media_insert(1017,jsonb_build_object('catalog_kind','legacy-happens'))$$,
  '23514',null,'legacy discriminator does not bypass required post');
select throws_ok($$select pg_temp.media_insert(1018,jsonb_build_object('pixel_width',100))$$,
  '23514',null,'half-present dimensions cannot pass a nullable CHECK');
select throws_ok($$select pg_temp.media_insert(1019,jsonb_build_object('byte_size',10485761))$$,
  '23514',null,'unmeasured oversized bytes cannot enter the master catalog');
select throws_ok($$select pg_temp.media_insert(1020,jsonb_build_object('mime_type','video/mp4'))$$,
  '23514',null,'Forms image purpose cannot admit video');
select throws_ok($$select pg_temp.media_insert(1021,jsonb_build_object('status','ready',
  'byte_size',100,'checksum_sha256',repeat('a',64),'pixel_width',100,'pixel_height',100))$$,
  '23514','media_catalog_original_required','ready cannot precede verified original');
select throws_ok($$update public.media_assets set catalog_kind='legacy-happens' where id=pg_temp.media_id(1000)$$,
  '23514','media_catalog_origin_immutable','new catalog cannot be downgraded into legacy commands');
select throws_ok($$update public.media_assets set owner_person_id=pg_temp.media_id(101) where id=pg_temp.media_id(1000)$$,
  '23514','media_catalog_identity_immutable','physical ownership is immutable');

select lives_ok($$
  insert into public.media_variants(media_asset_id,rendition,bucket_id,object_key,mime_type,
    byte_size,checksum_sha256,pixel_width,pixel_height)
  select id,'original',bucket_id,object_key,mime_type,100,repeat('a',64),100,100
  from public.media_assets where id=pg_temp.media_id(1000);
  update public.media_assets set status='ready',byte_size=100,checksum_sha256=repeat('a',64),pixel_width=100,pixel_height=100
  where id=pg_temp.media_id(1000);
  set constraints all immediate;
  set constraints all deferred;
$$,'verified original and matching metadata can become ready atomically');
select throws_ok($$update public.media_assets set byte_size=101 where id=pg_temp.media_id(1000)$$,
  '23514','media_catalog_identity_immutable','ready content cannot be overwritten');
select throws_ok($$update public.media_variants set checksum_sha256=repeat('b',64) where media_asset_id=pg_temp.media_id(1000)$$,
  '23514','media_catalog_child_immutable','verified rendition content is immutable');
select throws_ok($$delete from public.media_variants where media_asset_id=pg_temp.media_id(1000);
  set constraints all immediate;$$,
  '23514','media_catalog_original_required','ready original cannot be removed independently');
select throws_ok($$delete from public.media_bindings where media_asset_id=pg_temp.media_id(1000);
  set constraints all immediate;$$,
  '23514','media_catalog_binding_required','active last binding cannot disappear independently');
select lives_ok($$update public.media_assets set status='deleted' where id=pg_temp.media_id(1000);
  delete from public.media_variants where media_asset_id=pg_temp.media_id(1000);
  delete from public.media_bindings where media_asset_id=pg_temp.media_id(1000);
  set constraints all immediate; set constraints all deferred;$$,
  'revoked asset metadata can release rendition and binding for lifecycle reconciliation');
select throws_ok($$update public.media_assets set status='ready' where id=pg_temp.media_id(1000)$$,
  '23514','media_catalog_identity_immutable','deleted asset cannot be resurrected');

select ok(relrowsecurity and relforcerowsecurity,relname||' forces RLS') from pg_class
where oid in ('public.media_assets'::regclass,'public.media_variants'::regclass,'public.media_bindings'::regclass);
select ok(not has_table_privilege(actor,object_name,'select,insert,update,delete'),actor||' has no direct '||object_name||' access')
from unnest(array['anon','authenticated']) actor
cross join unnest(array['public.media_assets','public.media_variants','public.media_bindings']) object_name;
select ok(not has_table_privilege('service_role',object_name,'select,insert,update,delete'),
  'foundation grants no new direct worker access to '||object_name)
from unnest(array['public.media_variants','public.media_bindings']) object_name;
select ok(not has_function_privilege('authenticated',oid,'execute'),'private trigger helper has no client grant')
from pg_proc where pronamespace='app_private'::regnamespace and proname like 'private_media_catalog_%_v1';
select has_function('public','finalize_happens_media_upload',array['uuid','uuid','text','bigint'],
  'existing Acontece finalization signature remains');
select ok(has_function_privilege('authenticated','public.finalize_happens_media_upload(uuid,uuid,text,bigint)','execute'),
  'existing Acontece public command grant remains');

set constraints all immediate;
select * from finish();
rollback;
