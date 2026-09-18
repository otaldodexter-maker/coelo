---
title: "Perfil transversal e perfil de funcionário no Principal (OQ-044, owner.r12-19/23)"
source: "docs/open-questions.md (OQ-044); decisions/0041-owner-decisions-r14-mesa-20260916.md (B7); docs/reviews/archive/rounds/R12/R12-perfis-permissoes-owner.md (R12-19, R12-23); specs/018-profiles-permissions-superadmin.md; docs/archive/superpowers/specs/2026-09-01-superadmin-access-health-care-finalization-design.md; dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.access_profile_templates (+ _platform_permissions, _institution_permissions, _principal_capabilities), public.platform_roles, public.institution_roles, public.platform_memberships, public.institution_memberships, public.guardian_permission_capabilities"
status: "draft-for-review"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Perfil transversal e perfil de funcionário no Principal

Spec **sem prova** (ADR 0041 B7: contrato decidido para a R15; nada executado
na R14). Resolve OQ-044 e os Owner items `r12-19` (Modelos × Perfis) e
`r12-23` (perfil de funcionário no Principal). Só documento; nenhuma migration
ou tela nasce desta spec sem recorte próprio.

## Problema

A UX aprovada em 01/09 organiza o catálogo por aplicativo › módulo › tela ›
ação e permite ao perfil superior selecionar capacidades das hierarquias
inferiores. O schema físico mantém cada perfil preso a um domínio
(`platform_roles` → Superadmin, `institution_roles` → Admin, capacidades de
responsável → Principal) e as atribuições vivem em entidades distintas
(`platform_memberships`, `institution_memberships`, `guardian_context_permissions`).
Hoje um "perfil transversal" não existe fisicamente; o CRUD de modelos
(`access_profile_templates`) já guarda as três tabelas de permissões por
modelo, mas materializar um único perfil cross-app exigiria inventar membership
ou ampliar autoridade.

## Decisão de contrato (proposta para o Owner ratificar)

Opção recomendada: **composição de modelos por domínio, sem agregado novo**.

1. **Modelo (template) é transversal; perfil é por domínio.** Um
   `access_profile_template` continua declarando ações dos três aplicativos.
   "Aplicar modelo" materializa **um perfil por domínio presente no modelo**:
   `platform_roles` (Superadmin), `institution_roles` por instituição (Admin) e,
   para o Principal, um **perfil de funcionário** (novo, abaixo). A ligação
   fica registrada em `template_id` + `template_version` em cada perfil
   materializado; alterar o modelo não altera perfis já aplicados (versão).
2. **r12-19 — diretório:** ordem "Modelos de perfis" e depois "Perfis" abaixo
   dos filtros; cada categoria mostra o domínio de aplicação. Suspeita de
   inversão funcional (Perfil abre como modelo não editável) é defeito a
   reproduzir por rota/entidade/repository antes de mexer — não é rótulo.
3. **r12-23 — perfil de funcionário no Principal.** Novo domínio `principal`
   em `institution_roles`? Não: cria-se `public.principal_staff_roles`
   (instituição, código, nome, `max_scope_kind` em `institution|unit|group`,
   `status`, `management_version`, `template_id/version`) e
   `public.principal_staff_role_capabilities` (capacidade do catálogo do
   Principal — `guardian_permission_capabilities` hoje é o único catálogo do
   Principal; será estendido com `audience='staff'`). A atribuição usa a
   `institution_memberships` existente (pessoa × instituição, `role_code`) +
   `institution_role_assignments`-equivalente escopado (unidade/turma). Uma
   pessoa pode ter **vários** perfis e vínculos com várias
   instituições/unidades; o Principal resolve o contexto ativo pela
   membership escolhida.
4. **Alcance ≠ aplicativo.** Aplicativo diz onde a ação existe; alcance
   (instituição/unidade/turma/atividade) vem da atribuição. Selecionar no
   Superadmin uma ação do Admin ou do Principal não concede nada sem uma
   membership ativa naquele domínio (regra do design de 01/09:
   `ação + aplicativo + vínculo ativo + alcance + tenant + ausência de deny`).
5. **Sem herança implícita entre apps.** Owner de plataforma não vira
   funcionário no Principal por inferência; a materialização é explícita.

## Backend (esboço; sem migration nesta spec)

- `superadmin_access_profile_template_apply_v1(p_request_id, p_template_id,
  p_expected_version, p_targets jsonb)` → cria/atualiza perfis por domínio
  listados em `p_targets` (`platform`, `institution:<id>`, `principal_staff:<id>`),
  recibo idempotente, auditoria por perfil criado, PT409 em versão defasada.
- `superadmin_principal_staff_role_*_v1` (list/detail/save/assign) no contexto
  interno (`require_superadmin_internal_context('institution.roles.manage')`).
- RLS deny-by-default; nenhuma leitura direta das tabelas novas por
  `authenticated`.

## Aceite (futuro recorte)

pgTAP: aplicar modelo cria um perfil por domínio, versão presa ao modelo,
cross-tenant negado, atribuição exige membership ativa; FE: diretório com
Modelos antes de Perfis e domínio visível; rota real: aplicar modelo com ações
dos três apps e ver três perfis; Principal hospedado com funcionário lendo o
contexto certo. Owner items `r12-19` e `r12-23` só fecham com essa prova.

## Pontos abertos para o Owner

- Ratificar a opção "composição por domínio" (ou pedir agregado transversal).
- Nome e escopo do catálogo de capacidades de funcionário no Principal.
