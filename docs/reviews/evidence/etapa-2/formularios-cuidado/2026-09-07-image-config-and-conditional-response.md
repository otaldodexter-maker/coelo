---
title: "Formulários — configuração de imagens e resposta condicional"
source: "Contrato FormItemConfig; obrigatoriedade quando visível; revisão read-only e testes E2E4"
status: "local-behavior-verified-e2e-open"
generated_at: "2026-09-07"
---

# Recorte e resultado

Somente cliente Superadmin: preservar `allowCamera`, `allowExisting` e
`maxImages` de perguntas photo/gallery carregadas ao editar título, descartar e
duplicar; validar anexo obrigatório apenas quando a pergunta estiver visível.

O draft mantém configuração imutável carregada e a copia junto com a pergunta.
Os três campos são enviados sem substituir false por null. O responder usa a
mesma visibilidade da renderização e continua bloqueando anexos obrigatórios
visíveis enquanto o upload protegido não está disponível.

Nenhum picker, upload, RPC, SQL, mídia, local livre, endpoint ou autorização nova.
Não certifica o mapper completo do editor, mídia produtiva ou E2E.

# RED e GREEN reais

Antes da implementação:

- Quatro testes de editor falharam: `allowCamera` esperado false, recebido null,
  em photo/gallery com e sem descarte.
- Dois testes do responder falharam: a revisão não abria com imagem obrigatória
  invisível. Os dois controles com pergunta visível já bloqueavam corretamente.

Depois: dez testes novos, incluindo duplicação photo/gallery com câmera true e
galeria false. Sete suítes passaram, **99/99**, exit 0:

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

Comandos executados via RTK em `apps/superadmin`. Analyzer dos dois arquivos
produtivos e dois testes: sem problemas, exit 0. Formatação aplicada.
`validate_admin_visual_contracts.dart` em `apps/catalog`: exit 0, sem alterar
allowlist. Review independente read-only: aprovado no recorte; sugestão de teste
de duplicação incorporada. Diff check sem erros.

# Visual continua aberto

Execução separada de `forms_editor_golden_test.dart` e
`form_response_golden_test.dart`: 2 testes passaram e 3 falharam, exit 1.
Não atualizar goldens para encobrir diferenças.

Falhas nas mesmas superfícies já registradas nas evidências
`2026-09-07-editor-context-isolation.md` e da resposta: editor responsivo,
editor texto 200% e resposta DEV 375 claro. Nesta execução, por exemplo,
140039 px / 41,49% no editor 375 claro; 92341 px / 13,36% no editor 768 escuro;
108064 px / 28,82% no editor texto 200%; 47929 px / 12,78% na resposta.
Essas contagens constam das comparações de baseline anteriores. Esta fatia não
reexecutou um segundo checkout-base nem concluiu revisão visual.

# Memória e continuidade

Não houve decisão nova de produto: foi restaurada a preservação de configuração
existente e a regra de obrigatoriedade conforme visibilidade. Gate de memória
sem nova projeção durável; evidência operacional mantida aqui.

Upload/entrega privada continuam dependentes de E2E3; Locais catalogados,
visíveis e autorizados dependem do contrato E2E2. Não adotar oneOff por inferência.
SQL F-READ01 permanece preparado/não executado em `21792181`, aguardando fila
nominal exclusiva Eng1. Todos continuam dentro do escopo original.
