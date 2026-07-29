---
source: "docs/superpowers/specs/2026-07-29-superadmin-internal-users-preview-design.md; docs/product/prd-superadmin.md"
status: "approved-preview"
generated_at: "2026-07-29"
---

# Platform Users

Usuário interno é uma pessoa global vinculada à equipe própria Coelo por
`platform_memberships`. Não é usuário institucional, administrador de tenant
ou responsável familiar.

Esta feature implementa somente um preview local nas rotas `/dev`: diretório,
criação, visualização e edição. Owner possui ações de apresentação; Auditor
visualiza; os demais cenários demonstram sem permissão. Isso não representa
autorização produtiva.

O repositório fake cria vínculo `invited` e convite `pending`, sempre com aviso
de que nenhum convite real foi enviado. Papéis e permissões são derivados do
catálogo físico confirmado. O menu Arquivos oferece importação e exportação
somente demonstrativas, sem arquivo, parser, download ou persistência real.
MFA, último acesso, Auth, Supabase, RLS, RPCs e auditoria produtiva ficam fora.

Instituições é a baseline visual direta para menu, toolbar, filtros, cards,
tabela, ações Criar, hover/foco e paginação sticky.
