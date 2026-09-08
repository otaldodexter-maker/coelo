-- C02 I013. Synthetic rollback-only tests; no remote objects or real secrets.
-- Preparation is not evidence of execution. Run only in C00's nominal profile.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.read_id(n integer) returns uuid language sql immutable as $$
  select ('8c026000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
insert into public.institution_types(id,code,name,status)
values(pg_temp.read_id(1),'c02-media-read-test','Synthetic media read type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status)
select pg_temp.read_id(n),pg_temp.read_id(1),'Synthetic read '||n,'c02-media-read-'||n,'active'
from unnest(array[10,20]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.read_id(n),'adult','Synthetic','Responder','Synthetic responder '||n,'active'
from generate_series(1000,1001) n;
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.read_id(n),'authenticated','authenticated','c02-media-read-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from unnest(array[101,102]) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select pg_temp.read_id(n+100),pg_temp.read_id(n),now(),now(),'aal2',now()+interval '1 hour'
from unnest(array[101,102]) n;
insert into app_private.superadmin_internal_identities(id) select pg_temp.read_id(n) from unnest(array[301,302]) n;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select pg_temp.read_id(n+300),pg_temp.read_id(n+200),pg_temp.read_id(n) from unnest(array[101,102]) n;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select pg_temp.read_id(n+400),pg_temp.read_id(n+200),r.id,'institution',pg_temp.read_id(10)
from unnest(array[101,102]) n cross join public.platform_roles r where r.code='operations';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,(case when p.code='forms.responses.read' then 'allow' else 'deny' end)::public.permission_effect,'active'
from public.platform_roles r cross join public.platform_permissions p
where r.code='operations' and p.code in ('forms.read','forms.manage','forms.responses.read','forms.responses.export')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
select pg_temp.read_id(n),pg_temp.read_id(case when n=230 then 20 else 10 end),'form',
  case when n=220 then 'anonymous' else 'identified' end,'person','Synthetic form '||n,pg_temp.read_id(1000),pg_temp.read_id(1000)
from unnest(array[210,220,230,240]) n;
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
select pg_temp.read_id(n+1000),pg_temp.read_id(n),1,pg_temp.read_id(1000) from unnest(array[210,220,230,240]) n;
insert into public.form_sections(id,form_version_id,title,position)
select pg_temp.read_id(n+2000),pg_temp.read_id(n+1000),'Synthetic section',0 from unnest(array[210,220,230,240]) n;
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
select pg_temp.read_id(n+3000),pg_temp.read_id(n+1000),pg_temp.read_id(n+2000),'photo','Synthetic image',0
from unnest(array[210,220,230,240]) n;
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
select pg_temp.read_id(n+4000),pg_temp.read_id(n),pg_temp.read_id(case when n=230 then 20 else 10 end),
  'Synthetic application',pg_temp.read_id(1000) from unnest(array[210,220,230,240]) n;
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
select pg_temp.read_id(n+5000),pg_temp.read_id(n+4000),'UTC','2026-09-08 00:00:00','once' from unnest(array[210,220,230,240]) n;
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at)
select pg_temp.read_id(n+6000),pg_temp.read_id(n+4000),pg_temp.read_id(n+5000),pg_temp.read_id(case when n=230 then 20 else 10 end),
  pg_temp.read_id(n),pg_temp.read_id(n+1000),'2026-09-08 00:00:00','UTC',now()-interval '1 day',now()+interval '1 day'
from unnest(array[210,220,230,240]) n;
insert into public.form_responses(id,occurrence_id,institution_id,form_id,form_version_id,identity_mode,respondent_person_id,
  anonymous_edit_secret_hash,status,submitted_at)
select pg_temp.read_id(n+7000+offset_n),pg_temp.read_id(n+6000),pg_temp.read_id(case when n=230 then 20 else 10 end),
  pg_temp.read_id(n),pg_temp.read_id(n+1000),case when n=220 then 'anonymous' else 'identified' end,
  case when n<>220 then pg_temp.read_id(1000+offset_n) else null end,
  case when n=220 then 'synthetic-no-real-secret' else null end,'submitted',now()-interval '1 hour'
from unnest(array[210,220,230,240]) n cross join generate_series(0,1) offset_n;
insert into public.form_answers(id,response_id,form_version_id,item_id,answer_kind)
select pg_temp.read_id(n+8000+offset_n),pg_temp.read_id(n+7000+offset_n),pg_temp.read_id(n+1000),pg_temp.read_id(n+3000),'photo'
from unnest(array[210,220,230,240]) n cross join generate_series(0,1) offset_n;
insert into public.form_assets(id,institution_id,occurrence_id,item_id,prepared_by_person_id,anonymous_upload_secret_hash,
  storage_path,mime_type,expected_byte_length,actual_byte_length,expected_checksum_sha256,actual_checksum_sha256,
  state,prepared_at,expires_at,finalized_at)
select pg_temp.read_id(n+9000),pg_temp.read_id(case when n=230 then 20 else 10 end),pg_temp.read_id(n+6000),pg_temp.read_id(n+3000),
  case when n<>220 then pg_temp.read_id(1000) else null end,case when n=220 then '$2b$12$'||repeat('a',53) else null end,
  '8c/'||pg_temp.read_id(n+9000),'image/png',100,100,repeat('a',64),repeat('a',64),
  'finalized',now()-interval '2 days',now()-interval '1 day',now()-interval '23 hours'
from unnest(array[210,220,230,240]) n;
insert into public.form_answer_assets(answer_id,asset_id,position)
select pg_temp.read_id(n+8000),pg_temp.read_id(n+9000),0 from unnest(array[210,220,230,240]) n;
insert into public.media_assets(id,institution_id,form_id,source_form_asset_id,owner_person_id,catalog_kind,media_purpose,
  storage_provider,bucket_id,object_key,original_name,upload_request_id,mime_type,status)
select pg_temp.read_id(n+10000),pg_temp.read_id(case when n=230 then 20 else 10 end),pg_temp.read_id(n),pg_temp.read_id(n+9000),
  case when n<>220 then pg_temp.read_id(1000) else null end,'form-image','answer-image','r2','coelo-media-prod',
  'tenants/'||pg_temp.read_id(case when n=230 then 20 else 10 end)||'/forms/form/'||pg_temp.read_id(n)
    ||'/answer-image/'||pg_temp.read_id(n+10000)||'/original/'||pg_temp.read_id(n+11000)||'.png',
  '','synthetic-read-'||n,'image/png','pending' from unnest(array[210,220,230,240]) n;
insert into public.media_bindings(media_asset_id,form_version_id,item_id,purpose,position)
select pg_temp.read_id(n+10000),pg_temp.read_id(n+1000),pg_temp.read_id(n+3000),'answer-image',0
from unnest(array[210,220,230,240]) n;
insert into public.media_variants(media_asset_id,rendition,bucket_id,object_key,mime_type,byte_size,checksum_sha256,pixel_width,pixel_height)
select id,'original',bucket_id,object_key,mime_type,100,repeat('a',64),100,100 from public.media_assets
where id in(select pg_temp.read_id(n+10000) from unnest(array[210,220,230,240]) n);
insert into public.media_variants(media_asset_id,rendition,bucket_id,object_key,mime_type,byte_size,checksum_sha256,pixel_width,pixel_height)
select pg_temp.read_id(n+10000),'preview','coelo-media-prod',
  'tenants/'||pg_temp.read_id(10)||'/forms/form/'||pg_temp.read_id(n)||'/answer-image/'||pg_temp.read_id(n+10000)
    ||'/preview/'||pg_temp.read_id(n+12000)||'.png','image/png',50,repeat('b',64),50,50
from unnest(array[210,220]) n;
update public.media_assets set status='ready',byte_size=100,checksum_sha256=repeat('a',64),pixel_width=100,pixel_height=100
where id in(select pg_temp.read_id(n+10000) from unnest(array[210,220,230,240]) n);
set constraints all immediate;
set constraints all deferred;

create temporary table read_results(label text primary key,body jsonb);
grant insert,select on read_results to authenticated,service_role;
create function pg_temp.read_claims(actor integer) returns void language sql as $$
  select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.read_id(actor),'session_id',pg_temp.read_id(actor+100),
    'aal','aal2','role','authenticated')::text,true);
