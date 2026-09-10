-- Cardapios: apagar imagem passa a exigir p_expected_revision.
--
-- A migration 20260820230000 criou a forma revisionada
-- public.meal_plan_request_image_delete(uuid, uuid, integer), mas manteve
-- exposta a forma legada de dois argumentos, que le a revisao atual do proprio
-- banco e a repassa como "esperada". Com grant para authenticated, essa forma
-- anula o controle otimista: a exclusao sempre encontra a revisao que acabou de
-- ler e nunca levanta P0003, mesmo quando o cardapio mudou entre a leitura do
-- cliente e a confirmacao. O repositorio Flutter chamava justamente essa forma.
--
-- Aqui a porta legada e removida das duas camadas. A forma revisionada continua
-- sendo a unica exposta a authenticated, e o cliente passa a enviar a revisao
-- que leu.
begin;

drop function if exists public.meal_plan_request_image_delete(uuid, uuid);
drop function if exists app_private.meal_plan_request_image_delete(uuid, uuid);

revoke all on function public.meal_plan_request_image_delete(uuid, uuid, integer)
  from public, anon, service_role;
grant execute on function public.meal_plan_request_image_delete(uuid, uuid, integer)
  to authenticated;
revoke all on function app_private.meal_plan_request_image_delete(uuid, uuid, integer)
  from public, anon, authenticated, service_role;

commit;
