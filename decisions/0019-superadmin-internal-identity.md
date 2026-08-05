---
title: "Identidade interna exclusiva do Superadmin"
source: "Decisão aprovada pelo Owner Coelo em 2026-08-05; docs/product/prd-superadmin.md; specs/023-superadmin-internal-users-local-preview.md; decisions/0017-access-profile-governance.md"
status: "accepted"
generated_at: "2026-08-05"
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
