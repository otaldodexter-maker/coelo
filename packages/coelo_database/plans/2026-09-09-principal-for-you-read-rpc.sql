-- =====================================================================
-- Coelo | E2 R02 L03 | Principal / Para Voce (action_id principal.for-you)
-- Proposta de leitura autorizada no servidor: public.list_my_principal_for_you
-- ---------------------------------------------------------------------
-- STATUS: PROPOSTA. NAO APLICADA. NAO E MIGRATION.
--   Este arquivo vive em packages/coelo_database/plans/ e NAO em
--   packages/coelo_database/migrations/. Nenhum runner deve executa-lo.
--   Promover a migration exige numero forward-only proprio.
-- FORWARD-ONLY: cria uma funcao nova. Nao faz drop, alter ou revoke de
--   nenhum objeto existente. Nao altera tabelas, policies ou enums.
-- AUTORIZACAO: todo recurso Supabase do Coelo e PRODUCAO. A aplicacao
--   remota exige autorizacao nominal do Owner e serializacao por D00.
--   Quem escreveu este arquivo NAO tem essa autorizacao e NAO validou
--   este SQL contra nenhum banco, local ou remoto.
-- NAO SUBSTITUI as RPCs internas do Superadmin
--   (public.superadmin_notice_directory_v2, superadmin_notice_detail_v2 e
--   demais _v2 de 20260901185008_superadmin_internal_notices_v2.sql).
--   Aquelas continuam sendo o gateway administrativo, guardado por
--   app_private.superadmin_notice_context('notices.read'). Esta funcao e o
--   gateway de LEITURA DO ATOR no Principal, com audiencia resolvida no
--   servidor.
-- PADRAO SEGUIDO: public.list_my_principal_contexts()
--   (20260901161700_principal_runtime_contexts.sql) para resolucao do ator,
--   e public.list_visible_profile_circulars
--   (20260821190000_circulars_production.sql) para leitura por escopo.
-- =====================================================================
--
-- Colunas CONFIRMADAS nas migrations lidas:
--   public.platform_notices: id, notice_type, status, priority (int),
--     title, body_text, cta_label, cta_url, starts_at, ends_at,
--     published_at        -- 20260623191021_superadmin_foundation_v1.sql
--     priority_code, audience_json, audience_label, behavior,
--     target_device, content_format, image_orientation,
--     management_version, created_at, updated_at
--                         -- 20260901185008_superadmin_internal_notices_v2.sql
--
--   public.platform_notices.target_device CONFIRMADO como coluna `text`
--     `not null default 'all'` (NAO e enum). Adicionada em
--     20260812003000_notices_production.sql (linha 9) e reafirmada em
--     20260901185008_superadmin_internal_notices_v2.sql (linha 19).
--     A allowlist vem de CHECK constraint, nao de tipo:
--       platform_notices_production_values_ck  -- 20260812003000, linha 29
--       platform_notices_internal_v2_values_ck -- 20260901185008, linha 50
--     Ambas restringem target_device in ('all','web','mobile','tablet'),
--     o mesmo conjunto do dominio Dart NoticeTargetDevice.
--   public.institution_memberships: id, person_id, institution_id,
--     role_code, scope_kind, scope_unit_id, scope_group_id, status,
--     revoked_at, created_at   -- usadas por list_my_principal_contexts
--   public.person_auth_links: auth_user_id, person_id, status, revoked_at
--   public.people: id, status
--   public.institutions: id, status, public_name
--   public.units: id, institution_id, name, status
--   public.groups: id, institution_id, unit_id, name, status
--   public.notice_rules: id, notice_id, segment_id, effect, target_type,
--     target_id, role_filter, conditions_json, rule_version, position
--
-- Enums CONFIRMADOS:
--   public.notice_type: 'notice','critical_notice','popup','content_card'
--     + 'highlight','for_you' (20260820204752 / 20260901185008)
--   public.notice_status: 'draft','scheduled','published','expired',
--     'archived' + 'active','paused','inactive'
--   public.notice_rule_effect: 'include','exclude'
--   public.target_type: 'platform','institution','unit','group','role',
--     'plan','custom_segment'
--
-- Formato de audiencia CONFIRMADO em app_private.validate_notice_audience
--   (20260812003000_notices_production.sql) e no validador equivalente do
--   v2 (20260901185008, linhas 300-338):
--     platform_notices.audience_json =
--       { "rules": [ { "dimension": 'platform'|'institution'|'unit'
--                                   |'group'|'person',
--                      "select_all": bool,
--                      "target_ids": [uuid...],
--                      "excluded_ids": [uuid...],
--                      "filters": {...} } ],   -- exatamente 1 regra
--         "role_codes": [text...],             -- ate 20
--         "plan_ids": [uuid...] }              -- ate 50
--   Ou seja: papel NAO e dimensao de regra; vive em role_codes.
--   Plano NAO e dimensao de regra; vive em plan_ids.
--
-- ACHADO IMPORTANTE (corrige a hipotese inicial do recorte):
--   Nenhuma migration do repositorio executa
--   `insert into public.notice_rules`. A audiencia real e gravada em
--   platform_notices.audience_json pelos comandos de save/publish.
--   Por isso a avaliacao de audiencia abaixo usa audience_json como fonte
--   autoritativa, e notice_rules aparece apenas como EXCLUSAO defensiva
--   (exclusao vence inclusao), nunca como fonte de inclusao. Se algum dia
--   notice_rules passar a ser populado com inclusoes, esta funcao precisa
--   ser revista antes de promocao.
-- =====================================================================