$$;
create function pg_temp.read_issue(n integer,rendition text default 'original') returns jsonb language sql security invoker as $$
  select public.superadmin_form_authorize_media_read_v2(jsonb_build_object('asset_id',pg_temp.read_id(n),'rendition',rendition));
$$;
create function pg_temp.read_redeem(label text) returns jsonb language sql security invoker as $$
  select public.form_redeem_media_read_r2_v1(body#>>'{data,read_token}') from read_results r where r.label=$1;
$$;
grant execute on function pg_temp.read_id(integer),pg_temp.read_claims(integer),pg_temp.read_issue(integer,text),pg_temp.read_redeem(text)
  to authenticated,service_role;
select pg_temp.read_claims(101);
create temporary table read_claims_before as select current_setting('request.jwt.claims',true) as claims,
  current_setting('request.jwt.claim.sub',true) as sub;
set local role authenticated;
insert into read_results values('original',pg_temp.read_issue(9210)),('preview',pg_temp.read_issue(9210,'preview')),
  ('anonymous',pg_temp.read_issue(9220)),('no_preview_original',pg_temp.read_issue(9240));
select is(pg_temp.read_issue(9230)#>>'{error,code}','SAI_PERMISSION_DENIED','tenant A cannot issue a ticket for tenant B');
select is(pg_temp.read_issue(10210)#>>'{error,code}','SAI_PERMISSION_DENIED','catalog UUID cannot substitute for source asset UUID');
select is(pg_temp.read_issue(9240,'preview')#>>'{error,code}','SAI_PERMISSION_DENIED','missing preview cannot fall back to original');
select is(pg_temp.read_issue(9210,'thumbnail')#>>'{error,code}','SAI_INVALID_ARGUMENT','unknown rendition is rejected');
select is(public.superadmin_form_authorize_media_read_v2('{"asset_id":"bad","rendition":"original"}')#>>'{error,code}',
  'SAI_INVALID_ARGUMENT','invalid asset UUID is rejected');
select is(public.superadmin_form_authorize_media_read_v2(jsonb_build_object('asset_id',pg_temp.read_id(9210),
  'rendition','original','institution_id',pg_temp.read_id(10)))#>>'{error,code}','SAI_INVALID_ARGUMENT','client scope override is rejected');
reset role;
select is((select body->>'ok' from read_results where label='original'),'true','internal image reader needs only forms.responses.read');
select is((select body#>>'{data,asset_id}' from read_results where label='original'),pg_temp.read_id(9210)::text,'grant correlates source UUID');
select ok(not exists(select 1 from public.person_auth_links where auth_user_id in(pg_temp.read_id(101),pg_temp.read_id(102))),
  'internal reading creates no People surrogate');
select ok((select body#>>'{data,read_token}' from read_results where label='original') ~ '^[0-9a-f-]{36}$','grant contains opaque UUID capability');
select is((select (body->'data')-array['asset_id','rendition','read_token','expires_at'] from read_results where label='original'),
  '{}'::jsonb,'grant exposes no private descriptor or actor');
select ok(exists(select 1 from app_private.form_media_read_tokens t join read_results r on r.label='original'
  and t.token_hash=encode(extensions.digest(convert_to(r.body#>>'{data,read_token}','UTF8'),'sha256'),'hex')
  where t.asset_id=pg_temp.read_id(9210) and t.expires_at-t.created_at=interval '2 minutes'
    and to_jsonb(t)::text not like '%'||(r.body#>>'{data,read_token}')||'%'),'catalog stores only hashed ticket with exact short expiry');
select ok((select expires_at<now() and state='finalized' from public.form_assets where id=pg_temp.read_id(9210)),
  'positive source has an expired upload reservation');
set local role service_role;
insert into read_results values('original_descriptor',pg_temp.read_redeem('original')),('preview_descriptor',pg_temp.read_redeem('preview')),
  ('anonymous_descriptor',pg_temp.read_redeem('anonymous')),('no_preview_descriptor',pg_temp.read_redeem('no_preview_original'));
select is(pg_temp.read_redeem('original'),null::jsonb,'one-use ticket cannot be replayed');
select is(public.form_redeem_media_read_r2_v1('not-a-ticket'),null::jsonb,'malformed token has no descriptor');
reset role;
select is((select body->>'media_asset_id' from read_results where label='original_descriptor'),pg_temp.read_id(10210)::text,
  'service descriptor resolves the distinct catalog UUID');
select is((select body->>'asset_id' from read_results where label='original_descriptor'),pg_temp.read_id(9210)::text,'service keeps source correlation');
select is((select body->>'bucket' from read_results where label='original_descriptor'),'coelo-media-prod','master resolves private R2 bucket');
select is((select body->>'object_key' from read_results where label='original_descriptor'),
  (select object_key from public.media_assets where id=pg_temp.read_id(10210)),'original resolves the exact master key');
select is((select body->>'object_key' from read_results where label='preview_descriptor'),
  (select object_key from public.media_variants where media_asset_id=pg_temp.read_id(10210) and rendition='preview'),'preview resolves its exact rendition');
select is((select body->>'rendition' from read_results where label='no_preview_descriptor'),'original','original remains readable without preview');
select is(current_setting('request.jwt.claims',true),(select claims from read_claims_before),'redemption restores caller claims after internal reauthorization');
select is(coalesce(current_setting('request.jwt.claim.sub',true),''),coalesce((select sub from read_claims_before),''),'redemption restores caller subject');
select ok(not exists(select 1 from read_results where label in('anonymous','anonymous_descriptor')
  and body::text~'(respondent|prepared_by|owner_|anonymous_.*secret|participation|Synthetic responder|synthetic-no-real-secret)'),
  'anonymous grant and descriptor expose no respondent identity or secret');
select ok(exists(select 1 from audit.audit_logs where action_code='superadmin.forms.media.read.redeem' and outcome='success'
  and actor_internal_identity_id=pg_temp.read_id(301) and object_id=pg_temp.read_id(9210)),'successful read is audited with internal actor');

-- Each revocation gets a fresh ticket: denied redemption consumes it as well.
set local role authenticated;
insert into read_results values('capability_revoked',pg_temp.read_issue(9210));
reset role;
update public.platform_role_permissions set effect='deny' where role_id=(select id from public.platform_roles where code='operations')
  and permission_id=(select id from public.platform_permissions where code='forms.responses.read');
set local role service_role;
select is(pg_temp.read_redeem('capability_revoked'),null::jsonb,'current read capability is required at redemption');
reset role;
select ok(exists(select 1 from app_private.form_media_read_tokens t join read_results r on r.label='capability_revoked'
  and t.token_hash=encode(extensions.digest(convert_to(r.body#>>'{data,read_token}','UTF8'),'sha256'),'hex')
  where t.consumed_at is not null),'denied ticket stays consumed outside recovery block');
select ok(exists(select 1 from audit.audit_logs where action_code='superadmin.forms.media.read.redeem' and outcome='denied'
  and actor_internal_identity_id=pg_temp.read_id(301)),'denied redemption is audited');
update public.platform_role_permissions set effect='allow' where role_id=(select id from public.platform_roles where code='operations')
  and permission_id=(select id from public.platform_permissions where code='forms.responses.read');
set local role service_role;
select is(pg_temp.read_redeem('capability_revoked'),null::jsonb,'restoring capability does not revive consumed ticket');
reset role;

set local role authenticated;
insert into read_results values('scope_changed',pg_temp.read_issue(9210));
reset role;
update app_private.superadmin_internal_memberships set scope_institution_id=pg_temp.read_id(20),version=version+1 where id=pg_temp.read_id(501);
set local role service_role;
select is(pg_temp.read_redeem('scope_changed'),null::jsonb,'membership moved to another tenant cannot redeem prior scope');
reset role;
update app_private.superadmin_internal_memberships set scope_institution_id=pg_temp.read_id(10),version=version+1 where id=pg_temp.read_id(501);
set local role authenticated;
insert into read_results values('membership_suspended',pg_temp.read_issue(9210));
reset role;
update app_private.superadmin_internal_memberships set status='suspended',suspended_at=clock_timestamp(),version=version+1 where id=pg_temp.read_id(501);
set local role authenticated;
insert into read_results values('denied_malformed',public.superadmin_form_authorize_media_read_v2('{"asset_id":"bad"}'));
reset role;
select isnt((select body#>>'{error,code}' from read_results where label='denied_malformed'),'SAI_INVALID_ARGUMENT','authorization precedes input casts');
select is((select body->'data' from read_results where label='denied_malformed'),'null'::jsonb,'suspended actor receives no data');
set local role service_role;
select is(pg_temp.read_redeem('membership_suspended'),null::jsonb,'suspended membership cannot redeem prior ticket');
reset role;
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=version+1 where id=pg_temp.read_id(501);

set local role authenticated;
insert into read_results values('auth_link_suspended',pg_temp.read_issue(9210));
reset role;
update app_private.superadmin_internal_auth_links set status='suspended',suspended_at=clock_timestamp(),version=version+1 where id=pg_temp.read_id(401);
set local role service_role;
select is(pg_temp.read_redeem('auth_link_suspended'),null::jsonb,'suspended auth link invalidates ticket independently of membership');
reset role;
select is(current_setting('request.jwt.claims',true),(select claims from read_claims_before),'denied redemption also restores caller claims');
update app_private.superadmin_internal_auth_links set status='active',suspended_at=null,version=version+1 where id=pg_temp.read_id(401);

select pg_temp.read_claims(102);
set local role authenticated;
insert into read_results values('logged_out',pg_temp.read_issue(9210));
reset role;
delete from auth.sessions where id=pg_temp.read_id(202);
set local role service_role;
select is(pg_temp.read_redeem('logged_out'),null::jsonb,'deleted issuing session invalidates ticket without blocking logout');
reset role;
select pg_temp.read_claims(101);
set local role authenticated;
insert into read_results values('session_expired',pg_temp.read_issue(9210));
reset role;
update auth.sessions set not_after=clock_timestamp()+interval '1 millisecond' where id=pg_temp.read_id(201);
select pg_sleep(0.01);
set local role service_role;
select is(pg_temp.read_redeem('session_expired'),null::jsonb,'wall-clock expired session is rejected despite transaction now');
reset role;
update auth.sessions set not_after=clock_timestamp()+interval '1 hour' where id=pg_temp.read_id(201);

-- Reachable cross-resource corruption: independent FKs do not prove ownership.
set local role authenticated;
insert into read_results values('attachment_removed',pg_temp.read_issue(9210));
reset role;
delete from public.form_answer_assets where asset_id=pg_temp.read_id(9210);
set local role service_role;
select is(pg_temp.read_redeem('attachment_removed'),null::jsonb,'removed attachment invalidates prior authorization');
reset role;
insert into public.form_answer_assets(answer_id,asset_id,position) values(pg_temp.read_id(8211),pg_temp.read_id(9210),0);
set local role authenticated;
select is(pg_temp.read_issue(9210)#>>'{error,code}','SAI_PERMISSION_DENIED','another respondent in the same occurrence cannot own uploaded answer image');
reset role;
delete from public.form_answer_assets where asset_id=pg_temp.read_id(9210);
insert into public.form_answer_assets(answer_id,asset_id,position) values(pg_temp.read_id(8210),pg_temp.read_id(9210),0);

set local role authenticated;
insert into read_results values('anonymous_attachment_moved',pg_temp.read_issue(9220));
reset role;
delete from public.form_answer_assets where asset_id=pg_temp.read_id(9220);
insert into public.form_answer_assets(answer_id,asset_id,position) values(pg_temp.read_id(8221),pg_temp.read_id(9220),0);
set local role service_role;
select is(pg_temp.read_redeem('anonymous_attachment_moved'),null::jsonb,'anonymous ticket is bound to original response even without respondent identity');
reset role;
set local role authenticated;
select is(pg_temp.read_issue(9220)->>'ok','true','new authorization resolves the current anonymous attachment without inventing identity');
reset role;

set local role authenticated;
insert into read_results values('answer_version_changed',pg_temp.read_issue(9210));
reset role;
select throws_ok($$update public.form_answers set form_version_id=pg_temp.read_id(1240) where id=pg_temp.read_id(8210)$$,
  '23514','form answer version mismatch','effective answer trigger rejects foreign version before it can be persisted');
set local role service_role;
select is(pg_temp.read_redeem('answer_version_changed')->>'asset_id',pg_temp.read_id(9210)::text,'rejected corruption preserves valid ticket and original answer version');
reset role;
update public.form_items set section_id=pg_temp.read_id(2240),position=1 where id=pg_temp.read_id(3210);
set local role authenticated;
select is(pg_temp.read_issue(9210)#>>'{error,code}','SAI_PERMISSION_DENIED','image item section must belong to submitted version');
reset role;
update public.form_items set section_id=pg_temp.read_id(2210),position=0 where id=pg_temp.read_id(3210);
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
values(pg_temp.read_id(3212),pg_temp.read_id(1210),pg_temp.read_id(2210),'photo','Another source item',1);
update public.form_answers set item_id=pg_temp.read_id(3212) where id=pg_temp.read_id(8210);
set local role authenticated;
select is(pg_temp.read_issue(9210)#>>'{error,code}','SAI_PERMISSION_DENIED','answer item cannot differ from source item');
reset role;
update public.form_answers set item_id=pg_temp.read_id(3210) where id=pg_temp.read_id(8210);

set local role authenticated;
insert into read_results values('preview_removed',pg_temp.read_issue(9210,'preview'));
reset role;
delete from public.media_variants where media_asset_id=pg_temp.read_id(10210) and rendition='preview';
set local role service_role;
select is(pg_temp.read_redeem('preview_removed'),null::jsonb,'removed preview cannot redeem master as fallback');
reset role;
set local role authenticated;
select is(pg_temp.read_issue(9210)->>'ok','true','master remains independently authorized after preview removal');
insert into read_results values('quarantined',pg_temp.read_issue(9210));
reset role;
update public.media_assets set status='quarantined' where id=pg_temp.read_id(10210);
set local role service_role;
select is(pg_temp.read_redeem('quarantined'),null::jsonb,'quarantine after issue invalidates ticket');
reset role;
set local role authenticated;
select is(pg_temp.read_issue(9210)#>>'{error,code}','SAI_PERMISSION_DENIED','quarantined image cannot issue new ticket');
reset role;
update public.media_assets set status='ready' where id=pg_temp.read_id(10210);

set local role authenticated;
insert into read_results values('source_discarded',pg_temp.read_issue(9240));
reset role;
update public.form_assets set state='discarded',discarded_at=clock_timestamp() where id=pg_temp.read_id(9240);
set local role service_role;
select is(pg_temp.read_redeem('source_discarded'),null::jsonb,'discarded source cannot use stale ready catalog');
reset role;
set local role authenticated;
select is(pg_temp.read_issue(9240)#>>'{error,code}','SAI_PERMISSION_DENIED','non-finalized source cannot issue despite ready catalog');
reset role;

-- Token expiry is immutable. Clone a valid fixture with new identity/hash and
-- a genuinely short lifetime; never weaken the trigger or update the expiry.
set local role authenticated;
insert into read_results values('expiry_template',pg_temp.read_issue(9210));
reset role;
insert into app_private.form_media_read_tokens
select (jsonb_populate_record(null::app_private.form_media_read_tokens,to_jsonb(t)||jsonb_build_object(
  'id',pg_temp.read_id(20001),'token_hash',encode(extensions.digest(convert_to(pg_temp.read_id(20002)::text,'UTF8'),'sha256'),'hex'),
  'created_at',instant.at,'expires_at',instant.at+interval '20 milliseconds','consumed_at',null))).*
from app_private.form_media_read_tokens t join read_results r on r.label='expiry_template'
  and t.token_hash=encode(extensions.digest(convert_to(r.body#>>'{data,read_token}','UTF8'),'sha256'),'hex')
cross join (select clock_timestamp() as at) instant;
select pg_sleep(0.05);
select ok((select now()<expires_at and expires_at<=clock_timestamp() from app_private.form_media_read_tokens where id=pg_temp.read_id(20001)),
  'ticket expiry fixture distinguishes transaction time from wall clock');
set local role service_role;
select is(public.form_redeem_media_read_r2_v1(pg_temp.read_id(20002)::text),null::jsonb,'expired ticket is denied after real wait');
reset role;
select ok((select consumed_at is not null from app_private.form_media_read_tokens where id=pg_temp.read_id(20001)),'expired ticket remains consumed');
select throws_ok($$update app_private.form_media_read_tokens set expires_at=expires_at+interval '1 second' where id=pg_temp.read_id(20001)$$,
  '23514','forms_media_read_token_immutable','ticket expiry cannot be extended');
select throws_ok($$update app_private.form_media_read_tokens set consumed_at=null where id=pg_temp.read_id(20001)$$,
  '23514','forms_media_read_token_immutable','consumed ticket cannot be reset');

create function pg_temp.read_audit_failure() returns trigger language plpgsql as $$
begin
  if new.action_code in('superadmin.forms.media.read.authorize','superadmin.forms.media.read.redeem')
    and new.outcome='success' then raise exception 'synthetic media audit failure'; end if;
  return new;
end;
$$;
create temporary table read_before_audit as select count(*) as count from app_private.form_media_read_tokens;
create trigger c02_media_read_audit_failure before insert on audit.audit_logs for each row execute function pg_temp.read_audit_failure();
set local role authenticated;
select throws_ok($$select pg_temp.read_issue(9210)$$,'P0001','synthetic media audit failure','issue audit failure escapes without returning a grant');
reset role;
select is((select count(*) from app_private.form_media_read_tokens),(select count from read_before_audit),'failed issue audit rolls ticket insertion back');
set local role service_role;
select throws_ok($$select pg_temp.read_redeem('expiry_template')$$,'P0001','synthetic media audit failure','redeem audit failure escapes without returning descriptor');
reset role;
select ok(exists(select 1 from app_private.form_media_read_tokens t join read_results r on r.label='expiry_template'
  and t.token_hash=encode(extensions.digest(convert_to(r.body#>>'{data,read_token}','UTF8'),'sha256'),'hex')
  where t.consumed_at is null),'failed audit rolls consumption back atomically instead of committing unaudited read');
drop trigger c02_media_read_audit_failure on audit.audit_logs;

select ok(relrowsecurity and relforcerowsecurity,'ticket table forces RLS') from pg_class where oid='app_private.form_media_read_tokens'::regclass;
select ok(not has_table_privilege(actor,'app_private.form_media_read_tokens','select,insert,update,delete'),actor||' has no direct ticket access')
from unnest(array['anon','authenticated','service_role']) actor;
select ok(not has_function_privilege(actor,'public.superadmin_form_authorize_media_read_v2(jsonb)','execute'),actor||' cannot issue internal read grants')
from unnest(array['anon','service_role']) actor;
select ok(not has_function_privilege(actor,'public.form_redeem_media_read_r2_v1(text)','execute'),actor||' cannot redeem service descriptors')
from unnest(array['anon','authenticated']) actor;
select ok(has_function_privilege('authenticated','public.superadmin_form_authorize_media_read_v2(jsonb)','execute'),'authenticated can invoke guarded issuer');
select ok(has_function_privilege('service_role','public.form_redeem_media_read_r2_v1(text)','execute'),'service has only nominal redemption grant');
select ok(not has_function_privilege(actor,fn,'execute'),actor||' cannot execute private helper '||fn)
from unnest(array['anon','authenticated','service_role']) actor cross join unnest(array[
  'app_private.forms_media_read_context_v1(uuid,uuid,uuid,uuid,text,uuid)',
  'app_private.forms_answer_media_descriptor_v1(uuid,text,text,uuid,uuid)',
  'app_private.superadmin_form_authorize_media_read_v2(jsonb)',
  'app_private.form_redeem_media_read_r2_v1(text)']) fn;
set constraints all immediate;
select * from finish();
rollback;
