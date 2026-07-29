---
title: "Governança de perfis de acesso"
source: "specs/018-profiles-permissions-superadmin.md; decisions/0003-multitenancy.md; decisions/0004-auth-permissions.md; inspeção read-only do Supabase em 2026-07-29; decisões aprovadas pelo usuário em 2026-07-29"
status: "accepted"
generated_at: "2026-07-29"
---

# ADR 0017 — Governança de perfis de acesso

## Contexto

O banco possui papéis reutilizáveis distintos para plataforma e instituição,
enquanto o Principal usa capacidades contextuais por vínculo familiar. Uma
matriz transversal única confundiria entidades e autoridades diferentes.
Também faltavam comandos server-side para edição segura, anti-escalation,
concorrência e auditoria.

## Decisão

1. A central administrativa vive no Superadmin e apresenta conjuntos separados
   para Superadmin, Admin e Principal.
2. “Perfil de acesso” é apresentação de `platform_roles` ou
   `institution_roles`; não substitui membership nem perfil de usuário/social.
3. Principal permanece catálogo e impacto read-only.
4. Perfil define escopo máximo; vínculo define escopo efetivo contido.
5. Governança de plataforma e institucional usa capacidades distintas:
   `platform.roles.manage` e `institution.roles.manage`.
   Novos perfis Admin criados no Superadmin são bases globais reutilizáveis;
   `is_system` é derivado pelo servidor e nunca aceito do cliente.
6. Toda mutação passa por RPC autenticada, transacional, versionada, idempotente
   e auditada.
7. Deny explícito prevalece. Owner deixa de depender de bypass implícito por
   código e mantém autoridade por grants explícitos.
8. Perfis base são editáveis e excluíveis. Perfil em uso exige realocação; a
   última autoridade total exige substituto ativo com MFA.
9. O editor visual permanece privado à feature. Não nasce componente público,
   token ou variante de Design System.
10. O rodapé de paginação de Instituições torna-se composição compartilhada
    apenas dentro do Superadmin, sem mudar sua aparência.

## Consequências

- Superadmin e Admin preservam catálogos e políticas independentes.
- A UI não calcula autorização nem proveniência por conta própria.
- O banco ganha escopo máximo, versão e RPCs de governança.
- A gestão individual de capacidades familiares fica para o fluxo de
  Pessoas/Família.
- Instituições deve manter seus goldens após a extração do rodapé.