-- ---------------------------------------------------------------------
-- REVISAO L02 (dono do contrato de notices) incorporada nesta versao:
--   1. target_device passou a ser filtrado NO SERVIDOR. O cliente informa
--      apenas em qual destino esta rodando (p_target_device); ele NAO
--      recebe a coluna para decidir. Projetar target_device reintroduziria
--      exatamente o defeito de autorizacao que esta funcao existe para
--      corrigir, entao a coluna permanece fora do `returns table`.
--   2. content_card permanece elegivel. Endosso do dono do contrato:
--      "Conteudo" e card legitimo do hub Para Voce. O que nunca pode virar
--      card e popup, que ja esta bloqueado pelo filtro de notice_type.
--   3. status = 'active' apenas esta correto e o efeito colateral e
--      aceito: linhas legadas ainda em 'published' ficam invisiveis ate o
--      cutover forward-only de 20260901185008 ter rodado no destino.
--      Isso falha fechado, que e o lado certo de errar. Ausencia de
--      resultado por essa causa NAO e defeito da funcao.
-- ---------------------------------------------------------------------

create or replace function public.list_my_principal_for_you(
  p_target_device text,
  p_limit int default 50
)
returns table(
  notice_id uuid,
  notice_type text,
  priority_code text,
  priority_rank int,
  title text,
  body_text text,
  cta_label text,
  cta_url text,
  starts_at timestamptz,
  ends_at timestamptz,
  content_format text,
  image_orientation text,
  institution_id uuid,
  membership_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;

  if p_limit is null or p_limit not between 1 and 100 then
    raise invalid_parameter_value using message = 'invalid_for_you_query';
  end if;

  -- Allowlist server-side de destino. Espelha as CHECK constraints
  -- platform_notices_production_values_ck (20260812003000, linha 29) e
  -- platform_notices_internal_v2_values_ck (20260901185008, linha 50), e o
  -- dominio Dart NoticeTargetDevice {all, web, mobile, tablet}.
  -- Valor fora da allowlist (ou null) e REJEITADO, nunca ignorado em
  -- silencio: ignorar viraria uma leitura mais ampla do que a autorizada.
  if p_target_device is null
     or p_target_device not in ('all', 'web', 'mobile', 'tablet') then
    raise invalid_parameter_value using message = 'invalid_for_you_target_device';
  end if;

  return query
  with actor as (
    -- Mesmo caminho de resolucao de ator de public.list_my_principal_contexts:
    -- pessoa ativa vinculada ao auth.uid(), com vinculo ativo e nao revogado.
    select
      membership.id             as membership_id,
      membership.person_id      as person_id,
      membership.institution_id as institution_id,
      membership.role_code      as role_code,
      membership.scope_kind     as scope_kind,
      scoped_unit.id            as unit_id,
      scoped_group.id           as group_id
    from public.person_auth_links auth_link
    join public.people person
      on person.id = auth_link.person_id
     and person.status = 'active'
    join public.institution_memberships membership
      on membership.person_id = person.id
     and membership.status = 'active'
     and membership.revoked_at is null
    join public.institutions institution
      on institution.id = membership.institution_id
     and institution.status = 'active'
    left join public.groups scoped_group
      on scoped_group.id = membership.scope_group_id
     and scoped_group.institution_id = membership.institution_id
     and scoped_group.status = 'active'
    left join public.units scoped_unit
      on scoped_unit.id = coalesce(membership.scope_unit_id, scoped_group.unit_id)
     and scoped_unit.institution_id = membership.institution_id
     and scoped_unit.status = 'active'
    where auth_link.auth_user_id = (select auth.uid())
      and auth_link.status = 'active'
      and auth_link.revoked_at is null
  ),
  eligible_notice as (
    select
      notice.id,
      notice.notice_type,
      notice.priority_code,
      notice.title,
      notice.body_text,
      notice.cta_label,
      notice.cta_url,
      notice.starts_at,
      notice.ends_at,
      notice.content_format,
      notice.image_orientation,
      notice.published_at,
      notice.created_at,
      -- audience_json valida exatamente uma regra; o -> 0 e seguro aqui.
      notice.audience_json -> 'rules' -> 0 as rule_json,
      coalesce(notice.audience_json -> 'role_codes', '[]'::jsonb) as role_codes
    from public.platform_notices notice
    where
      -- Somente os tipos que o hub "Para Voce" pode exibir. popup, notice e
      -- critical_notice NUNCA saem por esta funcao.
      notice.notice_type::text in ('highlight', 'content_card', 'for_you')
      -- status = 'active' apenas, de proposito. Linhas legadas em
      -- 'published' ficam invisiveis ate o cutover forward-only de
      -- 20260901185008 (linha 40) ter rodado no destino. Fail-closed.
      and notice.status::text = 'active'
      -- Gate de destino aplicado no SERVIDOR. 'all' alcanca qualquer
      -- cliente; qualquer outro valor exige igualdade com o destino
      -- declarado e validado do chamador. A spec exige exatamente um
      -- destino por comunicacao, entao um aviso restrito a 'mobile' nunca
      -- chega a um cliente 'web'.
      and (
        notice.target_device = 'all'
        or notice.target_device = p_target_device
      )
      and notice.starts_at is not null
      and notice.starts_at <= now()
      and (notice.ends_at is null or notice.ends_at > now())
  )
  select
    eligible_notice.id,
    eligible_notice.notice_type::text,
    eligible_notice.priority_code,
    case eligible_notice.priority_code
      when 'urgent' then 0
      when 'important' then 10
      else 20
    end as priority_rank,
    eligible_notice.title,
    eligible_notice.body_text,
    eligible_notice.cta_label,
    eligible_notice.cta_url,
    eligible_notice.starts_at,
    eligible_notice.ends_at,
    eligible_notice.content_format,
    eligible_notice.image_orientation,
    actor.institution_id,
    actor.membership_id
  from eligible_notice
  cross join actor
  where
    -- -----------------------------------------------------------------
    -- 1) Gate de papel. role_codes vazio nao restringe; preenchido exige
    --    que o papel real do vinculo do ator esteja na lista.
    -- -----------------------------------------------------------------
    (
      jsonb_array_length(eligible_notice.role_codes) = 0
      or exists (
        select 1
        from jsonb_array_elements_text(eligible_notice.role_codes) as code(value)
        where code.value = actor.role_code
      )
    )
    -- -----------------------------------------------------------------
    -- 2) Gate de inclusao pela dimensao da regra de audience_json.
    --    'platform' alcanca todos. As demais exigem que o identificador
    --    real do ator naquela dimensao esteja em target_ids, salvo
    --    select_all, que alcanca a dimensao inteira.
    --    Dimensao desconhecida nunca inclui (fail-closed).
    -- -----------------------------------------------------------------
    and (
      case eligible_notice.rule_json ->> 'dimension'
        when 'platform' then true
        when 'institution' then
          coalesce((eligible_notice.rule_json ->> 'select_all')::boolean, false)
          or (eligible_notice.rule_json -> 'target_ids')
             ? actor.institution_id::text
        when 'unit' then
          actor.unit_id is not null
          and (
            coalesce((eligible_notice.rule_json ->> 'select_all')::boolean, false)
            or (eligible_notice.rule_json -> 'target_ids') ? actor.unit_id::text
          )
        when 'group' then
          actor.group_id is not null
          and (
            coalesce((eligible_notice.rule_json ->> 'select_all')::boolean, false)
            or (eligible_notice.rule_json -> 'target_ids') ? actor.group_id::text
          )
        when 'person' then
          coalesce((eligible_notice.rule_json ->> 'select_all')::boolean, false)
          or (eligible_notice.rule_json -> 'target_ids') ? actor.person_id::text
        else false
      end
    )
    -- -----------------------------------------------------------------
    -- 3) Exclusao vence inclusao. excluded_ids pode nomear qualquer
    --    identificador ao qual o ator pertenca, em qualquer dimensao.
    -- -----------------------------------------------------------------
    and not exists (
      select 1
      from jsonb_array_elements_text(
        coalesce(eligible_notice.rule_json -> 'excluded_ids', '[]'::jsonb)
      ) as excluded(value)
      where excluded.value in (
        actor.institution_id::text,
        coalesce(actor.unit_id::text, ''),
        coalesce(actor.group_id::text, ''),
        actor.person_id::text,
        actor.membership_id::text
      )
    )
    -- -----------------------------------------------------------------
    -- 4) Exclusao defensiva por public.notice_rules.
    --    Nenhum comando do repositorio popula notice_rules hoje, entao na
    --    pratica este predicado nao remove nada. Ele existe para que, se a
    --    tabela voltar a ser escrita, a exclusao continue vencendo.
    --    NAO ha inclusao por notice_rules aqui, de proposito.
    --
    --    CONFIRMAR: public.target_type nao tem valor 'person'; exclusao por
    --    pessoa so existe em audience_json.excluded_ids, tratada no item 3.
    --    CONFIRMAR: rule.segment_id / public.audience_segments
    --    (expression_json) nao sao interpretados aqui. Nenhum comando do
    --    repositorio cria segmentos; se passarem a existir, o segmento
    --    precisa ser avaliado antes da promocao desta funcao.
    -- -----------------------------------------------------------------
    and not exists (
      select 1
      from public.notice_rules rule
      where rule.notice_id = eligible_notice.id
        and rule.effect = 'exclude'
        and (
          (rule.target_type = 'platform')
          or (rule.target_type = 'institution' and rule.target_id = actor.institution_id)
          or (rule.target_type = 'unit'        and rule.target_id = actor.unit_id)
          or (rule.target_type = 'group'       and rule.target_id = actor.group_id)
          or (rule.role_filter is not null     and rule.role_filter = actor.role_code)
        )
    )
    -- -----------------------------------------------------------------
    -- 5) plan_ids.
    --    CONFIRMAR: audience_json aceita ate 50 planos, mas o vinculo do
    --    ator resolvido acima nao carrega plano. Falta confirmar qual
    --    coluna liga public.institution_memberships ou public.institutions
    --    a public.plans / subscriptions no escopo do ator. Enquanto isso,
    --    plan_ids preenchido NAO amplia nem restringe o resultado; quem
    --    decide continua sendo a regra de dimensao do item 2.
    --    Decisao pendente do Owner: plan_ids preenchido deve virar gate
    --    adicional fail-closed ou permanecer apenas rotulo de audiencia?
    -- -----------------------------------------------------------------
  order by
    priority_rank asc,
    coalesce(eligible_notice.starts_at, eligible_notice.published_at,
             eligible_notice.created_at) desc,
    eligible_notice.id desc
  limit p_limit;
