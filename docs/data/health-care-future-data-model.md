---
title: "Proposta futura de dados para Saúde e Cuidado"
source: "specs/020-superadmin-health-care.md; docs/data/data-model.md; docs/security/lgpd-security-media.md; packages/coelo_database/migrations; decisions/0010-private-media-r2.md"
status: "proposed"
generated_at: "2026-08-04"
---

# Proposta futura de dados para Saúde e Cuidado

## Limites

A proposta separa dados permanentes de cuidado da operação periódica de
medicamentos. Não aprova nomes físicos, migration, RLS, RPC, grant ou retenção.
O schema atual não possui tabelas produtivas deste módulo.

A spec 029 e a ADR 0023 substituem esta condição somente para Planos de
medicação: autorizam a fundação técnica fail-closed e classificam foto do
medicamento e prescrição no Supabase Storage privado. Perfis de cuidado ainda
dependem de spec própria.

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

Para Planos de medicação, a fundação técnica pode existir com acesso fail-closed;
a ativação continua proibida até resolver `OQ-003` e `OQ-040` e aprovar o gate
`legal_basis_and_retention`. Perfis de cuidado ainda exigem spec técnica, threat
model e revisão humana antes de migration.
