-- R05 realm-interno (16): reconciliacao com 20260911200000 (G7, Planos).
-- Meu 211000 (lote 42) concedeu SELECT em public.plans a authenticated para a
-- view institution_directory responder em leitura direta; o 200000 (lote 38)
-- decidiu o contrario, de proposito: "tabelas do catalogo continuam sem acesso
-- direto de cliente (RLS + sem grant)", membership escopada nao alcanca o
-- catalogo. Como o 211000 entrou depois, ele reabriu o grant. Este pacote
-- devolve o estado decidido pela G7: sem grant; institution_directory segue
-- servida por RPC (o cliente nao le a view diretamente).
-- Reversao: grant select on public.plans to authenticated (= 211000).
begin;
revoke select on table public.plans from authenticated;
commit;
