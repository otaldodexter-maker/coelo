-- Endurecimento transversal dos objetos criados pela frente realm-interno na R05
-- (210000..210900): search_path vazio, dono postgres, sem EXECUTE para PUBLIC/anon,
-- tabelas novas com RLS e sem grant a anon.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

create temporary table r05_functions as
select p.oid, n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' as signature,
  p.prosecdef, coalesce(p.proconfig,'{}'::text[]) as config, (select rolname from pg_roles where oid=p.proowner) as owner
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','app_private') and (
  p.proname like 'superadmin_institution_contacts_%' or p.proname like 'superadmin_chat_attachment_%'
  or p.proname like 'superadmin_form_media_%' or p.proname like 'form_media_%'
  or p.proname like 'superadmin_unit_care_policy_%' or p.proname like 'child_care_%'
  or p.proname like 'notify_child_care_%' or p.proname like '%_care_notify_v1'
  or p.proname in ('person_identity_hmac_v1','cpf_digits_valid_v1','cnpj_digits_valid_v1','mask_email_v1','mask_phone_v1','mask_cpf_v1',
    'enforce_activity_active_group_v1','chat_attachment_limit_v1','chat_attachment_extension_v1',
    'chat_media_dispatch_expire_worker','forms_media_dispatch_expire_worker','form_prepare_asset_upload_r2_v1','form_asset_r2_descriptor_v1',
    'unit_care_policy_payload_v1','form_assets_answer_media_mirror_v1','form_assets_answer_media_discard_v1'));

select ok((select count(*) >= 40 from r05_functions),'as funcoes da rodada foram encontradas (>= 40)');
select is((select count(*) from r05_functions where not (config @> array['search_path=']::text[] or config @> array['search_path=""']::text[])),0::bigint,
  'toda funcao da rodada tem search_path vazio');
select is((select count(*) from r05_functions where owner<>'postgres'),0::bigint,'toda funcao da rodada pertence a postgres');
select is((select count(*) from r05_functions f where has_function_privilege('anon',f.oid,'execute')
  or exists (select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where p.oid=f.oid and a.grantee=0 and a.privilege_type='EXECUTE')),0::bigint,
  'nenhuma funcao da rodada e executavel por anon ou PUBLIC');
select is((select count(*) from r05_functions f join pg_proc p on p.oid=f.oid join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and not f.prosecdef),0::bigint,'toda RPC publica da rodada e security definer');

with tables(s,t) as (values ('public','unit_care_policies'),('app_private','unit_care_policy_receipts'),
  ('app_private','superadmin_internal_chat_attachment_tickets'),('app_private','form_media_upload_tickets'),('app_private','form_media_r2_cleanup'))
select is((select count(*) from tables join pg_class c on c.relname=t join pg_namespace n on n.oid=c.relnamespace and n.nspname=s
  where not c.relrowsecurity or exists (select 1 from information_schema.role_table_grants g
    where g.table_schema=s and g.table_name=t and g.grantee in ('anon','PUBLIC'))),0::bigint,
  'tabelas novas com RLS ligada e sem grant a anon/PUBLIC');

select * from finish();
rollback;
