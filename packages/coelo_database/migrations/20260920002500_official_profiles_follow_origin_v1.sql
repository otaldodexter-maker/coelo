-- Perfis oficiais — spec 068 (parte 1/2). Lote 95a.
-- `follow_origin` ganha 'official_auto' (seguir automático dos perfis oficiais). Fica numa
-- migration própria porque um valor novo de enum não pode ser usado na mesma transação em
-- que foi criado.
alter type public.follow_origin add value if not exists 'official_auto';
