---
title: "Entrega e reconciliação dos compromissos do Owner"
knowledge_id: delivery-reconciliation
source: decisions/0036-delivery-reconciliation-and-owner-commitments.md
status: validated
generated_at: 2026-09-13
audience: team
surfaces: [superadmin, development, knowledge]
visibility: internal
review_owner: Coelo Owner
---

O integrador mantém todos os pedidos ativos do Owner num registro de entrega,
incluindo ajustes enviados durante a execução. Pendências e avanços são ligados
à tela/subtela e às camadas FE, BE e E2E; tarefa de processo também tem estado,
evidência, responsável e primeiro gate.

Fechamento exige reconciliar Git, worktrees, ignorados, stash, documentos e
skills no checkout de destino. Backup preservado não significa patch integrado;
push não significa deploy. Referência histórica sem revisão de conteúdo deve
permanecer explícita como pendência, sem merge artificial para zerar contagens.

O gate automatizado pode rejeitar inconsistências estruturais. Ele não substitui
a leitura dos pedidos nem prova visual ou equivalência semântica. Resultado
parcial permite entregar o trabalho concluído com seus limites, nunca afirmar
que tudo foi resolvido. Corte de execução não apaga compromissos anteriores.
