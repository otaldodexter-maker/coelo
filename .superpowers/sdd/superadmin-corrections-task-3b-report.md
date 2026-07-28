---
source: ".superpowers/sdd/superadmin-corrections-task-3b-brief.md"
status: "implemented"
generated_at: "2026-07-28"
---

# Task 3B — representantes legais e administradores

## Resultado

- `Responsável inicial` foi substituído por `Representantes legais`.
- Criação exige ao menos um representante; edição aceita zero.
- Representantes podem ser adicionados, editados e removidos em memória.
- A etapa `Administradores` oferece representantes ainda não vinculados,
  pré-selecionados, mas somente cria o `Admin Master` após confirmação explícita.
- Outros administradores podem ser adicionados e editados com os níveis locais
  coerentes com a documentação: `Admin Master`, `Administrador autorizado` e
  `Coordenador`.
- `Enviar convite` é local, muda o estado para `Enviado` e acrescenta evento ao
  histórico. A partir de `Enviado`, o operador pode simular `Aceito` ou
  `Expirado`; cada transição registra status e data/hora. Nenhum e-mail ou
  chamada externa é executado.
- Editar um representante sincroniza o administrador derivado; removê-lo também
  remove esse administrador para não deixar uma origem inexistente.
- A revisão lista nomes de representantes e nomes, papéis e status de
  administradores.
- A persistência legada de `InstitutionRecord` continua recebendo o primeiro
  representante nos campos `owner*`; listas e convites permanecem somente no
  controller desta rodada, conforme a restrição de não tocar banco.

## Coelo UI

O índice Coelo UI foi consultado para formulário, representantes,
administradores, convite e cards, sem resultados. Foram aplicados o contrato de
formulários e o contrato de superfícies: componentes de campo e single-select
compartilhados, tokens de grid/espaçamento, cards e diálogos em `surface`, sem
fundo estrutural laranja ou cinza.

## TDD

RED observado em
`institution_form_controller_test.dart`: enum, modelos, coleção de pessoas,
confirmação e histórico ainda não existiam.

GREEN:

- 16 testes do controller passaram.
- O teste widget focado de confirmação de representante, criação de Admin
  Master, histórico, transições Aceito/Expirado e revisão nominal passou.
- O teste widget focado do diálogo passou: obrigatoriedade associada aos campos
  depois da tentativa e ações com mesma largura no layout compacto.

A suíte combinada executou 38 testes com sucesso antes de cinco falhas de
expectativas antigas decorrentes da nova sétima etapa e de um finder de card.
Essas expectativas foram corrigidas, mas, por solicitação de encerramento no
checkpoint, a suíte completa não foi reexecutada depois desse último ajuste.

O coordenador repetiu o gate após o checkpoint, corrigiu o isolamento entre
larguras do teste responsivo com uma `ValueKey` e atualizou a quantidade de
avanços até Plano. Resultado final: **43/43 testes GREEN**, incluindo 375, 768,
1024 e 1440 px.

Análise estática focada nos quatro arquivos afetados: `No issues found`.

## Arquivos e concorrência

- Exclusivos desta tarefa:
  - `apps/superadmin/lib/features/institutions/presentation/view_models/institution_form_controller.dart`
  - `apps/superadmin/test/features/institutions/presentation/view_models/institution_form_controller_test.dart`
  - `apps/superadmin/test/features/institutions/presentation/screens/institution_form_page_test.dart`
- Misto, com alterações anteriores da Task 3A preservadas:
  - `apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart`

Não foram alterados `institution_record.dart`, repositório fake, dialogs,
Supabase, Support, menu, catálogo, docs canônicas, skills, goldens ou failures.
Nenhum preview foi gerado.

## Pendências

- A persistência normalizada das listas e do histórico continua reservada à
  Task 3C; nesta rodada, o `InstitutionRecord` legado recebe somente o primeiro
  representante e limpa corretamente `owner*` quando a edição remove todos.
- A memória Coelo foi `no-op`: nenhuma fonte canônica deve ser atualizada antes
  da aprovação visual final.
