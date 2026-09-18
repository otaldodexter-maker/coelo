---
source: "Spec Forms 2026-08-13:131,180; reserva explícita do Coordenador para ramo yesNo em 2026-09-07"
status: "implemented-local-visual-gate-open"
generated_at: "2026-09-07"
---

# Forms yes-no branch round-trip Implementation Plan

Execução das Tasks 1–3 registrada em
`docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-07-editor-yes-no-branch-roundtrip.md`.
Os checkboxes abaixo preservam o roteiro original; implementação e revisão
locais realizadas. Integração produtiva e cinco diferenças golden permanecem
abertas, não fazem parte de uma alegação de E2E.

> **For agentic workers:** execução inline com executing-plans; Owner exige Root
> como único writer e subagentes somente read-only para revisão.

**Goal:** Persistir e reidratar o ramo visual Se Sim sem perder filhos, condições ou IDs.

**Architecture:** Modelo de edição em árvore para condições simples yesNo=true
na mesma seção; contrato de domínio continua grafo plano com posições contíguas.
Cards e campos canônicos existentes renderizam filhos; um ID expandido continua
controlado pelo editor. Condições não representáveis permanecem intactas.

**Tech Stack:** Flutter/Dart, flutter_test, FormsApi/FormDefinition existentes.

## Global Constraints

- Somente editor/testes locais Superadmin; nenhum SQL, shared helper ou gateway.
- Não selecionar opção choice por inferência; não serializar ramo sem gatilho.
- Não combinar condições de ancestrais como OR; filho mantém condição direta.
- Não remover condições/filhos ao esconder controles; sair do ramo é explícito.
- Não chamar persistência local de E2E; reviewer independente e regressão antes commit.

## Task 1: RED de criação, identidade, cópia e reidratação

**Files:** `apps/superadmin/test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart`.
**Interfaces:** `_EditorApi`, `_app`, `FormCommand<FormDefinition>` existentes;
fixture de reload recebe a definição salva e retorna-a em `getEditor`.

- [ ] Criar testes pelo toggle `Desdobrar por resposta` e botão `Adicionar pergunta ao ramo`.
- [ ] Salvar e verificar a estrutura real, não campos privados do widget:

```dart
final items = api.savedCommands.single.payload.sections.first.items;
expect(items, hasLength(2));
expect(items[1].conditions.single.sourceItemId, items[0].id);
expect(items[1].conditions.single.expectedYesNo, isTrue);
expect(items.map((item) => item.position), [0, 1]);
```

- [ ] Acrescentar remover/adicionar, copiar pai/seção, reorder do pai com filho,
  toggle sem perda e reload seguido de segundo save com os mesmos IDs/condições.
- [ ] Provar que filho reidratado continua editável no card canônico; condições
  choice/yesNo=false/múltiplas permanecem preservadas.
- [ ] Executar e observar RED:

```powershell
rtk proxy flutter test --no-pub --reporter expanded test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart --plain-name "yes-no branch"
```

Esperado antes da correção: filho ausente do payload ou da hierarquia carregada.

## Task 2: árvore local e mapper plano

**Files:** `apps/superadmin/lib/features/forms/presentation/editor/forms_editor_page.dart`.
**Interfaces:** `_EditorQuestionDraft.branchQuestions` já existe;
`_localDefinition()` continua retornando `FormDefinition`.

- [ ] Extrair o mapper atual sem mudar metadados/configuração/opções para
  `_itemDefinition(_EditorQuestionDraft question, int position)`.
- [ ] Achatar a árvore apenas para yesNo e sempre preservar filhos existentes:

```dart
Iterable<_EditorQuestionDraft> _flattenQuestions(
  Iterable<_EditorQuestionDraft> questions,
) sync* {
  for (final question in questions) {
    yield question;
    if (question.kind == FormItemKind.yesNo) {
      yield* _flattenQuestions(question.branchQuestions);
    }
  }
}
```

- [ ] Para cada seção, converter `_flattenQuestions(section.questions).toList()`
  em itens com índice global da seção como position.
- [ ] Ao criar filho, usar UUID já disponível e condição direta:

```dart
final child = _EditorQuestionDraft(
  id: _newRequestId(),
  kind: FormItemKind.shortText,
  label: 'Pergunta do ramo ${parent.branchQuestions.length + 1}',
  required: false,
  loadedConditions: [FormCondition.yesNo(sourceItemId: parent.id, expected: true)],
);
parent.branchQuestions.add(child);
```

- [ ] Hidratar na ordem original com pilha de ancestrais contíguos: conectar só
  item com uma condição yesNo=true cujo pai yesNo está nessa pilha. Ao conectar,
  truncar a pilha depois do pai e empilhar filho; caso contrário iniciar nova
  raiz e pilha. Fonte posterior/filho não contíguo permanece plano; nunca mover
  itens por um save de título. Não modificar loadedConditions. Testar ambos os
  casos de ordem identificados pela revisão antecipada.
- [ ] Cópia calcula mapa de IDs/opções para toda subárvore antes de recursão;
  remapeia referências internas com esses mapas e conserva referências externas.

## Task 3: UI e verificação

**Files:** mesmo editor, seus testes e evidência em
`docs/reviews/evidence/etapa-2/formularios-cuidado/`.
**Interfaces:** `_QuestionCard`, `_BranchPanel` e `_expandedQuestionId` existentes.

- [ ] Renderizar filhos com `_QuestionCard` reutilizado dentro do painel do pai,
  mantendo o painel visível quando o filho é o item expandido. Usar o mesmo
  `_expandedQuestionId` para não abrir múltiplos editores.
- [ ] Movimento/duplicação/exclusão usam a lista de irmãos real. Filho não ganha
  movimento implícito para fora do ramo; arraste não deve atingir lista ancestral.
- [ ] Notificar a árvore ao adicionar/remover/trocar toggle; controles escondidos
  não removem conteúdo persistível. Não alterar o fluxo choice ainda não definido.
- [ ] Rodar os testes da Task 1 até GREEN, depois as sete suítes de regressão
  Forms já registradas no plano visível; analyzer dos dois arquivos e validator
  administrativo visual. Não atualizar goldens para mascarar diferenças.
- [ ] Solicitar review read-only, corrigir achados com RED e registrar contagens,
  limitações e ausência de SQL. Commit atômico e handoff ao Coordenador.

Self-review: recorte corresponde à reserva yesNo; grafo de domínio e avaliação
OR não são alterados. UI choice, SQL e persistência real ficam fora desta fatia,
mas permanecem no escopo integral. Nenhum recurso remoto ou nome compartilhado
é criado pelo plano.
