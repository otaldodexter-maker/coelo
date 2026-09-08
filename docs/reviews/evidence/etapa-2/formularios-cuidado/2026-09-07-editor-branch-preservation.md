---
title: "Formulários — preservar opções e condições carregadas"
source: "docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md:132,182-186; FormItem/FormCondition e DTO existentes"
status: "local-behavior-verified-e2e-open"
generated_at: "2026-09-07"
---

# Defeito e recorte

Ao abrir um formulário e salvar só o título, o editor recriava IDs das opções
pela posição e omitia todas as condições. Isso tornava itens condicionados
incondicionais, contrariando a regra aprovada de saída explícita do ramo.

Correção somente do mapper do cliente Superadmin: condições carregadas mantidas;
ID associado ao controller da opção, sem mudar ao reordenar; duplicação cria
novos IDs para todas as opções, inclusive além das duas iniciais. Duplicar seção
remapeia fontes/opções internas para as cópias e mantém referências externas.

Não traduz condições carregadas para `branchQuestions`, não cria fluxo novo de
ramificação e não modifica contrato compartilhado, SQL, permissões ou Locais.
A edição visual completa de ramos e a integração produtiva permanecem abertas.

# Prova local

Cinco REDs antes da implementação: título, descarte, reordenação, duplicação de
pergunta e de seção retornavam IDs reconstruídos em vez dos IDs opacos carregados.
Após correção, sete testes novos cobrem também duplicação de dependente e
reordenação seguida de duplicação da seção. Conferem tipo de condição, fonte,
booleano false, conjuntos de opções e validade da definição serializada.

Regressão final **106/106**, exit 0, via RTK em `apps/superadmin`:

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

Analyzer dos dois arquivos alterados: sem problemas, exit 0. Formatação aplicada;
diff check sem erros. Validador de contratos visuais: exit 0, allowlist intacta.
Review read-only aprovado no recorte; duas sugestões de cobertura incorporadas.
Nenhuma execução de banco, navegador produtivo ou atualização de golden.
As diferenças visuais previamente registradas continuam abertas; validador de
contratos não equivale a revisão visual concluída.

# Memória e continuidade

Nenhuma decisão nova de produto: restaura invariantes canônicas. Gate de memória
sem nova projeção durável. Evidência operacional não promove action_id a done.
SQL F-READ01 aguarda replay nominal Eng1; editor, respostas, exportação XLSX,
mídia, locais e cuidado continuam no escopo original da vertical.
