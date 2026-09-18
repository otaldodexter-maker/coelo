---
title: "Respostas — uma seção por página"
source: "Spec Forms 2026-08-13:201; aprovação central explícita 2026-09-08"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Desenho delimitado

Apresentar uma seção por vez, anterior/próxima e progresso textual/visual com
semântica acessível. Identidade da seção e dos campos por ID, não por índice.
Manter campos fora de tela sem perder texto transitório inválido; excluir foco
e semântica das seções não apresentadas. Seções compostas só de ramos ocultos
não contam no progresso; blocos informativos visíveis e seções vazias mantêm
seu contexto. Se a seção atual sair do conjunto, selecionar destino válido.

Navegar não salva por si, não submete e não limpa respostas/invalidade; autosave
pendente continua sob a mesma fila. Ramos ocultos continuam fora do payload.
Revisão é global e leva o foco ao cabeçalho da primeira seção com erro visível,
antes do envio explícito. Foco/scroll tardio obedece geração e seção atuais.

# Alternativas e escolha

Reconstruir somente a seção visível exigiria uma segunda fonte de valores crus
para campos inválidos. PageView/IndexedStack mantém estado, mas introduz gesto
ou altura da maior página. Escolha local: Offstage com exclusão de foco para
seções inativas, mantendo o estado de campos existentes e layout de uma seção.
Não altera contrato nem o carregamento remoto atual.

# Ordem e evidência

REDs de página/progresso, preservação em navegação, erro global/foco, seções
condicionais e troca de contexto; controles de autosave, teclado e375px/200%.
Implementação mínima com tokens/componentes atuais; regressão Forms, analyzer,
validator visual, review independente e handoff. Estimativa35–50min; checkpoint
03:20BRT mantido. Sem endpoint, SQL, mídia, anonimato ou realm. E2E separado.
