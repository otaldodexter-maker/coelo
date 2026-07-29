---
source: "docs/superpowers/specs/2026-07-28-profile-settings-final-surface-adjustments-design.md"
status: "approved"
generated_at: "2026-07-28"
---

# Profile and Settings Final Surface Adjustments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar o divisor canônico ao cabeçalho de alteração de senha e eliminar a superfície de hover da linha Reduzir animações.

**Architecture:** Alterar somente a composição local das duas telas. O diálogo continua usando `AlertDialog`; sua `title` passa a reproduzir cabeçalho e divisor do popup de Bug. A preferência de movimento continua no mesmo controlador, mas a UI troca `SwitchListTile` por texto neutro e `Switch.adaptive`.

**Tech Stack:** Flutter, Material 3, `coelo_tokens`, `coelo_ui_core`, `flutter_test`.

## Global Constraints

- Não criar componentes públicos, tokens ou dependências.
- Preservar textos, persistência, responsividade e comportamento existentes.
- Usar `colorScheme.outlineVariant` no divisor de 1 px.
- A linha de acessibilidade não pode ter hover, splash ou overlay.
- O switch deve permanecer acessível por mouse, toque, teclado e leitor de tela.

---

### Task 1: Cabeçalho canônico no diálogo de senha

**Files:**
- Modify: `apps/superadmin/lib/features/account/presentation/screens/profile_page.dart:680-710`
- Test: `apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart`

**Interfaces:**
- Consumes: `Theme.of(context).colorScheme.outlineVariant`, `CoeloSize.touchMin`.
- Produces: widget identificado por `Key('account-password-header-divider')`.

- [ ] **Step 1: Escrever o teste vermelho**

No teste `uses a canonical close action and balanced footer in the password dialog`,
acrescentar:

```dart
final headerDivider = find.byKey(const Key('account-password-header-divider'));
expect(headerDivider, findsOneWidget);
final divider = tester.widget<Divider>(headerDivider);
expect(divider.height, 1);
expect(divider.color, Theme.of(tester.element(headerDivider)).colorScheme.outlineVariant);
```

- [ ] **Step 2: Executar o teste e confirmar a falha**

```powershell
flutter test test/features/account/presentation/screens/profile_page_test.dart --plain-name "uses a canonical close action and balanced footer in the password dialog"
```

Esperado: falha em `findsOneWidget`, pois o divisor ainda não existe.

- [ ] **Step 3: Implementar o cabeçalho mínimo**

Substituir a `title` atual do `AlertDialog` por:

```dart
title: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Row(
      children: [
        const Expanded(child: Text('Alterar senha')),
        IconButton(
          key: const Key('account-password-close'),
          tooltip: 'Fechar alteração de senha',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          color: Theme.of(context).colorScheme.error,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(CoeloSize.touchMin),
            hoverColor: Theme.of(context).colorScheme.errorContainer,
            focusColor: Theme.of(context).colorScheme.errorContainer,
            highlightColor: Colors.transparent,
          ),
        ),
      ],
    ),
    Divider(
      key: const Key('account-password-header-divider'),
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  ],
),
```

- [ ] **Step 4: Confirmar teste verde**

Executar o comando do Step 2.

Esperado: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/account/presentation/screens/profile_page.dart apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart
git commit -m "fix(superadmin): align password dialog header"
```

### Task 2: Linha de acessibilidade sem hover

**Files:**
- Modify: `apps/superadmin/lib/features/account/presentation/screens/settings_page.dart:68-87`
- Test: `apps/superadmin/test/features/account/presentation/screens/settings_page_test.dart`

**Interfaces:**
- Consumes: `UserPreferencesController.setReduceMotion(bool)`.
- Produces: linha neutra `Key('settings-reduce-motion-row')` e switch `Key('settings-reduce-motion')`.

- [ ] **Step 1: Escrever o teste vermelho**

Substituir o teste atual de hover por:

```dart
testWidgets('uses a neutral reduced motion row without a hover surface', (tester) async {
  final controller = UserPreferencesController(InMemoryUserPreferencesRepository());
  await controller.load();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: SettingsPage(
        controller: controller,
        logout: () async => const LogoutResult.success(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final row = find.byKey(const Key('settings-reduce-motion-row'));
  expect(row, findsOneWidget);
  expect(find.descendant(of: row, matching: find.byType(SwitchListTile)), findsNothing);
  expect(find.descendant(of: row, matching: find.byType(InkWell)), findsNothing);
  expect(find.byKey(const Key('settings-reduce-motion')), findsOneWidget);
});
```

- [ ] **Step 2: Executar o teste e confirmar a falha**

```powershell
flutter test test/features/account/presentation/screens/settings_page_test.dart --plain-name "uses a neutral reduced motion row without a hover surface"
```

Esperado: falha porque a linha ainda contém `SwitchListTile` e sua superfície interativa.

- [ ] **Step 3: Implementar a composição neutra**

Substituir `Material` e `SwitchListTile.adaptive` por:

```dart
Semantics(
  key: const Key('settings-reduce-motion-row'),
  container: true,
  label: 'Reduzir animações',
  child: Row(
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reduzir animações'),
            SizedBox(height: CoeloSpacing.spaceHalf),
            Text('Também respeitamos a preferência de movimento do sistema.'),
          ],
        ),
      ),
      const SizedBox(width: CoeloSpacing.space4),
      Switch.adaptive(
        key: const Key('settings-reduce-motion'),
        value: controller.preferences.reduceMotion,
        onChanged: controller.setReduceMotion,
      ),
    ],
  ),
),
```

- [ ] **Step 4: Confirmar teste verde e persistência**

```powershell
flutter test test/features/account/presentation/screens/settings_page_test.dart
```

Esperado: os dois testes passam e a preferência continua persistida.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/account/presentation/screens/settings_page.dart apps/superadmin/test/features/account/presentation/screens/settings_page_test.dart
git commit -m "fix(superadmin): remove settings row hover"
```

### Task 3: Regressão e inspeção visual

**Files:**
- Verify: `apps/superadmin/lib/features/account/presentation/screens/profile_page.dart`
- Verify: `apps/superadmin/lib/features/account/presentation/screens/settings_page.dart`

**Interfaces:**
- Consumes: resultados das Tasks 1 e 2.
- Produces: evidência de regressão e análise estática.

- [ ] **Step 1: Executar testes de Perfil e Configurações**

```powershell
flutter test test/features/account/presentation/screens/profile_page_test.dart test/features/account/presentation/screens/settings_page_test.dart
```

Esperado: todos os testes passam.

- [ ] **Step 2: Executar análise focada**

```powershell
dart analyze lib/features/account/presentation/screens/profile_page.dart lib/features/account/presentation/screens/settings_page.dart test/features/account/presentation/screens/profile_page_test.dart test/features/account/presentation/screens/settings_page_test.dart
```

Esperado: `No issues found!`

- [ ] **Step 3: Inspecionar no host local**

Verificar `/dev/profile` e `/dev/settings` em light e dark:

- o diálogo de senha possui a linha sob o cabeçalho;
- a linha Reduzir animações não muda de fundo com o mouse;
- não há overflow ou mudança fora do escopo.

- [ ] **Step 4: Executar o gate de conhecimento**

Como não há regra durável nova além da spec canônica, registrar `no-op` e validar:

```powershell
& .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1
& .agents/skills/coelo-knowledge/tests/Test-CoeloKnowledge.ps1
```

Esperado: ambos os validadores passam.
