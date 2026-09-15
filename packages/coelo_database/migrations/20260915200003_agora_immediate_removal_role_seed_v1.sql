-- R14 Bloco E / ADR 0040 / action_id agora.remove.
-- A permissao entrou depois do seed historico de papeis; atualiza somente o
-- papel sistemico institution_admin, sem ampliar teacher/reader/coordinator.
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.institution_roles role_record
cross join public.institution_permissions permission_record
where role_record.institution_id is null
  and role_record.is_system
  and role_record.code='institution_admin'
  and permission_record.code='now.publications.remove'
  and permission_record.status='active'
  and not exists(
    select 1 from public.institution_role_permissions existing
    where existing.role_id=role_record.id and existing.permission_id=permission_record.id
      and existing.status='active' and existing.revoked_at is null
  );
