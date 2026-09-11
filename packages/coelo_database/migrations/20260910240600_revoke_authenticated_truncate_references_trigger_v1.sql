-- Seguranca basica: authenticated deixa de ter TRUNCATE, REFERENCES e TRIGGER
-- em tabelas dos schemas da aplicacao.
--
-- Medido em producao em 11/09/2026 00:05 (somente leitura): 22 tabelas de
-- public concedem os tres privilegios a authenticated (GRANT ALL historico):
-- audience_segments, channel_policies, conversation_members, conversations,
-- institution_memberships, institution_settings, institution_subscriptions,
-- institutions, messages, people, person_addresses, person_auth_links,
-- person_contacts, person_education_details, person_professional_details,
-- person_profile_details, platform_permissions, schema_columns, schema_tables,
-- unit_branding, units, usage_limits.
-- TRUNCATE nao passa pelo RLS: com o privilegio, qualquer sessao autenticada
-- (inclusive um responsavel do app Principal) poderia esvaziar people,
-- institutions ou messages pela API. REFERENCES e TRIGGER nao tem uso pelo
-- cliente. SELECT/INSERT/UPDATE/DELETE ficam como estao (o RLS decide e uma
-- varredura separada, em docs/reviews/evidence/etapa-2/r04-realm-interno/,
-- registra os grants sem policy como pendencia de code review).
-- Idempotente e presence-based; nada e concedido.
begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='authenticated revoke migration must run as postgres';
  end if;
end
$$;

do $$
declare s text;
begin
  foreach s in array array['public','app_private','audit','analytics'] loop
    if exists(select 1 from pg_namespace where nspname=s) then
      execute format('revoke truncate, references, trigger on all tables in schema %I from authenticated', s);
    end if;
  end loop;
end
$$;

commit;
