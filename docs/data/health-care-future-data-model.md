---
title: "Proposta futura de dados para Saúde e Cuidado"
source: "specs/020-superadmin-health-care.md; docs/data/data-model.md; docs/security/lgpd-security-media.md; packages/coelo_database/migrations; decisions/0010-private-media-r2.md"
status: "proposed"
generated_at: "2026-08-04"
lifecycle: "future"
updated_at: "2026-09-15"
reconciled_with: "AGENTS.md; decisions/0032; decisions/0034; decisions/0038; docs/reviews/etapa-2-operacao/next-round/R14-handoff-sessao-2.md"
---

> **Documento futuro — não é modelo produtivo atual.** Esta proposta não
> autoriza tabela, migration, RLS, RPC, grant ou retenção. A política de mídia
> vigente é a ADR 0032 (R2 privado e catálogo Postgres); a ADR 0010 permanece
> apenas como histórico. Qualquer abertura exige spec e decisão próprias.

> **Overlay de execução — 15/09/2026.** Parte desta proposta deixou de ser
> apenas futura: as tabelas de coleções de Saúde e Cuidado já existem no
> modelo aplicado, e a Sessão D registrou em produção o limite defensivo de
> 100 registros por coleção/entidade, com rejeição do 101º. Este documento
> continua `future` para as entidades, contratos e fluxos ainda não aprovados;
> não use a frase histórica “não há tabelas produtivas” como instrução atual.

# Proposta futura de dados para Saúde e Cuidado

## Limites

A proposta separa dados permanentes de cuidado da operação periódica de
medicamentos. Ela não aprova novos nomes físicos, migrations, RLS, RPCs, grants
ou retenção para as partes ainda futuras. O recorte já aplicado em produção é
limitado às coleções de cuidado e ao guard de 100 registros; o restante deste
documento continua sujeito a spec, decisão e aceite próprios.

## Perfis de cuidado

Entidades candidatas: `child_health_access_grants`,
`child_care_profiles`, `child_allergy_restrictions`,
`care_profile_catalog` e `child_care_profile_items`. O perfil guarda sinais,
adaptações e orientações; alergia guarda status, último episódio, reação,
orientação, observações e gravidade do episódio.

Status da alergia e gravidade do episódio são independentes. Inativação
substitui exclusão física. O perfil não recebe classificação clínica por cor.

## Planos de medicação

Entidades candidatas: `child_medication_plans`,
`child_medication_plan_versions`, `child_medication_schedules`,
`child_medication_reviews`, `medication_dose_occurrences`,
`medication_dose_claims` e políticas/notificações privadas do tenant.

Edição relevante cria versão, invalida reviews e preserva ocorrências. Horário
usa XOR entre casa e instituição. Frequência deriva dos horários. Claim ativo
é único e adquirido por operação atômica.

## Isolamento, auditoria e mídia

Leitura exige sessão, contexto infantil ativo e autorização familiar vigente.
Reviews, políticas, claims e doses são tenant-owned. Comandos sensíveis futuros
usam RPC/Edge Function com autorização, idempotência e auditoria minimizada.
Documentos privados referenciam R2; URL pública e segredo não entram no Flutter.

## Gate futuro

Antes de migration: resolver `OQ-003`, aprovar contrato R2, threat model e
spec técnica, validar nomes contra o schema vigente e obter revisão humana de
segurança, LGPD e isolamento multi-tenant.
