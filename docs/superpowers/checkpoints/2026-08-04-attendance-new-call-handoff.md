---
title: "Handoff — refatoração do lançamento de chamada"
source: "Plano aprovado pelo Owner Coelo em 2026-08-04"
status: "completed"
generated_at: "2026-08-04"
updated_at: "2026-08-05"
---

# Handoff — refatoração do lançamento de chamada

## Encerramento

- Data e hora: 2026-08-04 21:10:10 -03:00.
- Estado seguro: unidade de UI de `/attendance/new` implementada, formatada e coberta pelo teste direcionado; nenhuma etapa seguinte foi iniciada.

## Objetivo original

Refatorar somente o lançamento de chamada do Superadmin, separando `Contexto` e `Chamada`, oferecendo entrada genérica ou pré-contextualizada e preservando domínio e persistência existentes. Dashboard, edição e persistência de Rotina Diária permanecem fora do escopo.

## Escopo efetivamente trabalhado

- Tela de criação e tela visual da chamada recém-criada.
- Contexto inicial opcional na rota existente.
- Testes direcionados da superfície de assiduidade.
- Nenhuma alteração intencional em dashboard, edição, permissões, repositório ou arquitetura.

## Decisões de produto e UI/UX a preservar

- O fluxo tem duas etapas: `Contexto` e `Chamada`.
- Instituição compõe uma faixa compacta; não deve virar painel isolado lado a lado.
- A mesma rota aceita acesso genérico ou pré-contextualizado por instituição, unidade, turma ou atividade.
- A data da nova chamada permanece hoje.
- Participantes começam `Sem marcação`; registram-se exceções e depois `Marcar restantes como presentes`, preservando exceções.
- Lista contínua e adaptativa, sem card completo por aluno.
- Aviso familiar é informação, não marcação oficial; confirmação deve ser explícita.
- Rotina Diária é somente interface visual opcional: oculta sem integração, sem persistência; primeiro pendente abre e pendência obrigatória informada pelo chamador bloqueia conclusão.
- A etapa 2 permanece em `/attendance/calls/:id`, preservando API e ciclo do `AttendanceRepository`.
- Preservar componentes/tokens Coelo, Nunito Sans, #D63C00, #3F4549, alvos de 48 px e estados que não dependem só de cor.

## Referências e documentos consultados

- `AGENTS.md` e instruções globais RTK.
- `.agents/skills/coelo-ui/SKILL.md`.
- `.codex/skills/ui-ux-pro-max/SKILL.md`.
- `.agents/skills/ponytail/SKILL.md`.
- `.agents/skills/flutter-build-responsive-layout/SKILL.md`.
- `.agents/skills/rtk/SKILL.md`.
- `.agents/skills/coelo-knowledge/SKILL.md`.
- `docs/design/design-system.md`.
- `specs/020-superadmin-attendance-prototype.md`.
- `docs/knowledge/team/superadmin-attendance-prototype.md`.
- Padrões de Criar/Editar Instituição, `SuperadminFormStepNavigation`, `SuperadminFormActionFooter` e seletores Coelo.
- Referências Arbor de realização e edição em massa preservadas no plano aprovado.

## Arquivos

Criado:

- `docs/superpowers/checkpoints/2026-08-04-attendance-new-call-handoff.md`.

Alterados nesta atividade:

- `apps/superadmin/lib/features/attendance/attendance_pages.dart`.
- `apps/superadmin/lib/app/router/superadmin_router.dart`.
- `apps/superadmin/test/features/attendance/attendance_pages_test.dart`.

O worktree contém muitas alterações paralelas do usuário; não foram limpas, revertidas ou incorporadas intencionalmente.

## Componentes, rotas e superfícies afetadas

- `AttendanceNewCallPage`.
- `AttendanceCallPage`.
- Componentes privados de contexto, lista, ações e detalhes de participante.
- Rota de criação em produção e preview/dev, com query parameters opcionais `institution`, `unit`, `group` e `activity`.

