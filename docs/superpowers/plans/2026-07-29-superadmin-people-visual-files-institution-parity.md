# People Visual Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduzir em Pessoas a ação Arquivos e a anatomia visual de Criar/Editar Instituição, mantendo todas as operações de arquivo estritamente demonstrativas.

**Architecture:** A listagem compõe um `PersonFileActions` local sobre o componente público `CoeloAdminFileActions`. O formulário continua usando `PersonFormViewModel`, mas replica breakpoints, navegação, cabeçalhos, avatar, transição, confirmação de saída e rodapé de Instituições sem criar API pública nova.

**Tech Stack:** Flutter, Dart, `coelo_tokens`, `coelo_ui_core`, `coelo_ui_admin`, widget tests e goldens.

## Global Constraints

- Não alterar Supabase, RPCs, migrations, RLS, MFA ou autorização.
- Não executar upload, importação, exportação ou download real.
- Não copiar capa, paleta ou campos exclusivos de Instituições.
- Reutilizar componentes e tokens públicos existentes.
- Preservar light/dark, 375/768/1024/1440, texto a 200%, teclado, foco, semântica e reduced motion.

---

### Task 1: Arquivos demonstrativos em Pessoas

**Files:**
- Create: `apps/superadmin/lib/features/people/presentation/person_file_actions.dart`
- Create: `apps/superadmin/test/features/people/presentation/person_file_actions_test.dart`
- Modify: `apps/superadmin/lib/features/people/presentation/person_directory_page.dart`
- Modify: `apps/superadmin/test/features/people/presentation/person_directory_page_test.dart`

**Interfaces:**
- Consumes: `CoeloAdminFileActions`, `CoeloAdminFileAction`, `CoeloAdminDialogShell`, `SuperadminActivityController`, `SuperadminExportFormat`.
- Produces: `PersonFileActions({required SuperadminActivityController activityController, bool compact = false})`.

- [ ] **Step 1: Escrever o teste RED do menu e do modal**

```dart
testWidgets('shows People file actions and a visual-only import flow', (tester) async {
  final activity = SuperadminActivityController();
  await tester.pumpWidget(testApp(PersonFileActions(activityController: activity)));
  await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
  await tester.pumpAndSettle();
  expect(find.text('Importar'), findsOneWidget);
  expect(find.text('Exportar CSV'), findsOneWidget);
  expect(find.text('Exportar XLSX'), findsOneWidget);
  await tester.tap(find.text('Importar'));
  await tester.pumpAndSettle();
  expect(find.text('Importar pessoas'), findsOneWidget);
  expect(find.text('Etapa 1 de 2 · Arquivo'), findsOneWidget);
});
```

- [ ] **Step 2: Executar o RED**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/people/presentation/person_file_actions_test.dart --no-pub
```

Expected: FAIL porque `PersonFileActions` ainda não existe.

- [ ] **Step 3: Implementar a composição mínima**

```dart
final class PersonFileActions extends StatelessWidget {
  const PersonFileActions({
    required this.activityController,
    this.compact = false,
    super.key,
  });

  final SuperadminActivityController activityController;
  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: [
      CoeloAdminFileAction(
        key: const Key('people-files-import'),
        label: 'Importar',
        icon: Icons.upload_file_outlined,
        onPressed: () => showPersonImportDialog(context, activityController),
      ),
      CoeloAdminFileAction(
        key: const Key('people-files-export-csv'),
        label: 'Exportar CSV',
        icon: Icons.table_rows_outlined,
        onPressed: () => completePersonExport(
          context,
          activityController,
          SuperadminExportFormat.csv,
        ),
      ),
      CoeloAdminFileAction(
        key: const Key('people-files-export-xlsx'),
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: () => completePersonExport(
          context,
          activityController,
          SuperadminExportFormat.xlsx,
        ),
      ),
    ],
  );
}
```

O modal usa `CoeloAdminDialogShell`, duas etapas locais e os textos
`pessoas-julho.xlsx`, `24 linhas válidas`, `2 linhas com erro` e
`Importar 26 linhas`. A confirmação chama:

```dart
activityController.startDemoImport(
  subject: 'Pessoas',
  fileName: 'pessoas-julho.xlsx',
  progressSummary: 'Importando pessoas',
  completedSummary: '24 importadas, 2 rejeitadas',
);
```

As exportações chamam:

```dart
activityController.completeDemoExport(
  format,
  subject: 'Pessoas',
  fileBaseName: 'pessoas',
);
```

- [ ] **Step 4: Inserir a ação ao lado do toggle**

Em `PersonDirectoryPage`, substituir a ação isolada pelo mesmo `Row` de
Instituições:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(height: CoeloSize.touchMin, child: layoutToggle),
    const SizedBox(width: CoeloSpacing.space2),
    PersonFileActions(
      activityController: activityController,
      compact: constraints.maxWidth < 1000,
    ),
  ],
)
```

