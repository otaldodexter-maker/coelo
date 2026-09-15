---
title: Saúde e Cuidado centrados na criança
knowledge_id: health-care
source: specs/020-superadmin-health-care.md
status: validated
lifecycle: "current"
generated_at: 2026-08-04
updated_at: 2026-09-15
audience: team
surfaces: [superadmin, health-care, permissions, database]
visibility: internal
review_owner: Coelo Product
---

# Saúde e Cuidado centrados na criança

> **Overlay de execução — 15/09/2026.** A base produtiva já possui o recorte
> de coleções de cuidado usado pela R14: alergias e orientações são registros
> independentes, com adicionar/remover/reload, e o backend rejeita o 101º
> registro por coleção/entidade. A migration e o pgTAP remoto foram entregues
> pela Sessão D; o aceite central dos Owner items ainda é separado.

**Perfis de cuidado** reúnem identidade, alergias, restrições, sinais,
adaptações e orientações permanentes. **Planos de medicação** reúnem
medicamento, vigência, horários, responsáveis, revisão e doses periódicas.

Status da alergia e gravidade do episódio são independentes; a gravidade não
prevê reação futura. O perfil usa linguagem de apoio, sem semáforo clínico.
O limite técnico defensivo de 100 é proteção de integridade, não limite de
produto; a coleção pode conter vários registros válidos.

O acesso exige contexto infantil ativo e autorização familiar. Operação de
outro tenant não se torna global. Claims de dose e recibos de ciência são
distintos. A UI demonstrativa usa `/health-care/profiles` e
`/health-care/medication-plans`; o recorte atual possui migrations de coleção,
mas não autoriza inferir que Medicação ou todos os fluxos de Saúde estão
implementados.
