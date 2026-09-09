---
title: Identidade e acesso de Usuários Internos do Superadmin
knowledge_id: superadmin-internal-users
source: decisions/0019-superadmin-internal-identity.md
status: validated
generated_at: 2026-08-27
updated_at: 2026-09-09
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

O aditivo de 2026-09-01 da ADR 0019 supersede temporariamente a exigência
anterior de MFA: durante a validação do MVP, o realm interno aceita AAL1 e
AAL2 sem bloquear login, bootstrap, contexto ou comando por MFA, inclusive
Owner e capacidades `requires_mfa`. Os demais controles permanecem vigentes.
A reativação exige decisão nominal no gate formal do MVP e regressão própria;
`requires_mfa` não concede autorização no cliente.

Suspensão é reversível. Revogação do vínculo é terminal e um retorno exige novo
vínculo e novo convite, preservando o ciclo anterior. O último Owner ativo e
global não pode ser suspenso, revogado, rebaixado ou limitado.

O preview de Usuários Internos referido no contrato original é local e usa
dados simulados; ele não prova convite, enforcement, auditoria ou persistência
produtiva. A [spec Auth-first de 01/09/2026](../../superpowers/specs/2026-09-01-superadmin-auth-first-local-green-design.md)
autoriza separadamente recuperação, callback e redefinição locais do
Superadmin. O aceite FE local de Auth não amplia o contrato de convite nem
comprova execução em produção.

A recuperação mantém uma sessão restrita em memória para redefinir a senha.
Com a remoção do armazenamento concluída, reinicializar depois de consumir o
callback exige outro link. Falha permanente de remoção pode reter a credencial;
a proteção cliente não substitui a autorização no servidor. O controle backend
comprovado localmente exige AMR `password` da mesma sessão validada para obter
contexto interno e nega recovery/OTP, inclusive após refresh. A prova usa
reinicialização de SDK, scope e rotas em teste com backend local real, não reinício
do sistema operacional nem falha real do storage do navegador. Esse controle
não é apresentado como implantado em produção. Após trocar a senha, o app
encerra a sessão de recuperação e retorna ao Login.
