---
title: "Plano de implementação de sentimentos na Rotina diária"
source: "docs/superpowers/specs/2026-08-03-superadmin-daily-routine-feelings-design.md"
status: "approved-for-inline-execution"
generated_at: "2026-08-03"
---

# Sentimentos na Rotina diária — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar `Como chegou?` em uma escolha opcional com cinco sentimentos principais, quatro em `Ver mais` e envio local de sugestões não aplicáveis aos participantes.

**Architecture:** O catálogo e as sugestões permanecem no domínio local de `daily_routine`; o repositório guarda identificadores estáveis e sugestões pendentes em memória. Widgets locais compõem a seleção e os diálogos com componentes Coelo aprovados, enquanto o editor coordena seleção individual, limpeza e lote sem alterar Chamada, Admin, Principal ou backend.

**Tech Stack:** Dart 3, Flutter, `coelo_tokens`, `coelo_ui_core`, `coelo_ui_admin`, `flutter_test`.

## Global Constraints

- Escopo limitado a `apps/superadmin`, à spec canônica e à projeção interna de conhecimento.
- Emoji sempre acompanha rótulo textual; `Não informado` é ausência de valor.
- Somente Owner altera valores ou envia sugestões; leitura permanece disponível aos demais.
- Sugestões livres ficam pendentes em memória e nunca entram no catálogo ou no registro de participante.
- Nenhum novo token, componente público, dependência, backend ou valor inicial será criado.
- Aplicação em lote preserva exceções por padrão e exige confirmação explícita para sobrescrever.
- Usar apenas componentes e tokens Coelo; executar o validador visual administrativo bloqueante.

---

## Estrutura de arquivos

- `apps/superadmin/lib/features/daily_routine/daily_routine.dart`: catálogo, sugestão, armazenamento e operações de domínio.
- `apps/superadmin/lib/features/daily_routine/daily_routine_controller.dart`: comandos autorizados e notificações de mudança.
- `apps/superadmin/lib/features/daily_routine/daily_routine_feeling_picker.dart`: composição local das cinco opções, `Ver mais` e limpeza.
- `apps/superadmin/lib/features/daily_routine/daily_routine_feeling_dialogs.dart`: catálogo adicional e envio de sugestão com `CoeloAdminDialogShell`.
- `apps/superadmin/lib/features/daily_routine/daily_routine_pages.dart`: integração individual e em lote no editor existente.
- `apps/superadmin/test/features/daily_routine/daily_routine_repository_test.dart`: comportamento de domínio.
- `apps/superadmin/test/features/daily_routine/daily_routine_feeling_picker_test.dart`: seleção, expansão, sugestão, semântica e leitura.
- `apps/superadmin/test/features/daily_routine/daily_routine_pages_test.dart`: integração do editor e lote.
- `apps/superadmin/test/features/daily_routine/daily_routine_golden_test.dart`: mobile light e desktop dark.
- `apps/superadmin/test/features/daily_routine/goldens/`: referências visuais geradas pelos testes.
- `specs/021-superadmin-daily-routine-prototype.md`: comportamento canônico aprovado.
- `docs/knowledge/team/superadmin-daily-routine-prototype.md`: projeção interna durável.

---

### Task 1: Modelar catálogo opcional e sugestões pendentes

**Files:**
- Modify: `apps/superadmin/test/features/daily_routine/daily_routine_repository_test.dart`
- Modify: `apps/superadmin/lib/features/daily_routine/daily_routine.dart`
- Modify: `apps/superadmin/lib/features/daily_routine/daily_routine_controller.dart`

**Interfaces:**
- Produces: `DailyRoutineFeeling`, `DailyRoutineFeelingSuggestion`, `participantFeeling`, `setParticipantFeeling`, `clearParticipantFeeling`, `suggestFeeling`, `feelingSuggestions`.
- Stores: `DailyRoutineFeeling.id` em `participantValues[participantId]['mood']`.

- [ ] **Step 1: Escrever testes de domínio que falham**

Adicionar testes equivalentes a:

