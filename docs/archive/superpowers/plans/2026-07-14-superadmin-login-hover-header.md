---
title: "Superadmin Login Hover and Header Implementation Plan"
source: "docs/superpowers/specs/2026-07-13-superadmin-login-design.md"
status: "completed"
generated_at: "2026-07-14"
---

# Superadmin Login Hover and Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o botao Entrar escurecer no hover e reduzir a altura visual do cabecalho sem perder responsividade, acessibilidade ou aderencia aos tokens Coelo.

**Architecture:** O estado de hover sera um papel semantico do tema por meio de `CoeloActionColors`, consumido pelo widget do botao sem acessar a paleta primitiva. O cabecalho continuara como widget de apresentacao isolado e tera apenas os espacamentos internos reduzidos; a composicao da tela reduzira o intervalo ate o formulario.

**Tech Stack:** Flutter, Material 3, `ThemeExtension`, `flutter_test`, tokens `coelo_tokens`.

## Global Constraints

- Nenhuma cor HEX sera declarada na feature Superadmin.
- O hover deve ser mais escuro em light e dark e nao pode alterar a geometria.
- A assinatura oficial completa permanece no cabecalho.
- Alvos interativos permanecem com no minimo 48 dp.
- O layout deve continuar sem overflow em janelas compactas e texto ampliado.

---

### Task 1: Token semantico e hover do botao

**Files:**
- Modify: `packages/coelo_tokens/lib/src/coelo_theme.dart`
- Modify: `apps/superadmin/lib/features/auth/presentation/widgets/login_submit_button.dart`
- Test: `apps/superadmin/test/features/auth/presentation/screens/superadmin_login_screen_test.dart`

**Interfaces:**
- Produces: `CoeloActionColors.primaryHover: Color`
- Consumes: `Theme.of(context).extension<CoeloActionColors>()!`

- [x] **Step 1: Escrever teste falhando**

Adicionar um widget test que renderiza light e dark, resolve o `backgroundColor` do `FilledButton` com `{WidgetState.hovered}` e exige igualdade com `CoeloActionColors.primaryHover` e luminancia menor que a cor primaria.

- [x] **Step 2: Confirmar RED**

Executar:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/auth/presentation/screens/superadmin_login_screen_test.dart
```

Resultado esperado: falha porque `CoeloActionColors` ainda nao existe e o hover usa alpha.

- [x] **Step 3: Implementar o minimo**

Adicionar ao tema:

```dart
@immutable
final class CoeloActionColors extends ThemeExtension<CoeloActionColors> {
  const CoeloActionColors({required this.primaryHover});
  final Color primaryHover;
}
```

Registrar `CoeloPalette.orange600` no light e `CoeloPalette.orange400` no dark. No `LoginSubmitButton`, resolver hover com `actionColors.primaryHover` e remover o overlay claro do hover.

- [x] **Step 4: Confirmar GREEN**

Executar o mesmo teste e exigir `All tests passed`.

### Task 2: Cabecalho compacto e verificacao responsiva

**Files:**
- Modify: `apps/superadmin/lib/features/auth/presentation/widgets/login_header.dart`
- Modify: `apps/superadmin/lib/features/auth/presentation/screens/superadmin_login_screen.dart`
- Test: `apps/superadmin/test/features/auth/presentation/screens/superadmin_login_screen_test.dart`

**Interfaces:**
- Consumes: `CoeloSpacing.space1`, `space2`, `space3`, `space4`
- Preserves: `LoginHeader()` sem estado e assinatura oficial com `CoeloSize.brandSignatureMd`

- [x] **Step 1: Escrever teste falhando**

Identificar os gaps com `ValueKey`s de apresentacao e testar que logo-chip usa 4 dp, chip-titulo 8 dp, titulo-subtitulo 4 dp, subtitulo-divisor 12 dp e cabecalho-formulario 16 dp.

- [x] **Step 2: Confirmar RED**

Executar o arquivo de widget tests. Resultado esperado: falha porque os gaps atuais sao 8, 16, 8, 16 e 24 dp.

- [x] **Step 3: Implementar o minimo**

Trocar apenas os `SizedBox` correspondentes pelos tokens aprovados, adicionar as chaves de teste e manter logo, tipografia, divisor e semantica existentes.

- [x] **Step 4: Verificar qualidade e build**

Executar format, analyze, o arquivo de widget tests e `flutter build web --release --dart-define=COELO_DEV_MFA=true`. Reiniciar o servidor estatico na porta 8766 e validar light/dark e viewports 375, 768, 1024 e 1440 no navegador.
