-- Formularios: revoga o drift de privilegios que producao acumulou.
--
-- Achado na baseline de producao de 2026-09-10, ao rodar os pgTAP da familia
-- sobre ela. Quatro assercoes falharam, e nenhuma delas era teste
-- desatualizado: as quatro descrevem privilegios que o repositorio revoga e
-- que o banco de producao ainda tem.
--
-- 1. Grants diretos de tabela. As sete tabelas expostas de Formularios (forms,
--    form_versions, form_items, form_applications, form_occurrences,
--    form_responses, form_answers) tem SELECT, INSERT, UPDATE, DELETE,
--    TRUNCATE, REFERENCES e TRIGGER concedidos a anon E a authenticated.
--
--    Hoje isso esta inerte: as sete tem RLS habilitado e FORCE com ZERO
--    policies, entao a negativa e total para quem nao tem BYPASSRLS, e um anon
--    que consulte public.forms recebe zero linhas. Mas a protecao inteira esta
--    apoiada na ausencia de policy. No dia em que qualquer policy permissiva
--    for criada, ou em que o FORCE cair, esses grants viram escrita real de
--    anonimo em dado de formulario. Privilegio que so nao e usado porque outra
--    coisa esta segurando nao e privilegio aceitavel.
--
-- 2. Tokens de download. anon podia executar form_authorize_file_job_download,
--    e authenticated podia executar form_redeem_file_job_download. O resgate e
--    server-side por contrato: quem resgata e o service_role, nao o navegador.
--    Este e o unico dos quatro que nao dependia de um segundo erro para
--    importar.
--
-- Forward-only e mecanico: so revoga. Nao cria, nao altera corpo de funcao e
-- nao mexe em RLS. Se algum caminho legitimo dependia de grant direto, ele
-- falha fechado e aparece, em vez de continuar escrevendo por fora das RPCs.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.forms.revoke-drift', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='forms drift revoke must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.forms') is null then
    raise exception using errcode='55000',
      message='forms drift revoke requires the forms foundation';
  end if;
end
$preflight$;

do $revoke_tables$
declare current_table text;
begin
  foreach current_table in array array[
    'forms','form_versions','form_items','form_item_options','form_applications',
    'form_audience_rules','form_occurrences','form_responses','form_answers',
    'form_response_revisions'
  ] loop
    if pg_catalog.to_regclass('public.' || quote_ident(current_table)) is null then
      continue;
    end if;
    execute format('revoke all on public.%I from anon, authenticated', current_table);
    -- service_role continua com tudo: e por ele que as Edge Functions e os
    -- jobs alcancam a tabela.
    execute format('grant all on public.%I to service_role', current_table);
  end loop;
end
$revoke_tables$;

-- Autorizar o download continua sendo de sessao autenticada; resgatar o token
-- e do service_role, porque o resgate acontece no servidor e nao no navegador.
revoke all on function public.form_authorize_file_job_download(uuid)
  from public, anon, authenticated;
grant execute on function public.form_authorize_file_job_download(uuid)
  to authenticated, service_role;

revoke all on function public.form_redeem_file_job_download(uuid)
  from public, anon, authenticated;
grant execute on function public.form_redeem_file_job_download(uuid)
  to service_role;

commit;
