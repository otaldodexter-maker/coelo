---
title: "Editor nominal — autosave serializado"
source: "Spec Forms 2026-08-13, Salvamento e prévia; aprovação central 2026-09-08"
status: "implemented-local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Contrato

Somente `FormsEditorPage.authoring`, sem SQL, rotas ou produção. Implementar
requisito já aprovado de salvamento automático e manual. Debounce de 800 ms
depois de edição real; navegação e hidratação não disparam comandos. Exigir
instituição e manage do contexto atual. Validação é de rascunho, nunca de
publicação: enquete incompleta continua salvável segundo contrato vigente.

Uma fila de save/receipt/expectedVersion. Edição durante save aguarda receipt e
novo debounce; confirmação antiga não significa que toda edição está salva.
Save manual cancela timer e usa a mesma fila. Erro/confirmação perdida/conflito
pausam automático até ação explícita. Retry preserva comando incerto; não
sobrescreve silenciosamente e não cria loop. Dispose, troca API/formId e negação
invalidam timer. Estados claros de alterações, salvando, salvo e falha.

# Ordem e prova

1. RED com relógio fake: burst e ausência de save em abertura.
2. RED serialização de edição em trânsito; manual versus timer.
3. Negativas de falha/confirmação perdida/conflito e contexto/dispose/negação.
4. Implementação mínima com notificações explícitas de edição, sem observar
   rebuilds como se fossem intenções do usuário.
5. Rodar suíte nominal e regressão Forms, analyzer, validator visual e review.
6. Evidência e handoff; integração e E2E continuam gates separados.

Estimativa local 40–65 min, sujeita a REDs; checkpoint 03:20 BRT preservado.
Não altera o escopo original de Respostas, Locais, Cuidado ou XLSX. Não cria
nova regra de produto nem conhecimento por atividade; trackers do Coordenador.
