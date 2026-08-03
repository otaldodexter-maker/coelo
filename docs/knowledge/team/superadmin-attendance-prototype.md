---
title: Assiduidade e Chamada no Superadmin
knowledge_id: superadmin-attendance-prototype
source: specs/020-superadmin-attendance-prototype.md
status: validated
generated_at: 2026-08-03
audience: team
surfaces: [superadmin, attendance]
visibility: internal
review_owner: Coelo Product
---

# Assiduidade e Chamada no Superadmin

Assiduidade separa intenção familiar de registro oficial. Aviso familiar pendente não altera chamada nem KPI; somente a confirmação profissional cria o registro oficial. O sino pode navegar diretamente para a chamada e o participante relacionados.

A presença é `(presente + atraso + saída antecipada) / registros oficiais`. Chamadas não exigidas, não previstas e avisos pendentes não entram no denominador. Conclusão exige todos os participantes marcados e operações em lote preservam exceções já preenchidas.

Permissões são contextuais e tipadas: Owner administra e corrige; leitura não recebe ações; professor acessa somente o vínculo atribuído. Correção exige motivo e preserva revisão antes/depois.