- [ ] **Step 5: Executar GREEN**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/people/presentation/person_file_actions_test.dart test/features/people/presentation/person_directory_page_test.dart --no-pub
```

Expected: PASS.

### Task 2: Paridade visual de Criar e Editar Pessoa

**Files:**
- Modify: `apps/superadmin/lib/features/people/presentation/person_form_page.dart`
- Modify: `apps/superadmin/lib/features/people/presentation/person_form_view_model.dart`
- Modify: `apps/superadmin/test/features/people/presentation/person_form_page_test.dart`
- Modify: `apps/superadmin/test/features/people/presentation/person_form_view_model_test.dart`

**Interfaces:**
- Consumes: `CoeloAvatar`, `CoeloFormTextField`, `CoeloAdminSingleSelectField`, `CoeloAdminDialogShell`, `SuperadminShell`.
- Produces: navegação com estados `current`, `complete`, `incomplete`, `error`; picker visual local de avatar; rodapé idêntico a Instituições.

- [ ] **Step 1: Escrever testes RED da anatomia**

Adicionar testes que exijam:

```dart
expect(find.byKey(const Key('person-profile-photo-card')), findsOneWidget);
expect(find.text('Foto de perfil'), findsOneWidget);
expect(find.text('Escolher foto'), findsOneWidget);
expect(find.byKey(const Key('person-form-navigation')), findsOneWidget);
expect(find.byKey(const Key('person-form-save-current')), findsOneWidget);
```

No mobile, conferir que `Continuar` ocupa a largura útil e
`Cancelar`/`Anterior` compartilham a linha inferior. Em serviço, exigir rodapé
com `Voltar` e ausência de salvar.

- [ ] **Step 2: Executar o RED**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/people/presentation/person_form_page_test.dart test/features/people/presentation/person_form_view_model_test.dart --no-pub
```

Expected: FAIL nas chaves e labels novas.

- [ ] **Step 3: Igualar layout e transição**

Usar exatamente:

```dart
final desktop = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
final contentInset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
    ? CoeloSpacing.space10
    : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
    ? CoeloSpacing.space6
    : CoeloSpacing.space4;
```

O conteúdo permanece em `BoxConstraints(maxWidth: 880)`. A troca de etapa usa:

```dart
AnimatedSwitcher(
  duration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : CoeloMotion.short,
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.025, 0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  ),
  child: section,
)
```

- [ ] **Step 4: Implementar cabeçalho, avatar e navegação**

O cabeçalho usa `headlineSmall`, `bodyMedium`, `space1` e `space5`. O card de
avatar usa `surface`, `outlineVariant`, `CoeloRadius.lg`, `space4`,
`CoeloAvatarSize.large` e ações `Escolher foto`, `Trocar foto`, `Remover`.
Selecionar foto apenas alterna uma prévia local; não acessa arquivo.

O view model expõe:

```dart
bool isStepComplete(PersonFormStep step);
bool isStepInvalid(PersonFormStep step);
```

Identidade é completa quando os quatro nomes obrigatórios estão preenchidos.
Contextos é completa depois de visitada ou quando já possui vínculo; revisão
nunca é marcada completa durante edição.

- [ ] **Step 5: Implementar proteção de saída e rodapé**

Usar `PopScope` e `CoeloAdminDialogShell` com:

```dart
title: 'Sair sem salvar?',
body: const Text(
  'As alterações feitas nesta pessoa serão perdidas se você sair agora.',
),
```

O rodapé copia Instituições: `Criar pessoa` no último passo da criação,
`Salvar alterações` na edição, `Continuar` outlined e
`person-form-save-current` filled nas etapas intermediárias da edição.

- [ ] **Step 6: Executar GREEN**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/people/presentation/person_form_page_test.dart test/features/people/presentation/person_form_view_model_test.dart --no-pub
```

Expected: PASS.

### Task 3: Goldens, acessibilidade e gates

**Files:**
- Modify: `apps/superadmin/test/features/people/presentation/person_golden_test.dart`
- Modify: `apps/superadmin/test/goldens/people/*.png`
- Modify: `docs/knowledge/team/superadmin-people-directory.md`

**Interfaces:**
- Consumes: implementação completa das Tasks 1 e 2.
- Produces: evidência visual aprovada e conhecimento interno durável.

- [ ] **Step 1: Executar goldens sem atualização**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/people/presentation/person_golden_test.dart --no-pub
```

Expected: FAIL visual após a mudança intencional.

- [ ] **Step 2: Gerar candidatos e inspecionar**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/people/presentation/person_golden_test.dart --update-goldens --no-pub
```

Inspecionar cards e tabela em 375/768/1024/1440, Criar 375 light e Editar
1440 dark. Rejeitar qualquer candidato que divirja dos espaçamentos, footer,
menu ou formulário de Instituições.

- [ ] **Step 3: Reexecutar toda a suíte de Pessoas**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/people test/app/router/people_routes_test.dart --no-pub
```

Expected: PASS.

- [ ] **Step 4: Formatar, analisar e validar**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format apps/superadmin/lib/features/people apps/superadmin/test/features/people
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze apps/superadmin/lib/features/people apps/superadmin/test/features/people
```

Executar validadores de índice/fronteiras, os dois gates
`Test-CoeloKnowledge.ps1` e `git diff --check`. Esperado: nenhum diagnóstico
causado por Pessoas.

- [ ] **Step 5: Atualizar conhecimento durável**

Registrar que Arquivos em Pessoas é exclusivamente demonstrativo e que
Criar/Editar usa a anatomia canônica de Instituições. Não registrar atividade,
fixtures ou dados pessoais.

- [ ] **Step 6: Commit final restrito**

Antes do commit:

```powershell
git diff --cached --name-only
```

O resultado deve conter somente arquivos de Pessoas, seus goldens, o plano e a
projeção de conhecimento desta entrega.
