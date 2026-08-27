---
title: Identidade e acesso de Usuários Internos do Superadmin
knowledge_id: superadmin-internal-users
source: decisions/0019-superadmin-internal-identity.md
status: validated
generated_at: 2026-08-27
audience: team
surfaces: [superadmin, internal-users, access, permissions]
visibility: internal
review_owner: Coelo Product
---

# Usuários Internos do Superadmin

Usuário Interno possui identidade e credencial exclusivas do Superadmin. O
cadastro não nasce de Pessoas, não recebe `@` e não compartilha acesso, sessão,
recuperação, perfil ou escopo com Admin ou Principal.

Superadmin, Admin e Principal usam o mesmo projeto Supabase, mas o Usuário
Interno usa outra conta `auth.users` e outro e-mail. O backend liga essa conta a
uma credencial interna privada, deriva o ator de `auth.uid()` e revalida o
`session_id` da JWT em `auth.sessions`; e-mail, claims mutáveis, rotas e contexto
enviado pelo cliente nunca concedem autorização.

Identidade, credencial, vínculo, perfil, escopo e convite são conceitos
separados. O perfil Superadmin define o teto de autorização; o vínculo guarda o
alcance efetivo. Permissões são derivadas e não são editadas individualmente.
Uma instituição selecionada é apenas contexto efêmero: o backend resolve e
revalida a instituição e a capacidade em cada comando, sem persistir uma
“instituição atual” como autoridade.

O Owner exige AAL2 em todo contexto e comando, inclusive no bootstrap. Os
demais papéis exigem AAL2 somente quando a capacidade ativa tiver
`platform_permissions.requires_mfa = true`.

Suspensão é reversível. Revogação do vínculo é terminal e um retorno exige novo
vínculo e novo convite, preservando o ciclo anterior. O último Owner ativo e
global não pode ser suspenso, revogado, rebaixado ou limitado.

O preview atual é exclusivamente local e fake. Não representa Supabase, Auth,
envio de e-mail, sessão, enforcement, auditoria ou persistência produtiva.
Convite, recuperação e reset produtivos continuam fora do contrato aprovado.
