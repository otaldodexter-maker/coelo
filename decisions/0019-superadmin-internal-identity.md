---
title: "Identidade interna exclusiva do Superadmin"
source: "Decisão aprovada pelo Owner Coelo em 2026-08-05 e 2026-08-27; docs/product/prd-superadmin.md; specs/023-superadmin-internal-users-local-preview.md; decisions/0017-access-profile-governance.md"
status: "accepted"
generated_at: "2026-08-27"
---

# ADR 0019 — Identidade interna exclusiva do Superadmin

## Contexto

As fontes anteriores descreviam a equipe Coelo como pessoas globais ligadas a
`platform_memberships`. Essa composição mistura a identidade operacional do
Superadmin com cadastros, credenciais e relações do Admin e do Principal.

## Decisão

1. Usuário Interno possui identidade e credencial próprias, exclusivas do Superadmin.
2. A identidade interna não nasce de `people`, não recebe `@` e não reutiliza
   conta, sessão, recuperação, perfil ou escopo de Admin ou Principal.
3. Credencial, vínculo interno, perfil de acesso, escopo e convite são conceitos
   independentes. Perfil define o teto; vínculo guarda o alcance efetivo.
4. Perfis atribuíveis vêm exclusivamente do catálogo Superadmin e podem ser
   predefinidos ou personalizados. Permissões permanecem derivadas do perfil.
5. Suspensão do vínculo é reversível. Revogação é terminal; retorno exige novo
   vínculo e novo convite, preservando o ciclo anterior.
6. O último Owner ativo e global não pode ser suspenso, revogado, rebaixado ou
   receber escopo incompatível.
7. Uma associação futura com uma identidade de Admin ou Principal será
   explícita, verificada e apenas referencial, sem compartilhar autorização.
8. O modelo físico atual não é alterado. Produção exige spec técnica, threat
   model, migração e autorização próprias.

## Consequências

- Pessoas deixa de ser fonte de criação ou busca para Usuários Internos.
- O preview local usa agregado e comandos fake próprios, sem alegar enforcement
  ou persistência produtiva.
- O desenho físico atual fica registrado como dívida de migração, não como
  arquitetura futura aprovada.

## Aditivo 2026-08-27 — realm, sessão e MFA internos

**Decisão aprovada pelo Owner Coelo em 2026-08-27.** Superadmin, Admin e
Principal permanecem no mesmo projeto Supabase, mas cada Usuário Interno usa
conta distinta em `auth.users` e e-mail distinto da conta que a mesma pessoa
eventualmente use no Admin ou no Principal. O vínculo dessa conta com a
identidade interna é privado; sessão e autorização não são compartilhadas entre
o realm interno e o realm global.

O Owner exige AAL2 em todo contexto e comando, inclusive no bootstrap. Os
demais papéis seguem a exigência já aprovada de AAL2 apenas quando a capacidade
ativa tiver `platform_permissions.requires_mfa = true`.

Os detalhes contratuais de `auth_link` privado, revalidação de sessão e contexto
estão em `specs/039-superadmin-internal-auth-session-context.md`.

## Aditivo 2026-09-01 — supersessão temporária da exigência AAL2

**Decisão explícita do Owner Coelo em 2026-09-01.** Durante a validação do MVP,
o realm interno do Superadmin aceita AAL1 e AAL2 sem usar MFA como gate de
login, bootstrap, contexto ou comando, inclusive para Owner e para capacidades
marcadas `requires_mfa`. Este aditivo supersede temporariamente os dois
parágrafos de MFA do aditivo de 2026-08-27; a separação de identidade e todos os
demais controles dessa ADR permanecem vigentes.

O adiamento termina no gate formal de entrega do MVP. A reativação de MFA exige
decisão nominal, mudança forward-only, regressão e prova ponta a ponta próprias.
Até esse gate, `requires_mfa` é metadado observacional preservado para
compatibilidade, nunca fonte de autorização no cliente.
