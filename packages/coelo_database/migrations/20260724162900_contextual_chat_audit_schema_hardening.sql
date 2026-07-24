-- Correct the conversation RPC created in the previous migration to the
-- canonical audit schema established by schema_boundaries_catalog_v1.

do $$
declare
  function_definition text;
begin
  select pg_get_functiondef(
    'app_private.create_context_conversation(uuid,text,uuid,uuid,uuid,text,text,uuid,uuid[])'
      ::regprocedure
  )
  into function_definition;

  function_definition := replace(
    function_definition,
    'insert into public.audit_logs',
    'insert into audit.audit_logs'
  );

  execute function_definition;
end
$$;
