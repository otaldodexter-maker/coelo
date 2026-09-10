-- Enum changes are isolated so later migrations can safely use the committed values.
alter type public.notice_status add value if not exists 'active';
alter type public.notice_status add value if not exists 'paused';
alter type public.notice_status add value if not exists 'inactive';
