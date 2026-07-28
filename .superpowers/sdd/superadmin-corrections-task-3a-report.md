---
source: ".superpowers/sdd/superadmin-corrections-task-3a-brief.md"
status: "implemented-with-concerns"
generated_at: "2026-07-28"
---

# Task 3A — Formulário de Instituição

## Estado

`DONE_WITH_CONCERNS`

O formulário local/fake foi ampliado sem tocar Supabase, representantes,
administradores, Support, menu, catálogo, documentação de UX ou skills.

## Entregue

- criação continua em wizard e salva somente na Revisão;
- edição oferece `Salvar alterações` na etapa atual, persiste no fake local,
  permanece na etapa e redefine o estado dirty;
- foto de capa local com preview, limite de 2 MB e validação de imagem legível;
- paleta com três cores de marca, três cores de texto e cor de superfície;
- bio limitada a 220 caracteres com contador;
- três pares fixos de rótulo/URL, com validação de par e URL HTTP(S);
- `Endereço` separado de `Contato básico`, na ordem aprovada;
- CEP exige exatamente oito dígitos; ViaCEP diferencia formato, inexistente e
  rede, mostra loading e não apaga endereço manual em falha;
- UF e Município usam `CoeloAdminSingleSelectField`; municípios vêm do IBGE e
  a troca de UF limpa o município anterior;
- contato básico inclui e-mail, telefone, WhatsApp e site;
- período de teste sugere hoje e hoje + 30 dias e rejeita término anterior;
- calendário pt-BR com superfície `colorScheme.surface`, tint transparente e
  borda/paleta Coelo;
- insets do formulário acompanham Instituições em 16/24/40 px por breakpoint;
- menu do single-select mantém largura do campo e offset vertical `space1`.

## RED → GREEN observado

1. Trial preservava a data fixa antiga e aceitava término anterior; 2 REDs,
   depois 6 testes do controller GREEN.
2. Capa/paleta/bio/links, grupos de endereço/contato e save-in-place não
   existiam; 3 REDs widgets, depois GREEN.
3. O serviço ViaCEP/IBGE não existia; RED de compilação da API desejada, depois
   4 testes GREEN para formato/mapeamento, CEP inexistente, rede e municípios.
4. A página não aceitava serviço injetável e não tinha loading/erros; RED de
   integração, depois widgets GREEN.
5. O calendário não tinha chave, pt-BR ou tema explícito; RED, depois GREEN.
6. O menu tinha offset zero; RED `Offset(0, 0)` versus `space1`, depois GREEN.

## Verificação

- `flutter test` focado em service/controller/page: **29 passed**.
- `coelo_ui_admin` single-select: **1 passed**.
- análise focada via Dart MCP, app e package: **No errors**.
- `git diff --check`: **pass**.
- `Test-CoeloKnowledge.ps1` da skill: **PASS**.
- arquivos tocados foram formatados.

Não foram executados/atualizados goldens nem gerados candidatos visuais por
orientação final do coordenador e pelo checkout compartilhado com shell/router
em mutação concorrente.

O segundo comando de memória inicialmente citado como
`tests/Test-CoeloKnowledge.ps1` não existe na raiz; o arquivo real foi
localizado em `.agents/skills/coelo-knowledge/tests/`, mas não foi reexecutado
após a ordem de interromper testes. A memória ficou em `no-op`: a tarefa proíbe
alterar docs/skills e nenhuma fonte canônica foi atualizada.

## Arquivos da Task 3A

- `apps/superadmin/lib/features/institutions/data/institution_location_service.dart`
- `apps/superadmin/lib/features/institutions/domain/institution_record.dart`
  (somente `InstitutionProfileLink` e extensões de `InstitutionRecord`)
