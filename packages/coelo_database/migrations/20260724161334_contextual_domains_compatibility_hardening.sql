-- Preserve the legacy guardian_links insert contract while normalizing every
-- new row into the catalog + detail model.

create or replace function app_private.normalize_guardian_relationship()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare normalized_code text;
begin
  if new.relationship_type_id is null then
    normalized_code := case lower(btrim(new.relation_type))
      when 'pai' then 'father'
      when 'father' then 'father'
      when 'mae' then 'mother'
      when 'mãe' then 'mother'
      when 'mother' then 'mother'
      when 'avo' then 'grandparent'
      when 'responsible' then 'other'
      when 'responsavel' then 'other'
      when 'responsável' then 'other'
      else 'other'
    end;

    if normalized_code = 'grandparent' then
      normalized_code := 'other';
    end if;

    select relationship.id into new.relationship_type_id
    from public.family_relationship_types relationship
    where relationship.code=normalized_code and relationship.status='active';

    if new.relationship_type_id is null then
      raise exception 'active family relationship type is missing';
    end if;
  end if;

  if new.relationship_detail is null then
    new.relationship_detail := nullif(btrim(new.relation_type),'');
  end if;
  return new;
end;
$$;

drop trigger if exists guardian_links_00_relationship_defaults
  on public.guardian_links;
create trigger guardian_links_00_relationship_defaults
before insert or update on public.guardian_links
for each row execute function app_private.normalize_guardian_relationship();

revoke all on function app_private.normalize_guardian_relationship()
  from public,anon,authenticated;