```dart
test('feeling catalog exposes five primary and four additional options', () {
  expect(DailyRoutineFeeling.primary, hasLength(5));
  expect(DailyRoutineFeeling.additional, hasLength(4));
  expect(
    DailyRoutineFeeling.values.map((feeling) => feeling.label),
    ['Animado', 'Calmo', 'Sensível', 'Irritado', 'Sonolento', 'Triste', 'Desanimado', 'Distraído', 'Agitado'],
  );
});

test('mood field is optional and has no initial value', () {
  final field = InMemoryDailyRoutineRepository.seeded()
      .models.first.sections.expand((section) => section.fields)
      .singleWhere((field) => field.id == 'mood');
  expect(field.required, isFalse);
  expect(field.initialValue, isNull);
});

test('participant feeling can be selected and cleared', () {
  final repository = InMemoryDailyRoutineRepository.seeded();
  repository.setParticipantFeeling('participant-2', DailyRoutineFeeling.sad);
  expect(repository.participantFeeling('participant-2'), DailyRoutineFeeling.sad);
  repository.clearParticipantFeeling('participant-2');
  expect(repository.participantFeeling('participant-2'), isNull);
  expect(repository.participantValues['participant-2'], isNot(contains('mood')));
});

test('suggestion stays pending and never changes the approved catalog', () {
  final repository = InMemoryDailyRoutineRepository.seeded();
  final before = DailyRoutineFeeling.values.length;
  repository.suggestFeeling('  Curioso  ', now: DateTime.utc(2026, 8, 3));
  expect(repository.feelingSuggestions.single.text, 'Curioso');
  expect(repository.feelingSuggestions.single.status, DailyRoutineFeelingSuggestionStatus.pending);
  expect(DailyRoutineFeeling.values, hasLength(before));
});
```

- [ ] **Step 2: Executar o teste e confirmar RED**

Run, em `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/daily_routine/daily_routine_repository_test.dart
```

Expected: FAIL por tipos e métodos ainda inexistentes e pela obrigatoriedade atual.

- [ ] **Step 3: Implementar o domínio mínimo**

Adicionar o catálogo:

```dart
enum DailyRoutineFeeling {
  animated('animated', '😊', 'Animado', true),
  calm('calm', '😌', 'Calmo', true),
  sensitive('sensitive', '🥺', 'Sensível', true),
  irritated('irritated', '😠', 'Irritado', true),
  sleepy('sleepy', '😴', 'Sonolento', true),
  sad('sad', '😢', 'Triste', false),
  discouraged('discouraged', '😔', 'Desanimado', false),
  distracted('distracted', '🤔', 'Distraído', false),
  agitated('agitated', '😣', 'Agitado', false);

  const DailyRoutineFeeling(this.id, this.emoji, this.label, this.isPrimary);
  final String id;
  final String emoji;
  final String label;
  final bool isPrimary;

  static List<DailyRoutineFeeling> get primary =>
      values.where((feeling) => feeling.isPrimary).toList(growable: false);
  static List<DailyRoutineFeeling> get additional =>
      values.where((feeling) => !feeling.isPrimary).toList(growable: false);
  static DailyRoutineFeeling? fromId(Object? id) =>
      values.where((feeling) => feeling.id == id).firstOrNull;
}

enum DailyRoutineFeelingSuggestionStatus { pending }

final class DailyRoutineFeelingSuggestion {
  const DailyRoutineFeelingSuggestion({
    required this.id,
    required this.text,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String text;
  final DailyRoutineFeelingSuggestionStatus status;
  final DateTime createdAt;
}
```

Se `firstOrNull` não estiver disponível sem nova dependência, implementar `fromId`
com um `for` e retorno `null`. No seed, definir `required: false`, remover
`initialValue`, armazenar apenas IDs aprovados e não preencher participantes
vazios. `clearParticipantFeeling` deve remover a chave `mood`. `suggestFeeling`
deve aplicar `trim`, rejeitar vazio com `ArgumentError.value`, criar ID local
determinístico e nunca alterar `DailyRoutineFeeling.values`.

Expor no controller os três comandos autorizados:

```dart
void setParticipantFeeling(String participantId, DailyRoutineFeeling feeling);
void clearParticipantFeeling(String participantId);
void suggestFeeling(String text);
```

