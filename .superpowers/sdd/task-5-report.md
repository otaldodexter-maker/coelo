---
source: "docs/superpowers/plans/2026-07-27-superadmin-chat-adjustments.md; docs/superpowers/specs/2026-07-27-superadmin-chat-adjustments-design.md"
status: "completed"
generated_at: "2026-07-28"
---

# Task 5 — Relatório

## Status

A seleção e o envio em massa local foram implementados nos quatro arquivos
previstos. O picker permanece privado à feature do Superadmin e a confirmação
acrescenta somente uma conversa simulada à lista em memória.

Não foram criados repository, ViewModel, backend, auditoria persistida, API de
pacote ou promoção do padrão institucional de chat. A modificação preexistente
em `task-1-report.md` foi preservada e permanece fora do commit seletivo.

## Escopo implementado

- `SuperadminChatRecipientPicker` consome `CoeloAdminContextOption` e apresenta
  a hierarquia local com `CheckboxListTile`.
- Um `Set<String>` local mantém seleção individual e `Selecionar todos`.
- A quantidade distingue singular e plural e permanece visível antes da
  revisão.
- O diálogo de revisão lista os destinatários, informa
  `Demonstração local` e declara que nenhuma mensagem será enviada fora do
  protótipo.
- Cancelar ou fechar a revisão preserva o rascunho e devolve foco a
  `Revisar envio`.
- `Esc` fecha tanto a revisão quanto o diálogo principal e devolve foco à
  origem adequada.
- A confirmação fecha o fluxo, insere uma conversa `bulk-local-N` somente na
  lista em memória e mostra `SnackBar` com
  `Demonstração local · nenhum envio real foi realizado.`
- A inbox e o rail passaram a selecionar a conversa pelo objeto/ID local, sem
  depender do índice da fixture constante. Isso permite abrir a conversa
  simulada sem índice `-1` e também corrige a associação quando filtros
  produzem subconjuntos.

## Contratos de UI

- O picker reutiliza `CoeloAdminContextOption`, tokens Coelo e o comportamento
  de rascunho/seleção do `CoeloAdminMultiSelectFilter`; ele não reutiliza
  diretamente `CoeloAdminContextPicker` porque esse componente é single-select
  com radio e não satisfaz o contrato explícito de múltipla seleção com
  `CheckboxListTile`.
- Os diálogos usam `colorScheme.surface` e
  `surfaceTintColor: Colors.transparent`.
- O fechar canônico usa `Icons.close_rounded`, alvo de 48 px, ícone
  `colorScheme.error`, `errorContainer` em hover/foco e overlay transparente.
- Espaçamentos, alvos, cores e raios usam tokens ou o tema; não foram
  introduzidos HEX, `Color(0x...)` ou `TextStyle` locais.
- O componente permanece local à feature; nenhuma API pública foi criada.

## TDD

### RED principal

Antes de qualquer código de produção, o comando focado falhou porque
`superadmin_chat_recipient_picker.dart` e
`SuperadminChatRecipientPicker` não existiam.

Uma primeira execução também encontrou um `bool?` inválido no próprio teste.
Esse erro de teste foi corrigido e o RED foi repetido até restarem somente as
falhas esperadas pela funcionalidade ausente.

```powershell
flutter test --no-pub test/features/chat/presentation/superadmin_chat_recipient_picker_test.dart test/features/chat/presentation/superadmin_chat_page_test.dart
```

### RED de endurecimento do fechar canônico

Após o fluxo principal ficar verde, dois testes específicos exigiram
`errorContainer` em hover/foco e overlay transparente. Ambos falharam com
`backgroundColor == null`, comprovando a lacuna antes da correção.

### GREEN

Os comandos focados finais executaram **29 testes, 0 falhas**: 5 do picker,
20 da página e 4 dos filtros de escopo. A cobertura inclui:

- seleção individual;
- seleção total dos quatro destinatários;
- quantidade e ordem hierárquica;
- cancelamento e confirmação da revisão;
- conversa e `SnackBar` de demonstração local;
- abertura da conversa adicionada em memória;
- foco e `Esc` nos dois níveis de modal;
- superfície/tint e fechar canônico;
- light/dark e texto a 200%;
- matriz preexistente de 375, 768, 1024 e 1440 px das Tasks 1–4.

### Correção após revisão

