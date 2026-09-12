---
fonte: R08-prompts.md; R08 backlog H10/H11; 2026-08-13-superadmin-forms-end-to-end-design.md
status: local-green; verificacao-integrada-pendente
data_geracao: 2026-09-12
---

# G3 — Audiência e autosave

Recorte: apps/superadmin -> Formulários -> agendamento/edição -> forms.schedule e forms.save-draft. Base 7bc243cdb. Não altera rastreadores centrais.

H10: o agendamento não reduz mais uma audiência múltipla, de exclusão ou de tipo não representável para uma regra simples. Exibe resumo honesto e conserva todas as regras anteriores. Instituição vem da definição autorizada. A implementação não amplia o editor de audiência; a composição dinâmica continua conforme a fonte canônica.

H11: o editor produtivo passa a usar o mesmo autosave de 800 ms do caminho nominal, preservando versão, alterações feitas durante envio, isolamento ao trocar contexto e request_id após resultado incerto. O resultado incerto continua exigindo conciliação antes de descarte.

Validação local: 112 testes do editor de contexto, 9 de agendamento e 95 do autor nominal aprovados, 216 IDs de testes neste pacote, 0 falhas atuais. O lote inicial executou também 11 testes do uploader e 128 da resposta em WIP, totalizando 355 testes, com 351 PASS e quatro falhas de pressupostos anteriores ao autosave. Essas quatro foram resolvidas; não somar os reruns. O primeiro rerun teve duas falhas restantes; o final terminou 112 PASS/0 FAIL. O ajuste de expectativas dos ramos lê o último comando confirmado; o descarte de formulário novo é exercitado antes do debounce; publicação sem rascunho confirmado é exercitada após falha do primeiro autosave. Análise estática focal: exit 0, sem issues.

Evidências: forms-h10-h11-gallery-tests.log (lote inicial), forms-autosave-rerun.log (intermediário), forms-autosave-final.log (112 PASS), forms-author-analyze.log (análise). Execução serial no slot G3 autorizado por C0 até 11:55 BRT.

Limites: 0 ações recertificadas E2E nesta entrega. Não houve runtime real, alteração remota, SQL ou deploy. Galeria e question-image permanecem WIP separado nesta worktree; o contrato G5 444ac0246 ainda não representa aplicação de backend. Conhecimento: preservadas as fontes existentes sobre múltiplas distribuições e autosave; nenhuma regra nova durável requer projeção nesta entrega.
