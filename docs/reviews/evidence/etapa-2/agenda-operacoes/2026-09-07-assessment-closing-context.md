---
title: "E2E5 — isolamento de contexto no fechamento de avaliações"
source: "assessment_pages.dart; testes de Avaliações; revisão independente agenda_ui_contract"
status: "correção local verificada; integração real pendente"
generated_at: "2026-09-07"
---

# Contrato da fatia

Objetivo: não exibir fila/diário antigos nem aplicar uma confirmação ao novo
contexto quando repository ou gradebookId mudam no mesmo elemento Flutter.
Incluído: fila, detalhe, diálogos e efeitos tardios de comandos de fechamento.
Fora: habilitação de mutações, SQL, autorização remota e publicação real.
Ordem: RED de widget, correção mínima, regressão, análise e review. Critério de
parada desta fatia: casos adversariais verdes e nenhum blocker de review; isso
não encerra Avaliações nem o escopo E2E5. Tempo observado: aproximadamente 12 min.

## RED e correção

- Quatro testes falharam no código anterior: fila A→B (sucesso/erro tardio),
  detalhe A→B sem fetch B e diálogo A ainda aberto após troca para B.
- Fila usa geração de leitura, recarrega ao trocar repository e limpa busca e
  página. Respostas/erros de gerações antigas são ignorados.
- Detalhe descarta controller anterior e limpa estado de edição ao trocar
  repository ou gradebookId. O controller existente já invalida leituras e
  comandos ao ser descartado.
- Cada decisão captura seu controller; valida identidade antes do envio e após
  resposta. O diálogo pertence a uma rota capturada: a invalidação remove apenas
  essa rota, nunca usa pop genérico que possa retirar outra tela.
- O wrapper impede sobreposição de decisões e abertura durante comando pendente.

## Verificação executada

- `flutter test --no-pub test/features/assessments`: **25/25 PASS**.
  São sete novos casos: os quatro RED acima, troca somente de gradebookId e
  sucesso/erro de comando A já enviado após renderizar B. Não há snackbar antigo,
  reaparição de A nem comando enviado ao repository B.
- `flutter analyze --no-pub lib/features/assessments/assessment_pages.dart
  test/features/assessments/assessment_entry_page_test.dart`: sem issues.
- `validate_admin_visual_contracts.dart`: exit0; nenhuma baseline alterada.
- Review read-only independente: sem blocker; sugestões de comando pendente e
  troca só de ID incorporadas aos testes antes do fechamento.

## Limites e memória

Teste de widget/repository fake não comprova persistência, reautorização ou
publicação real. Guards de produção não foram alterados. O gate de conhecimento
é no-op: correção de isolamento já exigido, sem nova regra de produto ou decisão
durável a projetar. Rastreadores centrais continuam sob writer Coordenador.
