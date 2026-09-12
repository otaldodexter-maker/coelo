-- ESPELHO LOCAL SOMENTE. Nao e migration de producao nem novo lote.
-- C0 R09 rev102: producao tem postgres/service_role; espelho tinha tambem
-- authenticated. Corpos das duas funcoes conferidos por hash nas duas bases.
-- Reconciliar o grant divergente antes de certificar o teste de autorizacao.
begin;
revoke execute on function public.form_media_authorize_for_worker(uuid,uuid,text) from authenticated;
commit;
