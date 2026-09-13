---
source: R12-28/R12-32; R12-saude-cuidado-owner.md
status: local-green
generated_at: 2026-09-13
---

# R12-28 a R12-32 — Saúde, Cuidado e Medicação

O recorte atual já implementa: identificação da criança e bloqueio de troca
na edição; registros independentes de alergias/restrições e orientações com
operações individuais; formulário de medicação com data, horários, dias,
via, dose/unidade e responsável; e diretório que reúne os planos autorizados
por criança, com contexto de consulta.

Provas locais: `health_care_form_pages_test.dart`,
`health_care_detail_context_test.dart`,
`health_medication_plan_directory_page_test.dart` e
`medication_plan_ui_contract_test.dart`: 97 testes PASS. A suíte focal não
certifica rota real, reload no Supabase ou negativa cross-tenant; integração
permanece pending-verification. R12-33 (notificações) não foi promovido:
continua dependente de evento/destinatários server-side formalizados.
