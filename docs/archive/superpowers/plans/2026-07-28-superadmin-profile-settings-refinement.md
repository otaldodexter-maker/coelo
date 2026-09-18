# Superadmin Profile and Settings Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refinar Perfil, Configurações e o seletor de cor compartilhado do Superadmin conforme o padrão visual aprovado, sem promover componentes ao Coelo UI.

**Architecture:** O modelo local de conta passa a carregar celular e mantém avatar como rascunho até o salvamento. Um diálogo avançado de cor local ao app é compartilhado por Perfil e Instituições. Ajustes de layout e interação permanecem nas telas atuais, reutilizando tokens e controles do Design System.

**Tech Stack:** Flutter, Dart, `go_router`, `coelo_tokens`, `coelo_ui_core`, `flutter_test`.

## Global Constraints

- Não criar API pública, componente de pacote ou token novo.
- Usar `colorScheme.surface` e `surfaceTintColor: Colors.transparent` em diálogos.
- Usar `CoeloFormTextField` para campos textuais.
- Usar `CoeloSpacing.space3` entre ações 50/50.
- Preservar rascunhos em falhas e impedir ações duplicadas durante salvamento.
- Verificar 375, 768, 1024 e 1440 px, light e dark, texto a 200% e reduced motion.
- Não promover o seletor, rodapé ou diálogos ao Coelo UI nesta entrega.

---

## File Map

- Create `apps/superadmin/lib/app/widgets/superadmin_advanced_color_picker_dialog.dart`: composição avançada de cor compartilhada apenas pelo Superadmin.
- Create `apps/superadmin/test/app/widgets/superadmin_advanced_color_picker_dialog_test.dart`: contrato do diálogo e ações 50/50.
- Modify `apps/superadmin/lib/features/account/domain/account_profile.dart`: celular e cor padrão do avatar.
- Modify `apps/superadmin/lib/features/account/presentation/account_controller.dart`: persistência local do celular.
- Modify `apps/superadmin/lib/features/account/presentation/screens/profile_page.dart`: celular, alinhamento, redefinição, senha e seletor compartilhado.
- Modify `apps/superadmin/lib/features/account/presentation/screens/settings_page.dart`: linha de acessibilidade neutra.
- Modify `apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart`: substituir diálogo local pelo compartilhado.
- Modify `apps/superadmin/test/features/account/domain/account_profile_test.dart`: celular e reset do avatar.
- Modify `apps/superadmin/test/features/account/presentation/account_controller_test.dart`: salvamento do celular.
- Modify `apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart`: interações e layout.
- Modify `apps/superadmin/test/features/account/presentation/screens/settings_page_test.dart`: ausência da faixa cinza.
- Modify `apps/superadmin/test/features/institutions/presentation/screens/institution_form_page_test.dart`: seletor compartilhado e rodapé.

---

### Task 1: Celular e redefinição do avatar no domínio

**Files:**
- Modify: `apps/superadmin/lib/features/account/domain/account_profile.dart`
- Modify: `apps/superadmin/lib/features/account/presentation/account_controller.dart`
- Test: `apps/superadmin/test/features/account/domain/account_profile_test.dart`
- Test: `apps/superadmin/test/features/account/presentation/account_controller_test.dart`

**Interfaces:**
- Produces: `AccountProfile.mobilePhone`, `AccountAvatar.defaultBackgroundColor`, `AccountAvatar.resetFor(firstName, lastName)`.
- Changes: `AccountController.saveProfile({firstName, lastName, email, mobilePhone, avatar})`.

- [ ] **Step 1: Write failing domain tests**

```dart
test('prototype exposes a mobile phone', () {
  expect(AccountProfile.prototype().mobilePhone, '+55 11 99999-0000');
});

test('reset avatar removes photo and derives default initials and color', () {
  final reset = AccountProfile.prototype().avatar
      .copyWith(mode: AccountAvatarMode.photo, photoBytes: Uint8List.fromList([1]))
      .resetFor('Maria', 'Silva');
  expect(reset.mode, AccountAvatarMode.initials);
  expect(reset.photoBytes, isNull);
  expect(reset.initials, 'MS');
  expect(reset.backgroundColor, AccountAvatar.defaultBackgroundColor);
});
```

- [ ] **Step 2: Run domain tests and confirm the missing members fail**

Run:

```powershell
flutter test test/features/account/domain/account_profile_test.dart
```

Expected: FAIL because `mobilePhone`, `defaultBackgroundColor` and `resetFor` do not exist.

- [ ] **Step 3: Implement the domain members**

Add to `AccountAvatar`:

```dart
static const defaultBackgroundColor = CoeloPalette.orange50;

AccountAvatar resetFor(String firstName, String lastName) => AccountAvatar(
  mode: AccountAvatarMode.initials,
  initials: initialsFor(firstName, lastName),
  backgroundColor: defaultBackgroundColor,
);
```