- `apps/superadmin/lib/features/institutions/presentation/screens/institution_form_page.dart`
- `apps/superadmin/lib/features/institutions/presentation/view_models/institution_form_controller.dart`
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart`
- `apps/superadmin/lib/app/superadmin_app.dart` (somente localização pt-BR)
- `apps/superadmin/pubspec.yaml` e `pubspec.lock` (somente
  `flutter_localizations`/`intl`)
- testes correspondentes em `apps/superadmin/test/features/institutions/`
- `packages/coelo_ui_admin/lib/src/filter/coelo_admin_single_select_field.dart`
- `packages/coelo_ui_admin/test/filter/coelo_admin_single_select_field_test.dart`

## Stage sem capturar trabalho concorrente

Arquivos exclusivos, seguros para stage integral:

```powershell
git add -- `
  .superpowers/sdd/superadmin-corrections-task-3a-report.md `
  apps/superadmin/lib/features/institutions/data/institution_location_service.dart `
  apps/superadmin/lib/features/institutions/presentation/screens/institution_form_page.dart `
  apps/superadmin/lib/features/institutions/presentation/view_models/institution_form_controller.dart `
  apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart `
  apps/superadmin/test/features/institutions/data/institution_location_service_test.dart `
  apps/superadmin/test/features/institutions/presentation/screens/institution_form_page_test.dart `
  apps/superadmin/test/features/institutions/presentation/view_models/institution_form_controller_test.dart `
  packages/coelo_ui_admin/lib/src/filter/coelo_admin_single_select_field.dart `
  packages/coelo_ui_admin/test/filter/coelo_admin_single_select_field_test.dart
