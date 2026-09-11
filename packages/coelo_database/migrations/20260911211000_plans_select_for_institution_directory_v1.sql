-- R05 realm-interno (11): institution_directory legivel por sessao autenticada.
--
-- Achado da varredura da R04 (item 6): em producao a view security_invoker
-- public.institution_directory falha em leitura direta por authenticated com
-- "permission denied for table plans", porque public.plans tem a policy
-- plans_platform_read (SELECT para quem tem platform.read) mas nao tem o
-- grant SELECT correspondente. O grant so materializa a policy ja existente:
-- RLS forcada continua decidindo linha a linha (quem nao tem platform.read
-- ve zero linhas). Nenhum outro comando e concedido. Idempotente.

begin;
do $$
begin
  if to_regclass('public.plans') is null
    or not exists (select 1 from pg_policies where schemaname='public' and tablename='plans' and policyname='plans_platform_read') then
    raise object_not_in_prerequisite_state using message = 'public.plans with plans_platform_read is required';
  end if;
  if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.plans'::regclass) then
    raise object_not_in_prerequisite_state using message = 'public.plans must keep forced RLS';
  end if;
end $$;
grant select on table public.plans to authenticated;
commit;
