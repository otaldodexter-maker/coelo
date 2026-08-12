---
title: Operação de planos de medicação
knowledge_id: medication-plans-production
source: specs/029-superadmin-medication-plans-production.md
status: validated
generated_at: 2026-08-12
audience: admin
surfaces: [admin, health-care, medication, child-care]
visibility: internal
review_owner: Coelo Product
---

# Operação de planos de medicação

Um plano registra criança, medicamento, dose, unidade, via, vigência, fuso,
dias, horários, responsáveis e prescrição. Na edição, a criança não muda; a
opção de troca apenas navega. Responsáveis são adicionados um por vez e não se
repetem no mesmo plano.

Profissionais autorizados registram administração, omissão ou recusa. Suspensão
preserva o histórico, e uma correção nunca apaga o evento original: exige motivo
e cria evidência auditada. Foto do medicamento e prescrição ficam privadas no
Supabase Storage e só são entregues após autorização do contexto infantil.

O contrato está aprovado para preparação técnica, mas permanece indisponível
para dados reais até aprovação jurídica da base legal e retenção. A interface
não simula cadastro, upload ou sucesso enquanto esse gate estiver fechado.