## Concluído

- Contexto alinhado ao padrão responsivo dos formulários administrativos.
- Contexto inicial opcional, sem rota nova.
- Faixa compacta de contexto/fatos responsiva, inclusive 375 px e texto a 200%.
- Chamada como lista contínua com Falta, Atraso, Saída e preenchimento explícito dos restantes.
- Avisos/observações em detalhe expansível.
- Seam visual opcional de Rotina Diária, sem persistência/domínio.
- Rodapé canônico com pendências e bloqueio de conclusão.
- Testes direcionados verdes.

## Parcialmente concluído

- Validador visual global iniciou, mas excedeu cerca de 60 s sob contenção e não produziu resultado.
- QA visual manual completo nas quatro larguras e goldens não foram feitos.

## Ainda não iniciado

- Dashboard gerencial.
- Edição de chamadas.
- Persistência/contrato de domínio da Rotina Diária.
- Mudanças de regra de negócio, permissões ou arquitetura.

## Verificações executadas

- `dart format` nos três arquivos: sucesso.
- `dart analyze lib/features/attendance/attendance_pages.dart`: `No issues found!`.
- `dart analyze test/features/attendance/attendance_pages_test.dart`: `No issues found!` antes do último ajuste de visibilidade; teste Flutter posterior recompilou o arquivo.
- `dart analyze lib/app/router/superadmin_router.dart`: exit 0; oito infos preexistentes de `use_null_aware_elements`, sem erro.
- `flutter test --no-pub test/features/attendance/attendance_pages_test.dart`: exit 0; 8 testes passaram em 71,2 s.
- `git diff --check` nos três arquivos: exit 0; apenas avisos LF/CRLF.
- `dart apps/catalog/tool/validate_admin_visual_contracts.dart`: não concluído; timeout silencioso após cerca de 60 s.

## Erros, avisos, bloqueios e débitos

- Nenhum erro óbvio de sintaxe/referência no escopo direcionado.
- Avisos LF para CRLF em dois arquivos.
- O roteador mantém oito infos externas à alteração.
- Processos Flutter paralelos causaram espera no lock global; nenhum processo alheio foi encerrado.
- A ferramenta de patch travou; escritas exatas foram usadas como contingência e o código foi formatado/validado.
- Rotina Diária ainda recebe widget/conjunto de pendências do chamador, sem contrato persistente.
- A chamada é criada antes da etapa 2 para preservar o ciclo existente.
- Goldens e QA visual manual completo estão pendentes.

## Estado atual do Git

Arquivos desta atividade:

```text
 M apps/superadmin/lib/app/router/superadmin_router.dart
 M apps/superadmin/lib/features/attendance/attendance_pages.dart
 M apps/superadmin/test/features/attendance/attendance_pages_test.dart
?? docs/superpowers/checkpoints/2026-08-04-attendance-new-call-handoff.md
```

Há diversos outros arquivos/checkpoints paralelos no worktree e eles devem ser preservados.

## Resumo do Git diff

Antes deste handoff, o recorte dos três arquivos mostrou:

```text
3 files changed, 1410 insertions(+), 367 deletions(-)
```

O total inclui alterações preexistentes, especialmente no roteador; não representa autoria exclusiva desta atividade.

## Próximo passo exato

Reabrir `apps/superadmin/lib/features/attendance/attendance_pages.dart` em `AttendanceNewCallPage` e `_AttendanceCallPageState`, conferir o diff contra este handoff e repetir o teste direcionado. Com ele verde, repetir o validador visual sem contenção e inspecionar 375, 768, 1024 e 1440 antes de qualquer ajuste.

Primeiro arquivo: `apps/superadmin/lib/features/attendance/attendance_pages.dart`.

## Comandos de retomada

Em `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/features/attendance/attendance_pages.dart lib/app/router/superadmin_router.dart test/features/attendance/attendance_pages_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib/features/attendance/attendance_pages.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test/features/attendance/attendance_pages_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test --no-pub test/features/attendance/attendance_pages_test.dart
```

