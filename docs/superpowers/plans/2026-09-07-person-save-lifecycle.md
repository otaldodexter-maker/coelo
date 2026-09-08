---
title: "PERS-LIFECYCLE01 — salvamento de Pessoas"
source: "specs/019-superadmin-people-directory.md"
status: "local-verified"
generated_at: "2026-09-07"
---

# Recorte aprovado

Correção local do `PersonFormViewModel`, testes e evidência, aprovada pelo
coordenador da Etapa 2. Integra a vertical Estruturas, Pessoas e Locais; não
substitui seu escopo nem constitui conclusão E2E.

Objetivo: compartilhar uma única operação pendente, congelar o comando antes
de notificar listeners e impedir notificações tardias após dispose. Chamadas
concorrentes recebem o mesmo resultado/erro. Novas edições e patches permanecem
intactos; erros liberam retry. Save após dispose falha sem chamar repository.

Não alterar validação, permissões, entidades, adapter, router ou backend.
Não reidratar receipt, atualizar a versão original ou reconciliar patches após
sucesso neste pacote. A resposta continua sendo entregue ao chamador; não é
possível cancelar uma escrita já enviada apenas descartando o view model.

## Execução e critério de parada local

- [x] RED: nove cenários reproduzidos antes da correção.
- [x] Correção mínima no view model.
- [x] GREEN focal 15/15, regressão 69/69 e analyzer sem issues.
- [x] Review independente sem bloqueadores e evidência preparada para handoff.

Estimativa local: 30–60 minutos. Supabase, persistência remota, cross-tenant,
revogação e E2E permanecem gates separados da vertical original.

Evidência: `docs/reviews/evidence/etapa-2/estruturas/2026-09-07-person-save-lifecycle.md`.
