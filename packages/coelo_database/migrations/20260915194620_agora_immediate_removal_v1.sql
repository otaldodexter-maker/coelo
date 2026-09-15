-- R14 Bloco E / ADR 0040 / action_id agora.remove.
-- O enum precisa ser confirmado antes de qualquer migration que use o novo
-- literal; por isso este passo e deliberadamente isolado.
alter type public.now_publication_status add value if not exists 'removed';