Add required `mobilePhone` to `AccountProfile`, initialize the prototype with
`'+55 11 99999-0000'`, and preserve it in `copyWith`.

- [ ] **Step 4: Write the failing controller test**

```dart
await controller.saveProfile(
  firstName: 'Owner',
  lastName: 'Coelo',
  email: 'owner@coelo.me',
  mobilePhone: '+55 11 98888-7777',
  avatar: controller.profile!.avatar,
);
expect(controller.profile!.mobilePhone, '+55 11 98888-7777');
```

- [ ] **Step 5: Extend `saveProfile` and run both tests**

Normalize with `mobilePhone.trim()` and pass it to `current.copyWith`.

Run:

```powershell
flutter test test/features/account/domain/account_profile_test.dart test/features/account/presentation/account_controller_test.dart
```

Expected: PASS.

---

### Task 2: Seletor avançado compartilhado

**Files:**
- Create: `apps/superadmin/lib/app/widgets/superadmin_advanced_color_picker_dialog.dart`
- Create: `apps/superadmin/test/app/widgets/superadmin_advanced_color_picker_dialog_test.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_form_page_test.dart`

**Interfaces:**
- Produces:

```dart
Future<Color?> showSuperadminAdvancedColorPicker(
  BuildContext context, {
  required Color initialColor,
  required String title,
});
```

- [ ] **Step 1: Write a failing widget test for the shared dialog**

Open the dialog from a test button and assert:

```dart
expect(find.byKey(const Key('advanced-color-picker-dialog')), findsOneWidget);
expect(find.byKey(const Key('advanced-color-picker-cancel')), findsOneWidget);
expect(find.byKey(const Key('advanced-color-picker-apply')), findsOneWidget);
expect(
  tester.getSize(find.byKey(const Key('advanced-color-picker-cancel'))).width,
  tester.getSize(find.byKey(const Key('advanced-color-picker-apply'))).width,
);
```

Also change the color and cancel, then assert the returned value remains null.

- [ ] **Step 2: Run the new test and confirm the missing API fails**

Run:

```powershell
flutter test test/app/widgets/superadmin_advanced_color_picker_dialog_test.dart
```

Expected: FAIL because the shared dialog file/API does not exist.

- [ ] **Step 3: Extract the Institutions dialog**

Move the current saturation/value plane, hue strip, Atual/Nova samples, HSV,
RGB and hexadecimal controls to the new file. Build the footer as:

```dart
Row(
  children: [
    Expanded(
      child: OutlinedButton(
        key: const Key('advanced-color-picker-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
    ),
    const SizedBox(width: CoeloSpacing.space3),
    Expanded(
      child: FilledButton(
        key: const Key('advanced-color-picker-apply'),
        onPressed: () => Navigator.of(context).pop(selectedColor),
        child: const Text('Usar cor'),
      ),
    ),
  ],
);
```

Use `Dialog`/`AlertDialog` with `colorScheme.surface`,
`surfaceTintColor: Colors.transparent` and width constraints matching the
existing Institutions picker.

- [ ] **Step 4: Replace the private Institutions dialog**

Change `_ColorField` to call `showSuperadminAdvancedColorPicker(...)` and remove
the duplicated `_ColorPickerDialog` implementation only after the shared test
passes.

- [ ] **Step 5: Run shared and Institutions tests**

Run:

```powershell
flutter test test/app/widgets/superadmin_advanced_color_picker_dialog_test.dart test/features/institutions/presentation/screens/institution_form_page_test.dart
```

Expected: PASS, including equal footer widths and unchanged color on cancel.

---

### Task 3: Perfil responsivo, celular e redefinição

**Files:**
- Modify: `apps/superadmin/lib/features/account/presentation/screens/profile_page.dart`
- Modify: `apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart`

**Interfaces:**
- Consumes: `AccountProfile.mobilePhone`, `AccountAvatar.resetFor`, `showSuperadminAdvancedColorPicker`.

- [ ] **Step 1: Write failing profile interaction tests**

Assert the mobile field exists:

```dart
expect(find.byKey(const Key('account-mobile-phone-field')), findsOneWidget);
```

Change name/surname, simulate a photo avatar through the test repository, tap
`account-reset-profile`, and assert the avatar preview shows derived initials
and the repository is unchanged before Save. Tap Save and assert the repository
now contains initials mode and default color.

- [ ] **Step 2: Write failing layout tests**

At 1440 px, assert the bottom coordinate of the personal card equals the bottom
coordinate of the right-side column container. At 375 px, assert personal,
access and security cards appear in a single vertical sequence without
exceptions.

- [ ] **Step 3: Run profile tests and verify the new expectations fail**

Run:

```powershell
flutter test test/features/account/presentation/screens/profile_page_test.dart
```

Expected: FAIL because celular/reset keys and aligned grid do not exist.

- [ ] **Step 4: Implement state and fields**

Add `_mobilePhone`, initialized from the profile and disposed with the other
controllers. Pass it to `_PersonalDataForm` and `saveProfile`. Render:

