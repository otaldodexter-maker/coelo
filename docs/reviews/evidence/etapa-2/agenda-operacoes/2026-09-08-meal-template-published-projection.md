---
title: "Cardápios — projeção de modelo publicado"
source: "meal_plan_template_save; MealPlanTemplate.toDirectoryItem; testes locais"
status: "correção local verificada; sem promoção E2E"
generated_at: "2026-09-08"
---

# Contrato e resultado

Recorte: Superadmin, conversão de modelos para o diretório. Nenhum SQL,
upload, permissão, publicação remota ou alteração de API foi executado.
Critério de parada desta fatia: reproduzir o status incorreto, corrigir a
projeção e verificar controles e regressões. Tempo desta fatia: cerca de 5 minutos.

`20260820160000_meal_plans_model_audience_availability.sql`, função
`meal_plan_template_save`, grava `published` quando `p_publish=true`.
O repositório DEV também retorna esse valor. A conversão reconhecia somente
`active`, produzindo `status=draft` e `isDraft=false` para modelo publicado.

A conversão agora aceita `published` e preserva a compatibilidade `active`.
Não altera os tratamentos existentes de `draft` e `archived`.

## Evidência

- RED real: teste de resposta HTTP simulada `published` esperava published e
  recebeu draft; outros quatro testes da suíte passaram.
- GREEN: 52 testes de data, wizard e diretório PASS, incluindo os quatro
  controles de status via adapter e as regressões de comandos/retry.
- Analyzer dos dois arquivos alterados: sem problemas.
- Nenhum golden foi atualizado e nenhum backend foi executado.

Gate de memória: correção do contrato existente, sem nova regra de produto;
nenhuma projeção de conhecimento adicional é necessária. Publicação real,
reload, autorização, upload e pós-condição do wizard de modelos continuam abertos.
