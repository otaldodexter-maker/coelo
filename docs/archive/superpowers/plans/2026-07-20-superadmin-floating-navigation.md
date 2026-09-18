---
title: "Superadmin Floating Navigation Implementation Plan"
source: "docs/superpowers/specs/2026-07-20-superadmin-floating-navigation-people-context-design.md"
status: "approved-for-implementation"
generated_at: "2026-07-20"
---

# Superadmin Floating Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar a shell compartilhada em duas superficies flutuantes e adicionar navegacao hierarquica responsiva com hover, toggle e menu de usuario coerentes com o design system Coelo.

**Architecture:** Manter `SuperadminShell` como ponto unico de composicao e usar `LayoutBuilder` para desktop/drawer. A hierarquia fica em configuracao imutavel local, sem novas dependencias; destinos ainda nao implementados preservam feedback seguro.

**Tech Stack:** Flutter, Dart, Material 3, `coelo_tokens`, `flutter_test`.

## Global Constraints

- Usar somente tokens e cores semanticas existentes; nenhum HEX local.
- Manter Nunito Sans e componentes Material tematizados.
- Sidebar e area principal usam gutters e raios compartilhados.
- Hover nao pode introduzir cinza intermediario nem layout shift.
- Toggle inicia cada sessao em `ThemeMode.system` e depois alterna claro/escuro.
- Viewports obrigatorios: 375, 768, 1024 e 1440.
- Nenhuma dependencia nova.

---

### Task 1: Fixar o comportamento esperado com widget tests RED

**Files:**
- Modify: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `SuperadminShell`, `CoeloTheme`, `SuperadminThemeModeScope`.
- Produces: contrato visual e interativo da shell.

- [ ] **Step 1: Atualizar teste da hierarquia**

Esperar categorias `Estrutura`, `Acessos`, `Operacao`, `Comunicacao`, `Governanca` e subitens:

```dart
for (final label in [
  'Instituicoes', 'Unidades', 'Grupos',
  'Pessoas', 'Usuarios internos', 'Perfis e permissoes',
  'Planos', 'Importacoes', 'Convites', 'Avisos',
  'Suporte', 'Auditoria',
]) {
  expect(find.text(label), findsOneWidget);
}
```

- [ ] **Step 2: Adicionar testes de superficie e divisores**

Validar margem externa, `CoeloRadius.xl` ou token equivalente, sidebar sem `VerticalDivider` de ponta a ponta e divisores recuados com largura menor que o container.

- [ ] **Step 3: Adicionar testes de acordeao e menu recolhido**

Validar categoria ativa laranja, expansao sem troca de rota, submenu ativo, recolhimento para 88 px e flyout ancorado ao clicar uma categoria recolhida.

- [ ] **Step 4: Adicionar testes de hover, toggle e logout**

Validar `primaryContainer` direto no hover, toggle expandido menor que o atual, versao vertical recolhida e item `Sair` com `colorScheme.error`/`errorContainer`.

