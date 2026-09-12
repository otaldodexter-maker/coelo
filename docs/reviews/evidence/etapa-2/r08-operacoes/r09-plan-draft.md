---
source: G7 draft requested by Owner during R08
status: draft-not-started
generated_at: 2026-09-12T14:23:00-03:00
---

# R09 — plano de retomada (rascunho)

Este arquivo prepara a próxima rodada; não autoriza iniciá-la, aplicar SQL, abrir navegador ou alterar qualquer rastreador.

## Ordem proposta

1. C0 materializa `origin/dev`, registra T0, posses, slots e a base integrada. Reconciliar commits/WIP/stashes antes de qualquer remoção de worktree.
2. Retomar H28 Pessoas pelo primeiro gate ainda aberto: candidato/fixture já produzidos na R08 devem passar no espelho descartável, com pgTAP estrutural e funcional; C0 é a única autora de fila/deploy. Só depois da serialização confirmada habilitar o adapter Flutter e rodar o teste focal.
3. Retomar avaliações pelo runner corrigido: validar primeiro a recuperação idempotente/falha 401 e alvo exato em ambiente permitido; não criar diário/configuração remota enquanto os recibos não forem revisados.
4. Retomar os E2E reais pendentes usando um único Chrome e a disponibilidade medida de G0. Prioridade: sessões próprias/reload, Suporte por estado e destinos de Catálogo, sem transformar indisponibilidades honestas em implementações de importação/exportação.
5. Executar censo Flutter somente numa base SHA fixa, uma vez por rodada, com parser que preserve os IDs; mudanças posteriores recebem teste focal e não alteram retrospectivamente o censo.
6. Atualizar rastreadores/inventário exclusivamente via C0 após provas commitadas. Revisões visuais continuam distintas de FE/BE/E2E.

## Frentes reaproveitáveis

| frente | retomada R09 proposta |
| --- | --- |
| G0 runtime | espelho descartável, browser/runtime, preflight e prova de API; sem segredos em evidência |
| G1 estrutura | avaliações/runner e gates de configuração/recuperação |
| G2 acessos | H28 e convites/Pessoas, após contrato SQL serializado |
| G3 formulários | regressões focalizadas e acessibilidade/H25 |
| G4 principal | contratos de perfil e erros/retry |
| G5 realm | fixtures SQL e autoria interna/R2 |
| G6 publicações | revisões de conteúdo e recursos retidos |
| G7 operações | sessões, Suporte, Catálogo, plans.assign e Help Center |
| G8 suites | censo único, parser e reconciliação de evidências |

## Critério de parada R09

Parar cada ação no primeiro gate não satisfeito e registrar: SHA/base, ambiente, prova executada, aprovado/falho/bloqueado e próximo gate. Não declarar ação E2E sem rota normal, persistência real, negação cross-tenant e reload quando aplicável.
