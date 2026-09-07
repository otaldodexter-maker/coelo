---
title: "Institution save lifecycle — implementation plan"
source: "docs/superpowers/specs/2026-09-07-institution-save-lifecycle-design.md; confirmação do Coordenador"
status: "approved-local; implementation-in-progress"
generated_at: "2026-09-07"
---

# Institution save lifecycle Implementation Plan

> Execução inline pelo único writer; subagente faz review read-only, conforme
> contrato operacional vigente. Skill subagent-driven-development já aplicada.

**Goal:** renderizar o record salvo sem retorno obsoleto ou edição concorrente.

**Architecture:** snapshot imutável antes de awaits; guard por geração e
identidade; novo controller com mesma etapa; subtree keyed e disposal pós-frame.

**Tech Stack:** Flutter/Dart, widget tests e doubles locais, nenhum backend real.

## Global constraints

Somente `apps/superadmin`. Não mudar validação, UI visual, FormFrame, router,
contrato042 ou remoto. Baseline49 testes:44GREEN/5FAIL preexistentes,
incluindo2golden e3widgets dependentes de botão fora da viewport375.
Sem atualização de goldens; cinco falhas permanecem separadas.

## Task 1 — resposta autoritativa e lifecycle

Files:

- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_form_page.dart`.
- Create: `apps/superadmin/test/features/institutions/presentation/screens/institution_form_save_lifecycle_test.dart`.

Interfaces: consome `InstitutionDirectoryRepository.update(record,
expectedVersion:) -> Future<InstitutionRecord>` sem modificar a assinatura.
Produz somente comportamento da página; nenhuma API pública nova.

- [ ] RED: repository delega leitura ao fake e mantém update em Completer;
  preparar representante/admin válido pelo controller do fixture e salvar.
  Conferir `controller.text(publicName) == saved.publicName`, versão via
  `controller.toRecord(id: id).version`, `isDirty == false` e mesma etapa.
- [ ] RED: enquanto Completer está pendente, conferir `AbsorbPointer.absorbing`
  e `ExcludeFocus.excluding`; segunda ação não cria segundo update.
- [ ] RED: trocar ID durante save, completar sucesso/erro antigo e conferir
  novo ID/draft inalterados e ausência de snackbar da operação antiga.
- [ ] Implementar guard local:

  ```dart
  final controller = _controller;
  if (controller == null || controller.isSaving) return;
  final sequence = _loadSequence;
  bool isCurrent() => mounted && sequence == _loadSequence &&
      identical(controller, _controller);
  ```

  Capturar draft/ID/repository antes do primeiro await. Chamar `isCurrent`
  antes de qualquer notificação, substituição, erro ou callback pós-await.

- [ ] Reidratar com `InstitutionFormController(record: saved)` e atribuir a
  etapa anterior. `_FormBody(key: ObjectKey(_controller))` desmonta caches
  anteriores. Descartar controller anterior após o frame de substituição.
- [ ] Envolver frame com `ExcludeFocus(excluding: controller.isSaving,
  child: AbsorbPointer(absorbing: controller.isSaving, child: frame))`.
  Retornar de saída/navegação durante envio. Sem mudança de aparência.
- [ ] GREEN: `rtk proxy C:\src\flutter\bin\flutter.bat test --no-pub test/features/institutions/presentation/screens/institution_form_save_lifecycle_test.dart`.
- [ ] Reexecutar formulário/goldens existentes; manter baseline5 falhas
  separadas, exigir zero falhas novas. Analyzer nos2 arquivos e review.
- [ ] Evidência por ação, memória no-op se não houver regra nova, commit e
  handoff; não declarar tela/E2E concluídos.

## Self-review

O plano cobre snapshot, concorrência, etapa, teclado/toque, ID e disposal.
Não inclui modo coreV2 rejeitado para este pacote. O teste usa fake somente como
double, nunca em composição produtiva. A conclusão é local e não certifica
Supabase. ETA local45–75min; limite global08/09 03:20BRT preservado.