Todos chamam `_requireWrite()` antes do repositório e `notifyListeners()` depois.

- [ ] **Step 4: Executar o teste e confirmar GREEN**

Run: o mesmo comando do Step 2.

Expected: PASS, sem warnings.

- [ ] **Step 5: Formatar e revisar o diff da task**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/features/daily_routine/daily_routine.dart lib/features/daily_routine/daily_routine_controller.dart test/features/daily_routine/daily_routine_repository_test.dart
git diff -- apps/superadmin/lib/features/daily_routine apps/superadmin/test/features/daily_routine/daily_routine_repository_test.dart
```

---

### Task 2: Criar seletor local, expansão e envio de sugestão

**Files:**
- Create: `apps/superadmin/lib/features/daily_routine/daily_routine_feeling_picker.dart`
- Create: `apps/superadmin/lib/features/daily_routine/daily_routine_feeling_dialogs.dart`
- Create: `apps/superadmin/test/features/daily_routine/daily_routine_feeling_picker_test.dart`

**Interfaces:**
- Consumes: `DailyRoutineFeeling`, `DailyRoutineFeelingSuggestion`, `CoeloAdminDialogShell`, `CoeloFormTextField`.
- Produces: `DailyRoutineFeelingPicker(value, enabled, onChanged, onSuggestFeeling)` e `showDailyRoutineFeelingSuggestionDialog`.

- [ ] **Step 1: Escrever testes de widget que falham**

Cobrir os comportamentos:

```dart
expect(find.text('😊 Animado'), findsOneWidget);
expect(find.text('😌 Calmo'), findsOneWidget);
expect(find.text('😢 Triste'), findsNothing);
expect(find.text('Ver mais'), findsOneWidget);

await tester.tap(find.text('Ver mais'));
await tester.pumpAndSettle();
expect(find.text('😢 Triste'), findsOneWidget);
expect(find.text('Sugerir sentimento'), findsOneWidget);
```

Adicionar casos separados para:

- selecionar uma principal e uma adicional;
- `Limpar sentimento` produzir `null`;
- estado disabled não expor ações mutáveis;
- semântica da opção selecionada conter `isSelected` e o rótulo completo;
- diálogo manter `Enviar sugestão` desabilitado para espaços;
- envio de `Curioso` chamar o callback uma vez e não criar nova opção visual.

- [ ] **Step 2: Executar o teste e confirmar RED**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/daily_routine/daily_routine_feeling_picker_test.dart
```

Expected: FAIL porque os arquivos e widgets ainda não existem.

- [ ] **Step 3: Implementar a composição mínima com componentes aprovados**

`DailyRoutineFeelingPicker` deve usar `Wrap` tokenizado e opções de escolha única
com chaves `daily-routine-feeling-<id>`. Cada opção renderiza
`${feeling.emoji} ${feeling.label}`, expõe `Semantics(selected: ...)` e usa
estado tonal primário sem HEX ou números visuais locais.

O gatilho `Ver mais` usa chave `daily-routine-feeling-more`. O diálogo adicional
usa `CoeloAdminDialogShell`, quatro opções no corpo, `Fechar` como ação secundária
e `Sugerir sentimento` como ação primária. Escolher uma opção retorna o valor e
fecha o diálogo. `Limpar sentimento` aparece somente quando `value != null`.

O diálogo de sugestão usa:

```dart
CoeloAdminDialogShell(
  title: 'Sugerir sentimento',
  body: CoeloFormTextField(
    fieldKey: const Key('daily-routine-feeling-suggestion-field'),
    controller: controller,
    labelText: 'Sentimento sugerido',
    prefixIcon: Icons.add_reaction_outlined,
    onChanged: (_) => setState(() {}),
  ),
  secondaryAction: OutlinedButton(
    onPressed: () => Navigator.of(dialogContext).pop(),
    child: const Text('Cancelar'),
  ),
  primaryAction: FilledButton(
    key: const Key('daily-routine-feeling-suggestion-submit'),
    onPressed: controller.text.trim().isEmpty
        ? null
        : () => Navigator.of(dialogContext).pop(controller.text.trim()),
    child: const Text('Enviar sugestão'),
  ),
)
```

