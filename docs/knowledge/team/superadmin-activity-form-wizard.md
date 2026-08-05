---
title: Wizard de atividade do Superadmin
knowledge_id: superadmin-activity-form-wizard
source: docs/superpowers/specs/2026-08-04-superadmin-activity-form-wizard-design.md
status: validated
generated_at: 2026-08-04
audience: team
surfaces: [superadmin, activities]
visibility: internal
review_owner: Coelo Product
---

# Wizard de atividade do Superadmin

Criar e Editar Atividade usam um wizard responsivo de quatro etapas preparado para integração por callbacks. Salvar rascunho exige nome, instituição e ao menos uma unidade; concluir também exige ao menos uma turma.

Locais internos são drafts opcionais vinculados à unidade, e profissionais são atribuídos por turma com Happens, Now, Moments e Chat ativados por padrão. Esta entrega não persiste dados nem concede autorização efetiva e não altera Supabase, Grupos ou Unidades.
