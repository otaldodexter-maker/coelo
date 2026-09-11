-- 20260911190100_agenda_requests_labels_v1
--
-- Rotulos legiveis nos pedidos da Agenda (achado da frente publicacoes-agenda
-- na rota real de 11/09/2026, R05: a tela Aprovacoes de publicacao mostrava
-- "Evento <uuid>", o UUID da instituicao e o UUID da pessoa que pediu/decidiu,
-- porque superadmin_agenda_requests devolve to_jsonb(linha) sem juntar nomes).
--
-- O que este pacote faz: mantem assinatura, guarda (agenda.manage_responses),
-- ordem e paginacao de superadmin_agenda_requests e acrescenta, por linha,
-- title (titulo do evento), institution_name, requested_by_name e
-- decided_by_name (display_name da pessoa; pessoa de servico da ponte de ator
-- aparece com o nome de servico). Nenhum dado fora do escopo ja autorizado:
-- quem le pedidos ja le o evento e a instituicao pela mesma capacidade.
-- Forward-only; idempotente (create or replace).

begin;

create or replace function public.superadmin_agenda_requests(
  p_kind text default 'publication',
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform app_private.assert_agenda_permission('agenda.manage_responses', false);
  if p_kind = 'publication' then
    select coalesce(jsonb_agg(to_jsonb(r) order by r.requested_at desc, r.id), '[]'::jsonb)
      into v_result
    from (
      select request.*,
        event.title,
        institution.public_name as institution_name,
        requester.display_name as requested_by_name,
        decider.display_name as decided_by_name
      from public.agenda_publication_requests request
      left join public.agenda_events event on event.id = request.event_id
      left join public.institutions institution on institution.id = request.institution_id
      left join public.people requester on requester.id = request.requested_by_person_id
      left join public.people decider on decider.id = request.decided_by_person_id
      where p_status is null or request.status = p_status
      order by request.requested_at desc, request.id
      limit p_limit offset p_offset
    ) r;
  elsif p_kind = 'guardian' then
    select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc, r.id), '[]'::jsonb)
      into v_result
    from (
      select *
      from public.agenda_guardian_requests
      where p_status is null or status = p_status
      order by created_at desc, id
      limit p_limit offset p_offset
    ) r;
  else
    raise exception using errcode = '22023', message = 'invalid_request_kind';
  end if;
  return v_result;
end;
$$;

commit;
