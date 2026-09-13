---
source: R12-39/R12-40; R12-formularios-agenda-owner.md
status: local-green
generated_at: 2026-09-13
---

# R12-39/R12-40 — editor de formulários

O editor mantém arraste de perguntas e seções, mover por botões, duplicação e
cancelamento sem alterar o tamanho do item. Foi acrescentado o comando
`Renomear seção`, com diálogo cancelável, limite de 120 caracteres, validação
de vazio e atualização do draft que segue o autosave/autoria existente.

Prova local: `forms_editor_page_test.dart`, 22 testes PASS. A persistência real,
reload e autorização cross-tenant permanecem pending-verification; o editor
não recebeu contrato novo de backend.
