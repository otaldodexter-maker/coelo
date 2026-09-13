-- R10 chat video: private MP4 only, same 10 MiB ceiling as Chat PDF.
-- No bucket, credential, retention, permission or read-path change.
create or replace function app_private.chat_attachment_limit_v1(p_content_type text)
returns bigint language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 4194304::bigint
    when 'image/png' then 4194304::bigint
    when 'image/webp' then 4194304::bigint
    when 'application/pdf' then 10485760::bigint
    when 'video/mp4' then 10485760::bigint
    else null end
$$;
create or replace function app_private.chat_attachment_extension_v1(p_content_type text)
returns text language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 'jpg' when 'image/png' then 'png'
    when 'image/webp' then 'webp' when 'application/pdf' then 'pdf'
    when 'video/mp4' then 'mp4' end
$$;
alter function app_private.chat_attachment_limit_v1(text) owner to postgres;
alter function app_private.chat_attachment_extension_v1(text) owner to postgres;
revoke all on function app_private.chat_attachment_limit_v1(text),
  app_private.chat_attachment_extension_v1(text) from public, anon, authenticated, service_role;