```dart
CoeloFormTextField(
  key: const Key('account-mobile-phone-field'),
  controller: mobilePhone,
  labelText: 'Celular',
  prefixIcon: Icons.smartphone_outlined,
  keyboardType: TextInputType.phone,
);
```

Replace `_AvatarColorDialog` with `showSuperadminAdvancedColorPicker`.

- [ ] **Step 5: Implement aligned wide layout and reset footer**

Use the existing responsive breakpoint. In wide mode, stretch the left card and
the right column to the same row height; use `Expanded` for the Security card so
the bases align. In compact mode, preserve the current semantic sequence.

Change `_FormFooter` to receive `onReset` and render:

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    OutlinedButton.icon(
      key: const Key('account-reset-profile'),
      onPressed: busy ? null : onReset,
      icon: const Icon(Icons.restart_alt_rounded),
      label: const Text('Redefinir'),
    ),
    FilledButton.icon(
      key: const Key('account-save-profile'),
      onPressed: busy ? null : onSave,
      icon: const Icon(Icons.save_outlined),
      label: const Text('Salvar alterações'),
    ),
  ],
);
```

`onReset` updates only local controllers/avatar using current name and surname.

- [ ] **Step 6: Run profile tests**

Run:

```powershell
flutter test test/features/account/presentation/screens/profile_page_test.dart
```

Expected: PASS.

---

### Task 4: Diálogo de senha e Configurações

**Files:**
- Modify: `apps/superadmin/lib/features/account/presentation/screens/profile_page.dart`
- Modify: `apps/superadmin/lib/features/account/presentation/screens/settings_page.dart`
- Modify: `apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart`
- Modify: `apps/superadmin/test/features/account/presentation/screens/settings_page_test.dart`

**Interfaces:**
- Produces keys `account-password-close`, `account-password-cancel`,
  `account-password-submit`, `settings-reduce-motion-row`.

- [ ] **Step 1: Write failing password-dialog tests**

Open Alterar senha and assert the close icon is `Icons.close_rounded`, uses
`colorScheme.error`, has tooltip `Fechar alteração de senha`, and both footer
buttons have equal widths.

- [ ] **Step 2: Write a failing Settings surface test**

Find `settings-reduce-motion-row` and assert its `Material.color` is
`Colors.transparent`; hover it with a mouse and confirm no enclosing gray
container color appears.

- [ ] **Step 3: Run both tests and confirm failure**

Run:

```powershell
flutter test test/features/account/presentation/screens/profile_page_test.dart test/features/account/presentation/screens/settings_page_test.dart
```

Expected: FAIL because the keys, close action and explicit neutral row contract
do not exist.

- [ ] **Step 4: Recompose the password dialog**

Use a title row with `Expanded(Text('Alterar senha'))` and:

```dart
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
);
```

Build Cancelar and Alterar senha in a `Row` with two `Expanded` children and
`CoeloSpacing.space3`.

- [ ] **Step 5: Make the accessibility row neutral**

Give the wrapping `Material` the key `settings-reduce-motion-row`, keep
`color: Colors.transparent`, and configure the tile overlay/hover to remain
transparent. Do not add `surfaceContainer`.

- [ ] **Step 6: Run both tests**

Run:

```powershell
flutter test test/features/account/presentation/screens/profile_page_test.dart test/features/account/presentation/screens/settings_page_test.dart
```

Expected: PASS.

---

### Task 5: Responsive and regression verification

**Files:**
- Modify if needed: `apps/superadmin/test/features/account/presentation/screens/account_pages_golden_test.dart`
- Update generated goldens only when the new output matches the approved spec.

- [ ] **Step 1: Run account, Institutions and shell tests**

```powershell
flutter test test/features/account test/features/institutions/presentation/screens/institution_form_page_test.dart test/app/shell/superadmin_shell_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Run static analysis**

```powershell
dart analyze lib/features/account lib/features/institutions/presentation/widgets/institution_form_sections.dart lib/app/widgets test/features/account test/app/widgets
```

Expected: `No issues found!`

- [ ] **Step 3: Run the approved golden matrix**

```powershell
flutter test test/features/account/presentation/screens/account_pages_golden_test.dart --update-goldens
flutter test test/features/account/presentation/screens/account_pages_golden_test.dart
```

Expected: 375, 768, 1024 and 1440 cases pass, including mobile light and desktop
dark.

- [ ] **Step 4: Inspect git diff**

Confirm only intended account, Institutions color picker, tests and goldens
changed. Do not stage unrelated pre-existing worktree changes.

- [ ] **Step 5: Run the Coelo knowledge gate**

Update the existing canonical profile/settings design only if implementation
reveals a durable behavior not already captured. Otherwise report `no-op`.
Validate any knowledge change with:

```powershell
& .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1
& .agents/skills/coelo-knowledge/tests/Test-CoeloKnowledge.ps1
```

