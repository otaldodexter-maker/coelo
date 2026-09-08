---
title: "Planos — isolamento contextual do formulário"
source: "specs/051-superadmin-plans-production.md"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

Quatro REDs confirmados: mesmo State não recarregava B após A; troca de repository
com mesmo ID conservava dados anteriores; sucesso de save após dispose chamava
onSaved; falha tardia chamava setState após dispose.

Correção local: didUpdateWidget detecta repository/ID, reinicia campos/etapa/
erros e invalida geração contextual. Cada leitura possui geração adicional;
save captura contexto e só aplica sucesso/erro/finally no contexto atual.
Guard single-flight evita segundo save simultâneo. Não cancela comando já
enviado no servidor nem promete desfazer persistência remota anterior à troca.

Sete novos testes cobrem A→B com comando dirigido a B/revisão7, repository trocado
com mesmo ID e negativa, save tardio sucesso/falha após troca e dispose, e
edição→criação com identidade/etapa reiniciadas. Suíte Plans: 35 testes verdes,
incluindo goldens existentes sem atualização de baselines. Analyzer e validator
visual limpos. Review independente sem blockers; nome de teste ajustado para
não alegar preparação do motivo que o caso não executa.

Comando: flutter test --no-pub test/features/plans (cwd apps/superadmin).

Nenhum router, flag, SQL ou ambiente remoto alterado. Gate E2E: helper da
migration 20260901183154 ainda usa current_person_id/has_platform_permission;
compatibilidade com realm interno requer pacote nominal próprio. Persistência,
reload, negativas e auditoria reais não demonstrados nesta fatia. Vínculos de
assinaturas continuam somente leitura. Memória no-op: contrato existente aplicado.
