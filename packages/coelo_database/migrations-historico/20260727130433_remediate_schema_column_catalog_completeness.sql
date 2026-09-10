-- Remediate schema column catalog completeness.

with target_columns(table_name, column_name) as (
  values
    ('activity_definitions', 'distribution_scope'),
    ('activity_definitions', 'governance_kind'),
    ('activity_definitions', 'promoted_by_person_id'),
    ('activity_definitions', 'promoted_at'),
    ('activity_group_links', 'participation_mode'),
    ('conversations', 'unit_id'),
    ('conversations', 'group_id'),
    ('conversations', 'activity_id'),
    ('conversations', 'routing_team_id'),
    ('conversations', 'is_read_only'),
    ('conversations', 'read_only_reason'),
    ('guardian_links', 'relationship_type_id'),
    ('guardian_links', 'relationship_detail'),
    ('invitations', 'invitation_state'),
    ('invitations', 'unit_id'),
    ('invitations', 'group_id'),
    ('invitations', 'invited_by'),
    ('invitations', 'target_contact_hash'),
    ('invitations', 'masked_destination'),
    ('invitations', 'sent_at'),
    ('invitations', 'last_sent_at'),
    ('invitations', 'send_count'),
    ('invitations', 'accepted_by'),
    ('messages', 'author_membership_id'),
    ('messages', 'author_experience_kind'),
    ('messages', 'author_role_snapshot')
),
unique_columns as (
  select ns.nspname as table_schema,
         rel.relname as table_name,
         att.attname as column_name
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace ns on ns.oid = rel.relnamespace
  join pg_attribute att
    on att.attrelid = rel.oid
   and att.attnum = any(con.conkey)
  where con.contype in ('p', 'u')
    and array_length(con.conkey, 1) = 1
),
column_catalog as (
  select st.id as schema_table_id,
         c.column_name,
         case c.column_name
           when 'person_id' then 'Pessoa'
           when 'institution_id' then 'Instituicao'
           when 'unit_id' then 'Unidade'
           when 'group_id' then 'Grupo'
           else initcap(replace(c.column_name, '_', ' '))
         end as column_label,
         'Campo ' || c.column_name || ' da tabela ' || st.table_label || '.'
           as column_description,
         case
           when c.data_type = 'USER-DEFINED' then c.udt_schema || '.' || c.udt_name
           when c.data_type = 'ARRAY' then c.udt_name
           else c.data_type
         end as column_type,
         (c.is_nullable = 'NO' and c.column_default is null) as is_required,
         (c.is_nullable = 'YES') as is_nullable,
         (uc.column_name is not null) as is_unique,
         (
           c.column_name = 'id'
           or c.column_name like '%\_id' escape '\'
           or c.column_name in (
             'status',
             'code',
             'slug',
             'scope_kind',
             'target_table',
             'target_domain',
             'event_name',
             'counter_name'
           )
           or c.column_name like '%\_at' escape '\'
         ) as is_filterable,
         coalesce(existing.is_importable, false) as is_importable,
         c.ordinal_position as position
  from target_columns target
  join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name = target.table_name
   and c.column_name = target.column_name
  join public.schema_tables st
    on st.schema_name = c.table_schema
   and st.table_name = c.table_name
   and st.status = 'active'
  left join unique_columns uc
    on uc.table_schema = c.table_schema
   and uc.table_name = c.table_name
   and uc.column_name = c.column_name
  left join public.schema_columns existing
    on existing.schema_table_id = st.id
   and existing.column_name = c.column_name
)
insert into public.schema_columns(
  schema_table_id,
  column_name,
  column_label,
  column_description,
  column_type,
  is_required,
  is_nullable,
  is_unique,
  is_filterable,
  is_importable,
  is_active,
  position,
  updated_at
)
select schema_table_id,
       column_name,
       column_label,
       column_description,
       column_type,
       is_required,
       is_nullable,
       is_unique,
       is_filterable,
       is_importable,
       true,
       position,
       now()
from column_catalog
on conflict (schema_table_id, column_name) do update set
  column_label = excluded.column_label,
  column_description = excluded.column_description,
  column_type = excluded.column_type,
  is_required = excluded.is_required,
  is_nullable = excluded.is_nullable,
  is_unique = excluded.is_unique,
  is_filterable = excluded.is_filterable,
  is_active = true,
  position = excluded.position,
  updated_at = now();
