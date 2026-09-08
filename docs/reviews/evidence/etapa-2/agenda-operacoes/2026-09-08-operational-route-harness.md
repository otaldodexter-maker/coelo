---
title: "Operações — harness de rotas DEV explícito"
source: "regressão local de12arquivos; testes de Avaliações/Assiduidade/Rotina"
status: "14 testes focados PASS; contrato de rota Cardápios aberto"
generated_at: "2026-09-08"
---

# Recorte e diagnóstico

Rodada adicional de12arquivos em test/app (rotas/composição das superfícies
operacionais) terminou **53PASS/4FAIL**, exit1. Ela é separada das669 regressões
anteriores de test/features. A falha de Cardápios não foi alterada nesta fatia.

Três falhas corrigidas apenas no harness:

- Positivos DEV de Avaliações e Chamada omitiam `allowDevelopmentPreview:true`;
  o router redirecionava para Home. Os títulos e builders esperados existem.
  Flag adicionada somente nesses dois testes; defaults e guards produtivos intactos.
- Rotina tocava botão em y1488 fora do viewport800x600. O teste agora faz
  scroll no container canônico, espera layout, verifica hitTestable e toca de fato.
  O primeiro scroll revelou também expectativa antiga do nome; a fixture
  `model-1` é `Chegada e acolhimento`, e o teste agora exige esse nome com `(cópia)`.
  Duplicação e aplicação preservam as verificações de editor e origem.

Critério de parada desta fatia: três arquivos verdes, sem editar produto ou
suprimir assertions. Tempo aproximado: 8 minutos. **14 testes PASS**, analyzer
dos três arquivos sem problemas e review independente sem achados. Não houve
SQL, HTTP, Docker, alteração de golden, router, grant ou default de preview.

## Falha restante separada

`meal_plan_production_routes_test.dart`: o caso que espera
`meal-plan-authorized-tenant-unavailable` falha também isoladamente. O guard foi
removido em `b0c250fc` ao conectar repositories; o wizard atual recebe tenant
vazio e usa seleção contextual. Esse histórico não constitui aprovação de
autorização backend nem motivo para trocar a expectativa automaticamente.
O Coordenador foi informado para fechar o contrato nominal; nenhum guard foi
restaurado/removido nesta correção de fixtures. A rodada completa de12arquivos
ainda não está verde. Memória: manutenção de testes, sem nova regra durável.