A revisão identificou três lacunas concretas e elas foram tratadas com novo
ciclo RED/GREEN:

- o resultado do picker agora usa `SuperadminChatRecipientSelection` e preserva
  todo o caminho de `CoeloAdminContextOption`, incluindo IDs, labels, kinds e
  subtítulos;
- a revisão mostra o caminho completo. Para Natação:
  `Centro Horizonte / Unidade Cambuí / Turma Girassol / Natação`;
- uma seleção única deriva estado, instituição, unidade, grupo, atividade e
  `targetKind` do caminho selecionado;
- uma seleção múltipla usa o ancestral comum mais profundo, de forma
  determinística. Os quatro destinatários atuais produzem o contexto da
  instituição `Centro Horizonte`, no estado `CE`;
- `child` e `personRole` permanecem vazios porque não existem esses tipos no
  caminho atual; nenhum dado foi inventado;
- a conversa criada permanece visível sob filtros ancestrais compatíveis;
- a conversa local carrega sua própria mensagem inicial, marcada somente como
  demonstração local, sem Marina, sem conteúdo herdado de Turma Girassol e sem
  estado fictício de entrega/leitura;
- novas mensagens digitadas nessa conversa também permanecem locais, não
  recebem confirmação de entrega e não disparam a resposta automática da
  Marina.

O RED do picker falhou pela ausência do novo tipo e do caminho completo. O RED
do thread local falhou com três bolhas, pois a resposta automática da Marina
ainda era criada. Depois da implementação, os testes validam a hierarquia de
Natação, a mensagem inicial local, a ausência de Marina/Girassol e de
read/delivery, o composer local e a compatibilidade com todos os filtros
ancestrais.

## Verificação

- `dart format` nos quatro arquivos Dart afetados: concluído.
- `dart analyze` em `apps/superadmin`: `No issues found!` antes do
  endurecimento final; a análise focada dos seis arquivos corrigidos também
  terminou com `No issues found!` depois dele.
- `git diff --check`: sem erros antes do relatório.
- Busca por HEX, `Color(0x...)`, `TextStyle` local, orientação e tipo de
  dispositivo: nenhuma ocorrência nos arquivos de produção afetados.
- Gate de conhecimento: `PASS: base de conhecimento válida`.
- Testes da memória Coelo: `PASS: validação, consulta e cenários`.
- O índice Coelo UI foi consultado em modo somente leitura e não retornou
  entrada específica. A skill instalada não fornece `validate-index.ps1`;
  somente `query-index.ps1` está disponível.

A suíte ampliada `flutter test --no-pub test/features/chat/presentation`
executou **30 testes verdes**, mas terminou com **12 falhas de goldens
preexistentes/desatualizados**. As diferenças incluem todos os tamanhos da
página e os três goldens do launcher, embora a Task 5 não altere o launcher.
Nenhum baseline foi atualizado silenciosamente e os artefatos temporários em
`failures/` foram removidos.

## Memória Coelo

A consulta inicial não encontrou projeção relevante. O comportamento já está
aprovado na spec canônica e esta tarefa não criou conhecimento durável novo
para outra audiência. Gate de memória: **no-op**.

## Self-review

- Seleção e mensagens são locais e desaparecem ao recriar a página.
- Nenhuma indicação afirma envio, auditoria ou notificação real.
- Cancelar a revisão não chama `onConfirmed`; `Esc` no diálogo principal não
  cria conversa.
- A confirmação preserva a conversa anteriormente selecionada até o usuário
  abrir explicitamente o item local.
- A conversa simulada mantém duas métricas para continuar compatível com o
  painel contextual da Task 4.
- O picker não foi promovido, e a Task 6 permanece não implementada.
- `task-1-report.md` não foi alterado nesta tarefa e será excluído do commit.
- A Task 6 continua intocada.

## Preocupações

1. Os goldens de chat já divergem amplamente do estado atual das Tasks
   anteriores. Eles exigem revisão visual e atualização deliberada em tarefa
   própria; atualizar agora ampliaria o escopo e mascararia mudanças não
   pertencentes à Task 5.
2. A pesquisa de pessoa continua sendo uma representação visual separada e
   não participa do envio em massa, pois não existe autorização, auditoria ou
   fonte de dados real nesta etapa.
3. O texto `Acesso auditado` permanece apenas no fluxo preexistente de pesquisa
   de pessoa; nenhuma trilha real foi adicionada.