- [ ] **Step 5: Executar e confirmar RED**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/app/shell/superadmin_shell_test.dart
```

Workdir: `apps/superadmin`

Expected: FAIL porque categorias, superficies flutuantes e novos estados ainda nao existem.

### Task 2: Implementar shell flutuante e navegacao hierarquica minima

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `CoeloSpacing`, `CoeloRadius`, `CoeloMotion`, `CoeloActionColors`.
- Produces: shell compartilhada responsiva, acordeoes e flyout.

- [ ] **Step 1: Criar configuracao local de secoes**

```dart
const _navigationSections = <_NavigationSectionData>[
  _NavigationSectionData('structure', 'Estrutura', Icons.account_balance_outlined, [
    _NavigationDestinationData('institutions', 'Instituicoes', Icons.account_balance_outlined, active: true),
    _NavigationDestinationData('units', 'Unidades', Icons.apartment_outlined),
    _NavigationDestinationData('groups', 'Grupos', Icons.groups_outlined),
  ]),
  _NavigationSectionData('access', 'Acessos', Icons.manage_accounts_outlined, [
    _NavigationDestinationData('people', 'Pessoas', Icons.people_outline),
    _NavigationDestinationData('internal-users', 'Usuarios internos', Icons.badge_outlined),
    _NavigationDestinationData('profiles', 'Perfis e permissoes', Icons.admin_panel_settings_outlined),
  ]),
  _NavigationSectionData('operations', 'Operacao', Icons.tune_outlined, [
    _NavigationDestinationData('plans', 'Planos', Icons.loyalty_outlined),
    _NavigationDestinationData('import', 'Importacoes', Icons.upload_file_outlined),
  ]),
  _NavigationSectionData('communication', 'Comunicacao', Icons.forum_outlined, [
    _NavigationDestinationData('invites', 'Convites', Icons.mail_outline),
    _NavigationDestinationData('notices', 'Avisos', Icons.campaign_outlined),
  ]),
  _NavigationSectionData('governance', 'Governanca', Icons.verified_user_outlined, [
    _NavigationDestinationData('support', 'Suporte', Icons.support_agent_outlined),
    _NavigationDestinationData('audit', 'Auditoria', Icons.security_outlined),
  ]),
];
```

Usar os textos acentuados no codigo final; o bloco acima explicita apenas os ids e a hierarquia.

- [ ] **Step 2: Tornar desktop duas superficies flutuantes**

Usar `Padding`, `Row`, `SizedBox` e `DecoratedBox` dentro do `LayoutBuilder`. Sidebar e painel principal usam `surface`, `outlineVariant`, raio tokenizado e sombra semantica sutil. Remover o `VerticalDivider` externo e usar gap do scaffold entre as superficies.

- [ ] **Step 3: Implementar acordeoes expandidos**

Somente `Estrutura` inicia aberta por conter a rota ativa. Clique no cabecalho alterna sua expansao; clique em destino futuro chama o feedback existente. Estados hover/focus sao resolvidos uma unica vez com `WidgetStateProperty` para impedir o flash cinza.

- [ ] **Step 4: Implementar flyout recolhido e drawer mobile**

No modo recolhido, usar `MenuAnchor`/`MenuItemButton` Material para exibir os filhos ao lado do icone. No mobile, reutilizar a mesma lista expandida dentro do drawer.

- [ ] **Step 5: Recuar divisores e alinhar gutters**

Substituir divisores full-width por helper local que aplica `Padding(horizontal: CoeloSpacing.space4)` e manter titulo/subtitulo no mesmo gutter.

- [ ] **Step 6: Executar teste focado**

Run: comando da Task 1.

Expected: PASS.

### Task 3: Refinar toggle e menu do usuario

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `SuperadminThemeModeScope`, `ColorScheme.error`, `CoeloActionColors`.
- Produces: toggle sutil e menu de perfil com logout semantico.

- [ ] **Step 1: Reduzir o toggle**

Usar aproximadamente `160 x 40` expandido, `40 x 80` recolhido e thumb de `32 x 32`, sempre limitado pelos tokens existentes mais proximos. Remover sombra forte e manter apenas elevacao sutil da marca Coelo.

- [ ] **Step 2: Fixar toggle no rodape interno**

Adicionar divisor recuado acima do controle e padding uniforme. O controle nao deve encostar no limite inferior ou parecer solto no espaco vazio.

- [ ] **Step 3: Migrar popup de perfil para controles com estado individual**

Usar `MenuAnchor` e `MenuItemButton` para Perfil, Configuracoes e Sair. Resolver o ultimo item assim:

```dart
foregroundColor: WidgetStatePropertyAll(colors.error),
backgroundColor: WidgetStateProperty.resolveWith((states) {
  return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
      ? colors.errorContainer
      : Colors.transparent;
}),
```

O menu abre abaixo do acionador e preserva cantos arredondados.

- [ ] **Step 4: Executar teste focado**

Run: comando da Task 1.

Expected: PASS.

### Task 4: Validar responsividade e qualidade Flutter

**Files:**
- Modify only if a failing check requires a scoped correction.

**Interfaces:**
- Consumes: implementacao completa.
- Produces: evidencia de qualidade e build web.

- [ ] **Step 1: Formatar arquivos alterados**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/app/shell/superadmin_shell.dart test/app/shell/superadmin_shell_test.dart
```

- [ ] **Step 2: Executar analise estatica**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Executar suite Flutter**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test
```

Expected: todos os testes passam.

- [ ] **Step 4: Executar build web**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart build web --dart-define=COELO_DEV_MFA=true
```

Expected: `Built build\\web`.

- [ ] **Step 5: Verificar diff e commit**

Run: `git diff --check`

Expected: sem erros.

```bash
git add apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart
git commit -m "feat(superadmin): add floating hierarchical navigation"
```