```

Arquivos mistos exigem `git add -p` com edição do hunk:

- `institution_record.dart`: incluir apenas `InstitutionProfileLink` e campos,
  parâmetros e cópia de `InstitutionRecord`; excluir import de `UnitStatus` e
  toda extensão de `InstitutionUnit`;
- `superadmin_app.dart`: incluir apenas import de `flutter_localizations` e
  `locale`/`supportedLocales`/`localizationsDelegates`; excluir preferências de
  conta, tema e reduced motion;
- `pubspec.yaml`: incluir apenas `flutter_localizations`; excluir
  `file_picker` e `shared_preferences`;
- `pubspec.lock`: incluir apenas entradas `flutter_localizations` e `intl`;
  excluir `file_picker`, `cross_file`, `dbus`,
  `flutter_plugin_android_lifecycle`, `win32` e a mudança de
  `shared_preferences`.

Não incluir `failures/`, router, shell, account, units, fake repository,
`institution_form_dialogs.dart`, catálogo, docs ou skills.

## Concern remanescente

A matriz responsiva/widget passou, mas a alteração visual ampla ainda precisa de
QA visual/golden candidato em mobile light e desktop dark quando o checkout
concorrente estabilizar. Nenhum golden aprovado foi alterado.

## Fix review 1 — 2026-07-28

### Estado

`DONE_WITH_CONCERNS`

O review foi corrigido sem tocar 3B, Supabase, menu, Support, docs de produto ou
skills. O checkout continuou compartilhado com alterações concorrentes de
Units, Account, shell/router e arquivos de falha visual; esses arquivos foram
preservados.

### Correções entregues

- o select administrativo compartilhado continua retrocompatível e agora
  aceita `errorText`, `enabled`, `isLoading`, mensagem semântica e busca
  automática quando há mais de oito opções;
- o popup do select preserva superfície administrativa, largura do gatilho,
  offset `space1`, seleção contínua sem check e navegação por teclado/foco;
- CEP é validado pelo controller com `^\d{8}$` em qualquer validação, inclusive
  sem consulta; a entrada do formulário remove caracteres não numéricos e
  limita a oito dígitos;
- CEPs legados com máscara são normalizados ao abrir a edição;
- a entrada na etapa de localização carrega municípios do IBGE quando já existe
  UF;
- toda nova consulta municipal limpa opções incompatíveis, desabilita o select
  e mostra loading no próprio campo;
- cada resposta do IBGE é correlacionada por UF e versão incremental; respostas
  tardias não substituem o estado atual;
- falha do IBGE mantém o município atual legível, associa o erro ao select e
  oferece `Tentar novamente` para a mesma UF;
- o serviço de localização valida o shape JSON sem deixar `TypeError` escapar,
  tem timeout injetável de oito segundos e converte HTTP, parse, timeout e rede
  para o estado de erro controlado;
- na edição há uma única ação primária: `Salvar alterações` é Filled e
  `Continuar` é Outlined; no desktop Salvar fica à direita e no compacto fica
  primeiro. Criação e ação final da Revisão foram preservadas;
- a cobertura de regressão inclui erro de rede ViaCEP real, CEP inválido no
  save, bio 220/221, par/URL/persistência dos links, corrida SP→RJ, retry da
  mesma UF, limpeza da lista e hierarquia do footer;
- o teste responsivo passou a percorrer Identidade visual, Localização e Plano
  em 375, 768, 1024 e 1440 px.

### RED → GREEN observado

1. A API desejada do select não compilava (`errorText`, `enabled`,
   `isLoading`); depois, **5 testes GREEN** cobriram legado, erro, loading,
   busca em 27 opções e teclado/foco.
2. CEP com três dígitos era aceito pelo controller; depois, controller + service
   somaram **15 testes GREEN**, incluindo CEP, bio, links, JSON malformado e
   timeout.
3. A entrada em Localização fazia zero requests de IBGE para UF existente; após
   a correção, init, retry, stale response e lista incompatível ficaram GREEN.
4. O footer de edição expunha duas ações Filled; após a correção, edição
   desktop/compacta e criação ficaram GREEN.

### Verificação do fix

- página do formulário completa: **27 testes GREEN**;
- bloco novo crítico da página (IBGE, ViaCEP, CEP/save e footer):
  **8 testes GREEN**;
- controller + service: **15 testes GREEN**;
- select compartilhado: **5 testes GREEN**;
- análise focada do app: **No issues found**;
- análise focada de `coelo_ui_admin`: **No issues found**;
- os nove arquivos Dart do fix foram formatados.

A repetição final isolada do teste da matriz responsiva ampliada foi
interrompida por orientação do coordenador para encerrar testes e finalizar o
relatório; não houve falha observada. O arquivo completo já havia passado antes
da ampliação mecânica da matriz, e a análise posterior ficou limpa.

Não foram gerados candidatos visuais porque a orientação final foi parar testes
adicionais. Os goldens aprovados e todos os PNGs rastreados em `failures/`
permaneceram intocados.

Não foi criado teste binário novo da capa: o picker atual usa função top-level
condicional sem seam injetável para simular bytes/codec no widget test. A
validação existente de tamanho máximo e imagem decodificável foi preservada,
sem ampliar API pública apenas para teste.

A memória de conhecimento permaneceu `no-op`: nenhuma regra canônica aprovada
mudou, e o escopo proíbe alterações em docs/skills.

### Arquivos exclusivos do Fix review 1

```powershell
git add -- `
  .superpowers/sdd/superadmin-corrections-task-3a-report.md `
  apps/superadmin/lib/features/institutions/data/institution_location_service.dart `
  apps/superadmin/lib/features/institutions/presentation/screens/institution_form_page.dart `
  apps/superadmin/lib/features/institutions/presentation/view_models/institution_form_controller.dart `
  apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart `
  apps/superadmin/test/features/institutions/data/institution_location_service_test.dart `
  apps/superadmin/test/features/institutions/presentation/screens/institution_form_page_test.dart `
  apps/superadmin/test/features/institutions/presentation/view_models/institution_form_controller_test.dart `
  packages/coelo_ui_admin/lib/src/filter/coelo_admin_single_select_field.dart `
  packages/coelo_ui_admin/test/filter/coelo_admin_single_select_field_test.dart
```

Não incluir fake repository, `institution_record.dart`,
`institution_form_dialogs.dart`, Units, Account, shell/router, menu, Support,
catálogo, docs, skills ou qualquer diretório `failures/`.

## Fix review 2

Os três achados restantes da revisão foram tratados com TDD:

- UF e Município agora recebem o erro obrigatório diretamente nos selects,
  inclusive na árvore semântica compartilhada;
- editar o CEP limpa o erro externo anterior e volta a exibir a validação do
  valor atual;
- uma resposta não vazia do IBGE sem nenhum nome de município válido é
  rejeitada como erro controlado.

### Verificação

- testes focados de widget: **2/2 GREEN**;
- teste focado do parser IBGE: **1/1 GREEN**;
- análise dos quatro arquivos afetados: **sem issues**.

O fix não alterou color picker, goldens, catálogo, documentação canônica ou
skills. A memória `coelo-knowledge` permanece `no-op` até aprovação visual.