Na raiz:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe apps/catalog/tool/validate_admin_visual_contracts.dart
git diff --check -- apps/superadmin/lib/features/attendance/attendance_pages.dart apps/superadmin/lib/app/router/superadmin_router.dart apps/superadmin/test/features/attendance/attendance_pages_test.dart
```

## Critérios da próxima etapa

- Os 8 testes permanecem verdes.
- Validador visual sem violação atribuível à tela.
- Sem overflow/perda de ação em 375, 768, 1024 e 1440, inclusive texto a 200%.
- Nenhuma mudança em dashboard, edição, domínio ou persistência.

## Gate de memória Coelo

Nenhuma fonte canônica/projeção foi atualizada: esta etapa implementa o plano aprovado sem criar nova regra durável. Este checkpoint preserva somente a continuidade operacional.

## Retomada e conclusão em 2026-08-05

- Handoff, `git status`, diffs direcionados, implementação, testes, spec e projeção de conhecimento foram reabertos antes de qualquer edição.
- O índice Coelo UI confirmou Criar/Editar Instituição, `SuperadminFormStepNavigation` e `SuperadminFormActionFooter` como padrões aplicáveis.
- Foi criado `apps/superadmin/test/features/attendance/attendance_pages_golden_test.dart`.
- Foram geradas as referências `attendance_new_call_context_light_375.png` e `attendance_new_call_marking_dark_1440.png`.
- A suíte final exclusiva de Assiduidade passou com 9 testes: 8 funcionais e 1 teste golden cobrindo duas imagens.
- A formatação dos quatro arquivos Dart terminou sem mudanças e `git diff --check` terminou sem erros.
- O gate visual oficial foi executado com os argumentos corretos. Ele não apontou Assiduidade, mas o processo global retornou exit 1 por oito ocorrências externas em Chat, Imports, Notices e Support; nenhuma foi alterada ou adicionada à allowlist.
- O navegador/localhost foi dispensado por orientação do Owner. A evidência visual ficou registrada pelos goldens do Flutter.
- Gate de memória: `no-op`; nenhuma nova regra durável foi introduzida além da spec já aprovada.

## Aceite visual em 2026-08-05

- O Owner Coelo aprovou explicitamente os goldens de Assiduidade.
- Para mobile e tablet no tema claro, a base permanece simples e branca por `colorScheme.surface`; cinza claro fica reservado a superfícies secundárias com função explícita.
- Instagram e Airbnb são referências conceituais de limpeza e hierarquia por conteúdo e espaço, sem copiar identidade, componentes ou navegação.
- A auditoria confirmou conformidade da tela: `surfaceContainerLowest` do shell resolve para `CoeloPalette.neutral0`, igual à superfície branca no tema claro; nenhum ajuste adicional foi necessário.

## Fechamento final solicitado em 2026-08-05

- O escopo final permanece exclusivamente `Assiduidade > Lançamento de chamada`; dashboard, edição e persistência da Rotina Diária não foram incorporados.
- A suíte completa de `test/features/attendance` passou com 17 testes, cobrindo repositório, permissões, notificação, tela, marcações, responsividade e duas referências golden.
- `attendance_pages.dart` e todo o diretório de testes da feature foram analisados sem issues.
- Foi tentada cobertura adicional da rota contextual real. O teste não chegou a executar porque o roteador global está bloqueado por erro externo em `fake_notice_repository.dart`; nenhum arquivo externo foi corrigido.
- O teste adicional não validado foi removido e `attendance_routes_test.dart` retornou exatamente ao estado anterior, confirmado por `git diff --exit-code`.
- O mapeamento contextual permanece implementado no roteador e os valores pré-preenchidos continuam cobertos diretamente na página.
- O aceite visual do Owner permanece registrado. Não há alteração adicional necessária na tela de Lançamento de chamada.
