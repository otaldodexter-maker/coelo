---
title: "Formulários — ramos por opção com gatilho explícito"
source: "Spec Forms 2026-08-13:180–192; reserva nominal do Coordenador; plano 2026-09-08-choice-branch-roundtrip.md"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Resultado local

O editor mostrava filhos de escolha única/múltipla sem condição de opção,
enquanto o mapper só percorria filhos Sim/Não. Os filhos aparentes desapareciam
do payload. Agora o seletor canônico exige escolha explícita do ID da opção
antes de adicionar um filho, que recebe UUID e condição choice correspondente.
O seletor controla somente o próximo filho: não retargeta filhos anteriores.

Os cards e a árvore existentes renderizam os filhos com o rótulo do gatilho.
Serialização, contagem e cópia percorrem ramos choice; IDs internos/opções são
remapeados nas cópias. Renomear ou reordenar opções não muda o gatilho. Esconder
os controles pelo toggle não apaga filhos. Hidratação conservadora admite uma
condição choice com uma opção válida de ancestral contíguo na mesma seção;
condições complexas e ordem não representável permanecem planas e intactas.

Callbacks de seleção/criação verificam geração e presença da instância atual.
Criação também revalida o gatilho e passa pelo gate de edição existente.
Autosave usa a mesma fila/recibos: selecionar opção sem criar filho não salva.

Um RED adicional demonstrou lacuna do validador compartilhado: opção inexistente
na condição não era rejeitada. Sem modificar o domínio compartilhado, o save do
editor passou a conferir fonte choice, conjunto não vazio e pertencimento das
opções à fonte. Não corrige nem descarta silenciosamente condições inválidas.
Esse preflight não afirma proteção equivalente de publicação ou backend.

# Evidências

- Dois REDs iniciais: seletor explícito ausente para single/multiple.
- RED de callback retido após limpar o gatilho: null-check indevido; corrigido
  com revalidação no momento do comando.
- RED de opção inexistente: comando indevido; corrigido pelo preflight local.
- 16 testes novos: 14 no editor (save/reload, toggle, reorder/rename, cópias de
  pergunta/seção, próximo gatilho, callback retido, ciclo, fonte/opção inválida,
  hierarquia mista a 375 px/200%, profundidades 4 e 5), um de autosave nominal
  e um de união de múltipla escolha/remoção de resposta oculta antes do submit.
- Regressão das nove suítes Forms: **265/265**, exit 0.
- Analyze dos quatro arquivos Dart alterados: sem problemas, exit 0.
- Validador de contratos visuais administrativos: exit 0; allowlist intacta.
- Revisão read-only independente favorável para árvore/cópia/callbacks e para
  o preflight adicional; Root único writer.

Comando de regressão em `apps/superadmin`, via RTK:

```text
flutter test --no-pub --reporter expanded
test/features/forms/presentation/editor/forms_editor_authoring_test.dart
test/features/forms/data/supabase_forms_authoring_api_test.dart
test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart
test/features/forms/presentation/editor/forms_editor_page_test.dart
test/features/forms/presentation/response/form_response_page_test.dart
test/features/forms/presentation/response/form_response_development_test.dart
test/features/forms/presentation/response/forms_test_page_test.dart
test/features/forms/presentation/forms_lifecycle_page_wiring_test.dart
test/features/forms/data/supabase_forms_api_test.dart
```

Erros de preparação dos testes não contam como RED de produto: callback nullable
sem `!` na primeira compilação; tentativa de abrir card pelo título em vez do
botão Editar; scroll do rodapé antes de estabilizar o caret após digitação;
submit inicialmente fora da viewport. Os testes usam botão real e aguardam
layout, sem suprimir warning nem aumentar viewport para esconder o problema.
Dois avisos de chaves no analyzer foram corrigidos antes do gate final.

# Limites e continuidade

Nenhum SQL, endpoint, rota, publicação, autorização, remoto ou gateway alterado.
Sem atualização de goldens; diferenças visuais conhecidas permanecem abertas.
Validador estático e teste de 375 px não substituem revisão visual E2E.
Integração nominal, F-AUTHOR01/02/03, distribuição, respostas, XLSX/R2, locais
internos e cuidado continuam no escopo original, com seus gates próprios.

Gate de memória: implementação de regra já aprovada, sem decisão nova de produto;
nenhuma projeção de conhecimento criada apenas para registrar atividade.
Rastreadores e ledger oficiais permanecem sob escrita exclusiva do Coordenador.