Descartar o controller após o fechamento. Não criar componente público nem
alterar `coelo_ui_admin`.

- [ ] **Step 4: Executar o teste e confirmar GREEN**

Run: o mesmo comando do Step 2.

Expected: PASS, sem overflow, exceptions ou warnings.

- [ ] **Step 5: Formatar e revisar o diff da task**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/features/daily_routine/daily_routine_feeling_picker.dart lib/features/daily_routine/daily_routine_feeling_dialogs.dart test/features/daily_routine/daily_routine_feeling_picker_test.dart
git diff -- apps/superadmin/lib/features/daily_routine apps/superadmin/test/features/daily_routine
```

---

### Task 3: Integrar seleção individual, lote, leitura e referências visuais

**Files:**
- Modify: `apps/superadmin/lib/features/daily_routine/daily_routine_pages.dart`
- Modify: `apps/superadmin/test/features/daily_routine/daily_routine_pages_test.dart`
- Create: `apps/superadmin/test/features/daily_routine/daily_routine_golden_test.dart`
- Create: `apps/superadmin/test/features/daily_routine/goldens/daily_routine_editor_light_375.png`
- Create: `apps/superadmin/test/features/daily_routine/goldens/daily_routine_editor_dark_1440.png`

**Interfaces:**
- Consumes: `DailyRoutineFeelingPicker`, operações do repositório/controller e `showSuperadminNotice`.
- Produces: editor operacional com seleção por participante e seleção separada para lote.

- [ ] **Step 1: Escrever testes de integração que falham**

Adicionar testes com chaves estáveis para provar:

```dart
expect(find.text('Como chegou? (opcional)'), findsWidgets);
expect(find.text('Não informado'), findsWidgets);
expect(find.text('Tranquilo'), findsNothing);
```

Depois:

- selecionar `Triste` para `participant-2` por `Ver mais` e confirmar
  `repository.participantFeeling('participant-2') == DailyRoutineFeeling.sad`;
- limpar e confirmar ausência da chave `mood`;
- escolher `Animado` no seletor de lote, aplicar e preservar a exceção existente;
- confirmar que `Aplicar em lote` fica desabilitado sem sentimento escolhido;
- enviar `Curioso`, verificar uma sugestão pendente, confirmação visual e
  ausência de `Curioso` entre as opções;
- montar com `readOnly`, verificar valores visíveis e nenhuma ação mutável.

- [ ] **Step 2: Executar testes e confirmar RED**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/daily_routine/daily_routine_pages_test.dart
```

Expected: FAIL porque o editor atual só mostra texto, aplica `Tranquilo` e não
possui seletor de lote.

- [ ] **Step 3: Implementar a integração mínima**

No estado do editor, adicionar `DailyRoutineFeeling? _bulkFeeling`. Substituir o
valor fixo de `_applyBulk` por `_bulkFeeling!.id` e bloquear o botão quando
`_selected.isEmpty || _bulkFeeling == null || !permissions.canManage`.

Cada participante deve exibir:

```dart
DailyRoutineFeelingPicker(
  value: widget.repository.participantFeeling(entry.key),
  enabled: widget.permissions.canManage,
  onChanged: (feeling) {
    if (feeling == null) {
      widget.repository.clearParticipantFeeling(entry.key);
    } else {
      widget.repository.setParticipantFeeling(entry.key, feeling);
    }
    setState(() {});
  },
  onSuggestFeeling: _suggestFeeling,
)
```

O fluxo `_suggestFeeling` chama o diálogo, salva somente o texto aprovado no
repositório e usa `showSuperadminNotice(context, 'Sugestão enviada para avaliação.')`.
O texto `Não informado` é derivado de `participantFeeling == null`; nunca é
gravado. Desabilitar checkboxes e ações auxiliares para read-only.

- [ ] **Step 4: Confirmar GREEN dos testes de integração**

Run: o mesmo comando do Step 2.

Expected: PASS.

- [ ] **Step 5: Escrever o golden test e gerar as referências**

O teste deve carregar Nunito Sans e Material Icons como os goldens existentes,
desabilitar animações, usar `devicePixelRatio = 1` e proteger:

