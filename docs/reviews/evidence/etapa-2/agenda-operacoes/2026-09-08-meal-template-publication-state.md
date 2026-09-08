---
title: "Cardápios — confirmação da publicação do modelo"
source: "meal_plan_template_save; wizard de Cardápios; testes locais"
status: "correção local verificada; E2E aberto"
generated_at: "2026-09-08"
---

# Recorte e evidência

Objetivo: impedir sucesso de publicação quando a resposta final do modelo
não confirma `published`. Incluído: pós-condição cliente e testes de widget.
Fora: SQL, upload real, reconciliação de resultado incerto, R2 e backend interno.
Ordem: reprodução, correção mínima, regressão e revisão independente.
Critério de parada da fatia: resposta inválida sem callback; resposta publicada
com callback. Tempo aproximado: 6 minutos.

- RED real: respostas draft e archived acionavam `onSaved` uma vez; esperado zero.
  O controle published passou. Uma execução anterior tinha label de botão
  incorreto no teste, corrigido antes de medir esses REDs.
- GREEN: 28 testes do wizard PASS; após adicionar controle active, quatro
  casos focados finais PASS (draft, archived, active, published).
- Analyzer dos dois arquivos: sem problemas; revisão independente sem blocker.

O gate fica depois do último `saveTemplate`, incluindo o save de metadados
de mídia quando houver, e antes do callback. Só atua quando `publish=true`.
O SQL existente grava `published`; `active` permanece alias de leitura legado,
não prova de uma nova publicação. Nenhuma mensagem de sucesso é inventada.

Os testes novos desabilitam imagens. A posição do gate após o ramo de mídia
foi revisada estaticamente, mas não se declara execução desse ramo nem upload
verificado. O protocolo de retry do modelo continua fora desta fatia.
Memória: correção do contrato existente, sem nova regra durável a publicar.