end
$function$;

-- A assinatura tem dois argumentos (text, int); os comandos de privilegio
-- abaixo precisam nomear exatamente essa assinatura.
revoke all on function public.list_my_principal_for_you(text, int)
  from public, anon, authenticated;
grant execute on function public.list_my_principal_for_you(text, int) to authenticated;

comment on function public.list_my_principal_for_you(text, int) is
  'Leitura autorizada do hub Principal / Para Voce. Resolve o ator pelo auth.uid() e aplica tipo, destino (p_target_device, allowlist all/web/mobile/tablet), vigencia e audiencia no servidor. Nao expoe popup, notice nem critical_notice. Proposta nao aplicada (E2 R02 L03).';

-- =====================================================================
-- NOTAS DE PROMOCAO (para D00/L00, nao executar daqui)
-- 1. Renumerar como migration forward-only propria em
--    packages/coelo_database/migrations/ com timestamp novo.
-- 2. Avaliar indice de apoio em public.platform_notices para
--    (notice_type, status, target_device, starts_at) antes de carga real.
--    CONFIRMAR: indices existentes de platform_notices nao foram
--    inventariados neste pacote.
-- 3. Testes cross-tenant obrigatorios antes de aceite: ator da instituicao
--    A nao pode ver comunicacao dirigida so a instituicao B, unidade B ou
--    turma B; ator excluido por excluded_ids nao pode ver mesmo quando a
--    regra e 'platform'; nenhum popup/notice/critical_notice pode sair;
--    comunicacao com target_device='mobile' nao pode sair para um chamador
--    que declarou 'web'; p_target_device fora da allowlist deve falhar.
-- 4. Nao remover nem alterar as RPCs _v2 do Superadmin.
-- =====================================================================
