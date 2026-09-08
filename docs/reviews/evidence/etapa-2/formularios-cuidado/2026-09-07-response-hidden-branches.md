---
title: "Formulários — valores de ramos ocultos e recibos de resposta"
source: "Spec Forms 2026-08-13:182-186,204; FormVisibilityEvaluator/FormAnswerNormalizer; SQL canônico forms_commands_and_projections:1755-1783"
status: "local-behavior-verified-e2e-open"
generated_at: "2026-09-07"
---

# Recorte e correção

Cliente Superadmin: regras de visibilidade e descarte de respostas ocultas.
O cliente exigia todas as condições, divergindo do evaluator compartilhado e do
SQL que aceitam uma condição correspondente. Também enviava e resumia respostas
ocultas; respostas residuais de um ancestral oculto mantinham seus descendentes.

Agora os IDs visíveis crescem a partir das raízes usando somente respostas de
fontes já visíveis. A ordem dos itens não determina a autorização de um ramo.
O evaluator existente fornece a união das condições. Renderização, validação,
resumo e normalização usam esse conjunto. Respostas ocultas são removidas no
load, na alteração e no recibo; não há cache para ressuscitá-las ao reabrir.
O normalizer compartilhado prepara o payload e faz trim sem reidratar campos
a cada tecla. Nenhum contrato compartilhado ou SQL foi alterado.

Recibos de rascunho conservam edições locais feitas após o início da operação,
mas avançam a versão confirmada. Recibos submitted sempre fornecem as respostas
mostradas na confirmação; não apresentar edição local posterior como persistida.
As guardas existentes de ocorrência/API/dispose continuam em vigor.

# RED, revisão e GREEN

Quatro REDs originais: payload com leaf oculto, descendente visível após ocultar
o ancestral, condição alternativa não exibida e recibo atrasado ressuscitando
ramo. Review encontrou um P2 adicional: durante submit, preservar edição local
podia mostrar conteúdo não confirmado. Reproduzido por quinto RED e corrigido.
Review final read-only aprovado, sem novo bloqueante no recorte.

Sete testes novos incluem load/recibo com resíduo oculto, fonte posterior,
reabertura sem ressurreição, cadeia de dois níveis, união das condições, save
pendente e confirmação de submit. Suíte específica 23/23.

Regressão final **113/113**, exit 0, via RTK em `apps/superadmin`:

```text
flutter test --no-pub --reporter expanded
test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart
test/features/forms/presentation/editor/forms_editor_page_test.dart
test/features/forms/presentation/response/form_response_page_test.dart
test/features/forms/presentation/response/form_response_development_test.dart
test/features/forms/presentation/response/forms_test_page_test.dart
test/features/forms/presentation/forms_lifecycle_page_wiring_test.dart
test/features/forms/data/supabase_forms_api_test.dart
```

Analyzer dos dois arquivos alterados: sem problemas, exit 0. Formatação aplicada.
Validador de contratos visuais: exit 0, allowlist intacta. Goldens não atualizados;
as diferenças já registradas continuam abertas. Não houve novo ensaio visual
nem execução de backend nesta fatia.

# Limites e memória

As provas são locais, com doubles; não comprovam autorização ou persistência
produtiva. Backend revalida visibilidade e valores e permanece autoridade.
Anexo obrigatório visível continua indisponível honestamente; upload/mídia não
foi implementado. Nenhum action_id promovido a done nesta branch.

Gate de memória sem nova decisão/projeção: restaura regras canônicas existentes.
SQL nominal F-READ01, exportação XLSX/R2, locais, cuidado e integração produtiva
continuam no escopo original e nos gates coordenados.
