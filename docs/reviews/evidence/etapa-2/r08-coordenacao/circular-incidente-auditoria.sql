-- Somente a fixture nominal do incidente; sem object_key, URLs ou conteúdo.
select current_timestamp as measured_at,
  (select jsonb_build_object('exists',true,'status',status,'deleted',deleted_at is not null)
   from public.circulars where id='aa9e26a6-2874-4e19-ac79-a41f56c44468') as circular,
  (select jsonb_build_object('exists',true,'status',status,'bytes',byte_size,
    'cleanup_attempted',cleanup_attempted_at is not null)
   from public.circular_media_assets where id='429f1bc4-f579-4179-9193-0e6304aa3e0f') as asset;
