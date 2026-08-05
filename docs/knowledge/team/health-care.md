---
title: Saúde e Cuidado centrados na criança
knowledge_id: health-care
source: specs/020-superadmin-health-care.md
status: validated
generated_at: 2026-08-04
audience: team
surfaces: [superadmin, health-care, permissions, database]
visibility: internal
review_owner: Coelo Product
---

# Saúde e Cuidado centrados na criança

**Perfis de cuidado** reúnem identidade, alergias, restrições, sinais,
adaptações e orientações permanentes. **Planos de medicação** reúnem
medicamento, vigência, horários, responsáveis, revisão e doses periódicas.

Status da alergia e gravidade do episódio são independentes; a gravidade não
prevê reação futura. O perfil usa linguagem de apoio, sem semáforo clínico.

O acesso exige contexto infantil ativo e autorização familiar. Operação de
outro tenant não se torna global. Claims de dose e recibos de ciência são
distintos. A UI demonstrativa usa `/health-care/profiles` e
`/health-care/medication-plans`; nenhuma migration foi criada.
