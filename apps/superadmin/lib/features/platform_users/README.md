---
source: "docs/superpowers/specs/2026-07-29-superadmin-internal-users-preview-design.md; docs/product/prd-superadmin.md"
status: "approved-preview"
generated_at: "2026-07-29"
---

# Platform Users

Usuário interno possui identidade e credencial próprias, exclusivas do
Superadmin. Não reutiliza Pessoas, `@`, conta, sessão, recuperação, perfil ou
escopo de Admin e Principal.

Esta feature implementa somente um preview local nas rotas `/dev`: diretório,
criação, visualização e edição. Owner possui ações de apresentação; Auditor
visualiza; os demais cenários demonstram sem permissão. Isso não representa
autorização produtiva.

O repositório fake mantém identidade, credencial, vínculo, convite e histórico
independentes, valida CPF/e-mail únicos, compatibilidade entre perfil e escopo,
revogação terminal e proteção do último Owner. Toda ação informa que é uma
demonstração local. MFA, Auth, Supabase, RLS, RPCs e auditoria produtiva ficam
fora.

Instituições é a baseline visual direta para menu, toolbar, filtros, cards,
tabela, ações Criar, hover/foco e paginação sticky.
