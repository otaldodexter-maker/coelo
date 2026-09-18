---
title: "Cuidado — negar comandos iniciados após descarte"
source: "Revisão read-only do controller; contrato de ciclo de vida e contexto vigente"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

Recorte local: cinco métodos de mutação de HealthCareController. Callback
retido não pode iniciar repository depois de dispose. Rejeitar com StateError,
não retornar sucesso sem escrita. Não cancela uma escrita iniciada antes do
descarte; seu refresh continua protegido pela implementação anterior.
Nenhuma mudança de autorização clínica, SQL, rota, dados reais ou política.

Ordem: cinco REDs parametrizados, guard mínimo antes do repository, controles
ativos e em trânsito existentes, regressão funcional de Cuidado, analyzer,
review e handoff. Estimativa 10–15 min. E2E e gates sensíveis continuam abertos.
