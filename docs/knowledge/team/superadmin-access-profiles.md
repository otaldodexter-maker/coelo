---
title: Perfis e Permissões do Superadmin
knowledge_id: superadmin-access-profiles
source: specs/018-profiles-permissions-superadmin.md
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [superadmin, admin, principal, authorization, database]
visibility: internal
review_owner: Coelo Product
---

# Perfis e Permissões do Superadmin

A central separa três domínios. Superadmin e Admin possuem perfis de acesso
reutilizáveis; Principal mantém capacidades por responsável e contexto e, por
isso, aparece somente como catálogo e impacto. A interface não cria um perfil
familiar genérico.

Perfis do Superadmin têm escopo máximo `platform` ou `institution`. Perfis do
Admin têm escopo máximo `institution`, `unit` ou `group`. A atribuição efetiva
sempre precisa ser igual ou mais restrita que o máximo do perfil.
Novos perfis Admin criados nesta central são bases globais reutilizáveis; o
servidor deriva `is_system` e a criação de perfis locais por instituição fica
fora desta entrega.

As capacidades `platform.roles.manage` e `institution.roles.manage` exigem MFA
e nascem concedidas somente ao Owner por grants explícitos. `deny` prevalece
sobre `allow`; o código do papel nunca concede autorização implicitamente.

Criação, edição e exclusão passam por RPCs autenticadas e auditadas. Mutações
recebem `request_id`, versão esperada, motivo e rascunho completo. O servidor
revalida sessão, MFA, autoridade, catálogo, escopo e concorrência. Perfis em
uso só podem ser excluídos com realocação na mesma transação, e uma alteração
não pode deixar a plataforma sem uma membership ativa, com MFA e autoridade
total explícita.
Somente uma membership ativa de escopo global de plataforma pode governar
esses perfis; memberships limitadas a uma instituição não recebem alcance
global por possuírem o mesmo papel.

Fixtures são determinísticas, rotuladas como “Dados de demonstração” e
restritas a dev, catálogo e testes. O repositório produtivo usa somente RPCs e
falha fechado quando a integração não está disponível.
