---
fonte: R08 G5; candidato H28 G2; execução no espelho por G0
status: local-green; aplicação e deploy pendentes do C0
generated_at: 2026-09-12T14:21:14-03:00
---

# H28 — fixture funcional dos filtros contextuais de Pessoas

## Recorte

A fixture cobre isolamento entre instituições A/B, rejeição de unidade e turma
fora do contexto, composição de papel global, atividade, localidade e segmento,
exclusão de atribuições inativas/revogadas e deduplicação de pessoas. Todos os
IDs são sintéticos e a transação termina em `ROLLBACK`.

## Ajustes medidos

- `bcf9038b0`: preenche handles obrigatórios de grupos.
- `3eb8bb7d3`: marca como `is_system=true` os dois papéis globais com
  `institution_id=null`, conforme `institution_roles_global_system_check`.
- `e1cad10e2`: preenche `activity_definitions.canonical_handle` com
  `h28.atividade.a`, valor lowercase compatível com a constraint do espelho.

Cada versão inválida abortou antes das asserções e reverteu integralmente; não
houve bypass de constraint, alteração de schema ou aplicação remota por G5.

## Resultado do espelho

O G0 executou o candidato H28 somente no baseline descartável e informou:

- aplicação do candidato: exit 0;
- teste estrutural: 11/11;
- fixture funcional final `e1cad10e2`: 10/10;
- regressões modernas: 8/8, 11/11 e 4/4;
- total atual: 44/44, sempre com rollback das fixtures.

A suíte histórica `superadmin_people_directory_test.sql` registrou quatro
falhas e abortou porque ainda espera permissões antigas e a assinatura removida
de 12 argumentos. Ela foi preservada como dívida de teste, não mascarada nem
contada no verde H28.

G5 não executou pgTAP, SQL remoto ou deploy. Produção e ledger permaneceram
intocados; promoção e ordem forward-only pertencem exclusivamente ao C0.
