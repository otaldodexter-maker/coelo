---
title: Assiduidade e Chamada no Superadmin
knowledge_id: superadmin-attendance-prototype
source: specs/020-superadmin-attendance-prototype.md
status: validated
generated_at: 2026-08-06
audience: team
surfaces: [superadmin, attendance]
visibility: internal
review_owner: Coelo Product
---

# Assiduidade e Chamada no Superadmin

Assiduidade separa intenção familiar de registro oficial. Aviso familiar pendente não altera chamada nem KPI; somente a confirmação profissional cria o registro oficial. O sino pode navegar diretamente para a chamada e o participante relacionados.

O diretório não usa dashboard inicial: `Nova chamada` é uma ação simples em card. Quando o contexto mínimo é válido, `Chamada` pode ser acessada diretamente pela navegação lateral. Presente, Falta, Atraso e Saída antecipada permanecem disponíveis por aluno; marcar todos é apenas um atalho.

A presença é `(presente + atraso + saída antecipada) / registros oficiais`. Chamadas não exigidas, não previstas e avisos pendentes não entram no denominador. Conclusão exige todos os participantes marcados e operações em lote preservam exceções já preenchidas.

Permissões são contextuais e tipadas: Owner administra e corrige; leitura não recebe ações; professor acessa somente o vínculo atribuído e opera o mesmo fluxo canônico `Lançar chamada`, sem prévia paralela. Correção exige motivo e preserva revisão antes/depois.