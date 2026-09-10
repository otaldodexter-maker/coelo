---
title: "Limites de resposta em Formulários"
knowledge_id: "forms-answer-limits"
source: "packages/coelo_database/migrations/20260825193120_final_review_forms_runtime_hardening.sql"
status: "validated"
generated_at: "2026-09-09"
audience: "team"
surfaces: [superadmin, forms, supabase, authoring, response]
visibility: "internal"
review_owner: "Coelo Product e Engenharia"
---

# Limites de resposta em Formulários

O limite que o autor declara numa pergunta é validado **no servidor**, e não
apenas na tela. `app_private.form_replace_response_answers` recusa, antes de
gravar qualquer resposta: texto curto acima de `max_length`, com padrão 1000;
número inteiro, decimal ou dinheiro fora de `min_value` e `max_value`; data
fora de `min_value` e `max_value`; escala fora de `scale_min` e `scale_max`;
contagem de seleções fora de `min_selections` e `max_selections`; e contagem de
arquivos fora de `min_images` e `max_images`. A recusa é `check_violation` com
mensagem própria. A validação no cliente existe para falhar cedo e explicar,
nunca como o controle.

## Dinheiro trafega em minor units em todos os lugares

Esta é a regra que mais causa erro, porque as duas unidades parecem
intercambiáveis e não são. Uma resposta de dinheiro é guardada em
`money_minor_units`, ou seja em centavos, e o servidor compara exatamente esse
número contra `min_value` e `max_value` da configuração da pergunta. Portanto o
limite autorado também precisa estar em minor units: `10,50` é `1050`, não
`10.5`.

Gravar o limite em unidades enquanto a resposta é comparada em centavos torna o
limite cerca de cem vezes mais estrito do que o autor quis. Com um máximo
autorado de `10,50` gravado como `10.5`, qualquer resposta acima de dez centavos
é recusada pelo servidor, e nada na tela explica o motivo. O sintoma aparece
como formulário que simplesmente não aceita resposta, não como número errado.

A conversão e a comparação ficam em `FormNumericLimits`, em
`packages/coelo_domain/lib/src/forms/form_definition.dart`, com `parse`,
`format` e `violation`. Autoria, resposta e detalhe de resposta usam essa mesma
função. Reimplementar a regra de dinheiro numa tela é como as telas passaram a
ler o mesmo valor de formas diferentes.

## Um intervalo invertido torna a pergunta impossível

Mínimo acima do máximo não é um número inerte: como o limite é gate real,
nenhuma resposta consegue satisfazer a pergunta. O editor recusa essa
combinação antes de salvar ou publicar, junto das recusas equivalentes de
galeria e de datas. Mínimo igual ao máximo continua válido, porque descreve um
único valor aceito.
