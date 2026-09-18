-- Prova pgTAP da migration 20260918130000_account_profile_mobile_phone_e164_v1
-- (R16 Sessao RESERVA, D5 / owner.r12-46, celular-mascara): normalizacao E.164 do Celular.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

select has_function('app_private','normalize_mobile_phone_e164',array['text'],'normalizer exists');
select ok((select not has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private' and p.proname='normalize_mobile_phone_e164'),
  'normalizer has no client grant');
select ok((select p.provolatile='i' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private' and p.proname='normalize_mobile_phone_e164'),
  'normalizer is immutable');

-- aceitos
select is(app_private.normalize_mobile_phone_e164('11912345678'),'+5511912345678','11 digits');
select is(app_private.normalize_mobile_phone_e164('(11) 91234-5678'),'+5511912345678','masked national');
select is(app_private.normalize_mobile_phone_e164('+55 (11) 91234-5678'),'+5511912345678','masked with +55');
select is(app_private.normalize_mobile_phone_e164('+5511912345678'),'+5511912345678','already E.164');
select is(app_private.normalize_mobile_phone_e164('5511912345678'),'+5511912345678','55 prefix without plus');
select is(app_private.normalize_mobile_phone_e164('  +55 11 9 1234 5678 '),'+5511912345678','spaces and padding');
select is(app_private.normalize_mobile_phone_e164('55 91234-5678'),'+5555912345678','11 national digits with DDD 55 and no country prefix are kept as DDD');
select is(app_private.normalize_mobile_phone_e164('+55 55 91234-5678'),'+5555912345678','DDD 55 with explicit +55 is valid');

-- recusados
select is(app_private.normalize_mobile_phone_e164(null),null,'null');
select is(app_private.normalize_mobile_phone_e164(''),null,'empty');
select is(app_private.normalize_mobile_phone_e164('1112345678'),null,'landline (8 digits, no 9)');
select is(app_private.normalize_mobile_phone_e164('11812345678'),null,'third digit not 9');
select is(app_private.normalize_mobile_phone_e164('01912345678'),null,'DDD starting with zero');
select is(app_private.normalize_mobile_phone_e164('119123456789'),null,'12 digits');
select is(app_private.normalize_mobile_phone_e164('+1 202 555 0143'),null,'foreign country code');
select is(app_private.normalize_mobile_phone_e164('abc'),null,'letters');

-- save_v2 usa o normalizador e sinaliza com codigo de familia
select ok(position('normalize_mobile_phone_e164' in pg_get_functiondef('public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text)'::regprocedure))>0,
  'save_v2 normalizes the phone');
select ok(position('invalid_account_mobile_phone' in pg_get_functiondef('public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text)'::regprocedure))>0
  and position('40001' in pg_get_functiondef('public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text)'::regprocedure))=0,
  'save_v2 rejects with invalid_account_mobile_phone and never 40001');
select is(has_function_privilege('authenticated','public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text)','execute'),true,'authenticated keeps execute on save_v2');

select * from finish();
rollback;
