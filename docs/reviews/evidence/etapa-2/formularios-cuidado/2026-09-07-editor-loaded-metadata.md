---
title: "Formulários — preservar metadados e configuração carregada"
source: "Spec Forms aprovada de 2026-08-13; FormDefinition/FormItemConfig/FormDefinitionDto existentes"
status: "local-behavior-verified-e2e-open"
generated_at: "2026-09-07"
---

# Recorte

Ao salvar somente o título, o editor substituía tipo, modo de identidade e
unidade da resposta por form/identified/person, descartava descrição e usava
status/version defaults. Também descartava precisão decimal, escala e rótulos.

O mapper agora conserva kind, identityMode, responseUnit, description, status,
managementVersion e as configurações carregadas citadas. Formulários novos
mantêm os defaults anteriores. Mínimo/máximo continuam nos controles existentes;
BRL permanece a política atual. Não há novo controle, modo de publicação,
identidade, contrato, capability ou mudança de backend.

# Verificação

Sete REDs antes do fix: quatro casos tipo/anonimato em edição/descarte e três
casos escala/decimal/dinheiro. Confirmavam substituição por constantes ou null.
Depois, sete testes novos verdes; suíte de contexto/editor 49/49.

Regressão final **120/120**, exit 0, via RTK em `apps/superadmin`:

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

Analyzer dos dois arquivos alterados: sem problemas. Formatação aplicada,
diff check sem erros e validador de contratos visuais exit 0. Review read-only
aprovado no recorte. Goldens e integração remota permanecem abertos; não foram
atualizados nem certificados por esta execução.

# Limites e memória

A validação de rascunhos incompletos de enquete ainda usa o validator completo
no editor; é limite separado, não coberto como concluído. Preservar metadados
não autoriza o ator nem substitui revalidação server-side. Testes usam doubles.

Gate de memória: não há decisão nova; restaura valores já definidos pelo
contrato canônico. Sem nova projeção durável. Nenhum action_id promovido a done.
Exportação XLSX, imagens reais, locais, saúde/medicação e toda a integração E2E
continuam dentro do escopo original, nos gates coordenados.
