---
title: Identidade e acesso de Usuários Internos do Superadmin
knowledge_id: superadmin-internal-users
source: decisions/0019-superadmin-internal-identity.md
status: validated
generated_at: 2026-08-05
audience: team
surfaces: [superadmin, internal-users, access, permissions]
visibility: internal
review_owner: Coelo Product
---

# Usuários Internos do Superadmin

Usuário Interno possui identidade e credencial exclusivas do Superadmin. O
cadastro não nasce de Pessoas, não recebe `@` e não compartilha acesso, sessão,
recuperação, perfil ou escopo com Admin ou Principal.

Identidade, credencial, vínculo, perfil, escopo e convite são conceitos
separados. O perfil Superadmin define o teto de autorização; o vínculo guarda o
alcance efetivo. Permissões são derivadas e não são editadas individualmente.

Suspensão é reversível. Revogação do vínculo é terminal e um retorno exige novo
vínculo e novo convite, preservando o ciclo anterior. O último Owner ativo e
global não pode ser suspenso, revogado, rebaixado ou limitado.

O preview atual é exclusivamente local e fake. Não representa Supabase, Auth,
envio de e-mail, sessão, enforcement, auditoria ou persistência produtiva.