```dart
await expectLater(
  find.byKey(const Key('daily-routine-editor-golden-root')),
  matchesGoldenFile('goldens/daily_routine_editor_light_375.png'),
);

await expectLater(
  find.byKey(const Key('daily-routine-editor-golden-root')),
  matchesGoldenFile('goldens/daily_routine_editor_dark_1440.png'),
);
```

Gerar:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test --update-goldens test/features/daily_routine/daily_routine_golden_test.dart
```

Inspecionar visualmente as duas imagens; não usar arquivos `failures/` como
baseline.

- [ ] **Step 6: Executar golden e matriz responsiva**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/daily_routine/daily_routine_golden_test.dart test/features/prototype_responsive_matrix_test.dart
```

Expected: PASS em mobile light, desktop dark e matriz existente.

- [ ] **Step 7: Formatar e revisar o diff da task**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/features/daily_routine/daily_routine_pages.dart test/features/daily_routine/daily_routine_pages_test.dart test/features/daily_routine/daily_routine_golden_test.dart
git diff -- apps/superadmin/lib/features/daily_routine apps/superadmin/test/features/daily_routine
```

---

### Task 4: Atualizar fonte canônica, memória e executar gates finais

**Files:**
- Modify: `specs/021-superadmin-daily-routine-prototype.md`
- Modify: `docs/knowledge/team/superadmin-daily-routine-prototype.md`

**Interfaces:**
- Consumes: comportamento aprovado e verificado nas Tasks 1–3.
- Produces: regra durável pesquisável, sem PII e sem conceder autorização.

- [ ] **Step 1: Atualizar a spec canônica primeiro**

Acrescentar ao escopo, estados, critérios e testes que `Como chegou?` é opcional,
possui cinco sentimentos principais e quatro adicionais, permite limpar, usa
emoji + texto, preserva exceções no lote e mantém sugestões pendentes separadas
do catálogo e dos participantes.

- [ ] **Step 2: Atualizar a projeção interna de conhecimento**

Acrescentar um parágrafo conciso em
`docs/knowledge/team/superadmin-daily-routine-prototype.md` com a mesma regra,
mantendo `source: specs/021-superadmin-daily-routine-prototype.md`, sem nomes de
participantes, tenants ou conteúdo de sugestões.

- [ ] **Step 3: Validar memória**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1 -Root C:\Users\adrie\Documents\Coelo
powershell -NoProfile -ExecutionPolicy Bypass -File .agents/skills/coelo-knowledge/tests/Test-CoeloKnowledge.ps1 -Root C:\Users\adrie\Documents\Coelo
```

Expected: ambos terminam com exit code 0.

- [ ] **Step 4: Executar formatação, análise, testes e validador visual**

Em `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/features/daily_routine test/features/daily_routine
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart analyze
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/daily_routine test/features/prototype_responsive_matrix_test.dart test/app/router/daily_routine_routes_test.dart
```

Em `apps/catalog`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_admin_visual_contracts.dart ..\.. assets/admin-visual-contract-allowlist.json
```

Expected: análise sem issues, todos os testes passam e o validador retorna exit
code 0 sem ampliar allowlist.

- [ ] **Step 5: Revisar escopo e estado do repositório**

```powershell
git diff --check
git status --short
git diff -- apps/superadmin/lib/features/daily_routine apps/superadmin/test/features/daily_routine specs/021-superadmin-daily-routine-prototype.md docs/knowledge/team/superadmin-daily-routine-prototype.md
```

Confirmar que nenhuma alteração paralela foi modificada ou incluída por engano.

- [ ] **Step 6: Commitar somente os arquivos da entrega após todos os gates**

```powershell
git add apps/superadmin/lib/features/daily_routine apps/superadmin/test/features/daily_routine specs/021-superadmin-daily-routine-prototype.md docs/knowledge/team/superadmin-daily-routine-prototype.md docs/superpowers/plans/2026-08-03-superadmin-daily-routine-feelings.md
git commit -m "feat(superadmin): add optional routine feelings"
```

Antes do commit, conferir `git diff --cached --name-only`; nenhum arquivo fora
dessa lista pode permanecer staged.
