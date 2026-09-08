---
title: "Atividades — interação do formulário compacto no harness"
source: "reprodução do caso funcional reportado pela coordenação; SuperadminFormFrame; teste activity_form_page_test"
status: "local-green; sem alteração produtiva ou conclusão E2E"
generated_at: "2026-09-07"
---

# Recorte

Corrigir somente o caso `stacks local selector and create action at full width on compact screens` no viewport 375 × 1000. Não alterar Locais, o formulário produtivo, o frame compartilhado nem masters de golden.

## Evidência RED e causa

- Execução isolada reproduziu `tap()` em Continuar no centro `(187.5, 1346.0)`, fora do viewport. A etapa Estrutura e locais não abriu; a leitura seguinte do seletor de instituição falhou com `Bad state: No element`.
- `SuperadminFormFrame` inclui o footer no `SingleChildScrollView` quando compacto. O teste não rolava até a ação. Também tentava tocar na unidade antes de `ensureVisible`.
- A primeira rolagem trouxe somente a borda do botão: retângulo y=962–1010, enquanto a região rolável termina em y=984. Uma asserção de hit test detectou que o centro ainda estava fora da região. Um gesto adicional expõe o botão antes do toque.

## Correção

- Rolar o formulário, aguardar estabilização e exigir `hitTestable()` antes de tocar em Continuar.
- Trazer a unidade para a tela e exigir hit test antes de tocar nela.
- Preservar viewport, dados, assertivas de empilhamento/largura de Locais e ausência de exceções. Não invocar diretamente o callback de Continuar nem suprimir warnings.

## Verificação

- Caso isolado: 1/1 PASS após RED reproduzido.
- Arquivo completo `activity_form_page_test.dart`: 16/16 PASS.
- `flutter analyze --no-pub test/features/activities/presentation/activity_form_page_test.dart`: PASS.
- `git diff --check`: PASS.
- Revisão independente read-only: sem blocker.

## Limites

A instituição continua selecionada pelo callback da fixture existente; este caso verifica composição compacta e alcance das ações, não o fluxo completo do seletor. Nenhum SQL, backend, Locais nominal, golden ou arquivo produtivo foi alterado. Os nove goldens divergentes reportados pela coordenação não foram reexecutados nem rebaselined neste pacote. O resultado não certifica E2E de Atividades. Gate de conhecimento: no-op, pois não mudou regra durável de produto.
