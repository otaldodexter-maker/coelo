---
title: "Editor — descarte produtivo sem fixture"
source: "FormsEditorPage; widget tests locais; revisão independente"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Contrato

Superadmin, Editor, descarte em `forms.create` e `forms.edit`. Restaurar a última
definição confirmada por load/save/publish; criação ainda não salva retorna ao
estado neutro com contexto autorizado preservado. Desenvolvimento mantém seu
fluxo. Fora: mapper completo das perguntas, idempotência, backend e integração
produtiva. Nenhum BD, RPC real, Worker ou recurso R2 executado.

## Causa e correção

O descarte reconstruía sempre a fixture ANHEMBI, inclusive em produção, mas
mantinha o ID e a versão produtivos. O próximo save poderia misturar esses
identificadores ao conteúdo de demonstração.

A produção agora restaura `_definition` via `_applyDefinition`, ou campos e
seção neutros quando ainda não existe definição. Controllers e seleção são
reconstruídos; contexto textual, preview, feedback e agenda local são limpos.
Não há refetch nem comando no descarte. A confirmação informa corretamente o
retorno ao último conteúdo confirmado; a composição do diálogo foi preservada.

## Evidência

Quatro REDs reproduziram o título indevido da fixture: carregado, último save,
criação neutra e save rejeitado. Um RED adicional verificou a confirmação
textual. Erros iniciais de seletor/viewport dos testes foram corrigidos e não
contados como RED de produto.

Oito testes adicionados cobrem essas restaurações, continuar editando, pergunta
removida/contexto textual e último receipt de publicação. Execução final:

```text
flutter test --no-pub test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart test/features/forms/presentation/editor/forms_editor_page_test.dart
50/50 passaram, exit 0

flutter analyze --no-pub lib/features/forms/presentation/editor/forms_editor_page.dart test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart
2 arquivos, No issues found, exit 0

dart run tool/validate_admin_visual_contracts.dart ../.. assets/admin-visual-contract-allowlist.json
exit 0
```

Revisão estática independente aprovada sem bloqueios; recomendações de
publicação, pergunta removida e confirmação textual foram incorporadas. Sem
certificação visual/E2E: os goldens gerais preexistentes documentados em
`2026-09-07-editor-context-isolation.md` permanecem pendentes; não foram
atualizados nem repetidos nesta fatia sem mudança de composição.

Estado Front-end local-green parcial; nenhum action_id promovido. Backend e
E2E continuam abertos. Coelo Knowledge no-op: correção da separação já exigida
entre fixture e produção, sem nova regra de produto ou projeção de atividade.
