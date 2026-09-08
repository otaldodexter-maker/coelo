---
title: "Perfis — continuidade do recurso no detalhe"
source: "reserva nominal e adendo do Coordenador; testes locais E2E 1"
status: "local-green; visual-and-e2e-open"
generated_at: "2026-09-08"
---

# Recorte

`AccessProfileDetailPage` e seu teste de continuidade. Mudança de repository,
domínio ou ID limpa o snapshot/erro e inicia leitura com revisão própria.
Resposta e erro tardios são descartados. Rebuild equivalente não refaz leitura.

Exclusão captura repository e callback originais e verifica continuidade após
preparação, diálogo e comando. Confirmação antiga não dispara comando novo;
comando já enviado não é cancelado, mas sua conclusão não afeta a nova tela.
Payload, RPC, regras server-side e layout preservados. O controller do motivo
é descartado após completar a transição do diálogo, evitando uso após dispose.

## Evidência

- RED original: dois testes falharam por ausência da consulta B e snapshot A
  ainda visível. Controle equivalente passou.
- RED adicional: preparação antiga abriu diálogo sobre B; confirmação antiga
  disparou exclusão de A após troca. Ambos reproduzidos antes dos guards.
- GREEN focal: 9/9 testes (inclui repo/domínio, resposta tardia, preparação,
  confirmação, comando em voo e controle positivo de callback único).
- Regressão funcional conjunta com adapter Models: 161/161 PASS; data/domain,
  view-model/pages/detalhe Perfis, rotas Perfis normais/preview/invalidação,
  rotas Usuários/detalhe, router geral e sessão.
- Analyzer de detalhe/teste: PASS; format/diff check PASS.
- Review independente account_review: sem bloqueantes no recorte.

Execução visual ampliada separada: 38 PASS / 3 FAIL. Os três testes goldens
de `access_profile_golden_test.dart` falham em cards/tabela, hover e formulário.
Eles instanciam DirectoryPage/FormPage, não DetailPage. Não se atribui a causa
visual a este patch e não houve atualização de masters ou aprovação visual.
Artefatos de comparação ficam na pasta de failures ignorada do teste.

## Limites

Teste de componente não demonstra reutilização pelo router real nem revisão
de sessão no detalhe. Esses gates, formulário, navegação READ, backend real,
produção/reload e cleanup E2E continuam abertos. Não houve SQL/remoto/mídia.
Memória: contrato técnico restaurado, sem nova decisão durável. Rastreadores
permanecem exclusivos do Coordenador.
