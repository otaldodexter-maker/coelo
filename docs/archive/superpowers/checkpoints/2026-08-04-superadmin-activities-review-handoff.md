---
title: "Handoff da revisão de Atividades e padrões Coelo UI"
source: "Plano aprovado de Atividades do Superadmin e solicitação de revisão de 2026-08-04"
status: "paused"
generated_at: "2026-08-04"
updated_at: "2026-08-04"
---

# Handoff da revisão de Atividades e padrões Coelo UI

## Encerramento

- Data e hora: 2026-08-04 21:03:23 -03:00.
- Ponto seguro: revisão somente leitura concluída; nenhuma correção nova, staging,
  commit, branch, push, merge ou servidor local foi iniciado nesta etapa.

## Objetivo original

Revisar a entrega de Atividades/Happens contra o plano aprovado, ajustar a
`coelo-ui` somente se necessário para forçar os padrões, criar um commit seguro
e iniciar um novo localhost sem encerrar instâncias existentes.

## Escopo efetivamente trabalhado

- Auditoria de Diretório e Criar/Editar Atividade no Superadmin.
- Auditoria dos padrões compartilhados de toggle, flyout, tabela, tabs, stepper,
  rodapé e dialogs.
- Conferência da renomeação de produto Flow para Happens.
- Conferência somente leitura de Supabase: o repositório read-only preexistente
  foi localizado, mas não foi alterado nem executado nesta etapa.
- Inspeção do estado do worktree para preparar um commit seletivo futuro.

## Decisões de produto e UI/UX preservadas

- O escopo permanece somente Atividades; não corrigir Grupos ou Unidades nesta
  retomada.
- Não alterar Supabase, migrations, schema, RLS ou persistência.
- Instituições é a baseline de diretórios e formulários; Pessoas é a baseline
  das tabs; Tour é a baseline de flyouts.
- Toggle Cards/Tabela: segmentos imutáveis de 64 x 48 e variações via
  `CoeloAdminFlyout`.
- Tabela administrativa: largura natural centralizada e scrollbar/track acima
  da coluna fixa.
- Status de Atividades: tabs `Todos`, `Ativos`, `Em Implantação`, `Inativos`;
  seleção apenas visual nesta entrega.
- Wizard: quatro etapas, lateral em medium/wide e resumo acessível no compacto.
- Rascunho exige nome, instituição e unidade; conclusão também exige turma.
- Profissionais pertencem à atividade + turma; Happens, Now, Moments e Chat
  iniciam ativos, sem representar autorização efetiva.
- `Happens` substitui `Flow` como nome de produto; usos técnicos genéricos de
  `flow`, `posts` e `post_published` permanecem.

## Referências consultadas

- `.agents/skills/coelo-ui/SKILL.md` e índice `apps/catalog/assets/coelo-ui.index.jsonl`.
- `.agents/skills/coelo-ui/references/surface-interaction-contracts.md`.
- `.agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md`.
- `.agents/skills/coelo-ui/references/directory-linear-tabs-contract.md`.
- `.agents/skills/coelo-ui/references/form-layout-contracts.md`.
- `.agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md`.
- `.agents/skills/coelo-ui/references/rejected-visual-patterns-inbox.md`.
- `.agents/skills/coelo-ui/references/interactive-state-evidence-matrix.md`.
- `.agents/skills/coelo-ui/references/verification.md`.
- `.agents/skills/flutter-dart-code-review/SKILL.md`.
- `.agents/skills/verification-before-completion/SKILL.md`.
- `decisions/0018-happens-product-name.md`.
- `docs/superpowers/specs/2026-08-04-superadmin-activity-form-wizard-design.md`.
- `docs/knowledge/team/superadmin-activity-form-wizard.md`.

## Arquivos criados pela entrega preservada

- `apps/superadmin/lib/features/activities/presentation/activity_form_sections.dart`.
- Quatro goldens de formulário em `apps/superadmin/test/goldens/activities/`.
- `apps/principal/lib/features/happens/README.md`.
- `decisions/0018-happens-product-name.md`.
- `docs/knowledge/team/happens-product-naming.md`.
- `docs/knowledge/team/superadmin-activity-form-wizard.md`.
- `docs/superpowers/specs/2026-08-04-superadmin-activity-form-wizard-design.md`.
- Este checkpoint.

## Arquivos alterados relevantes

- `apps/superadmin/lib/features/activities/**` e testes/goldens correspondentes.
- `apps/superadmin/lib/app/router/superadmin_router.dart`.
- `apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart`.
- `apps/superadmin/lib/shared/presentation/widgets/superadmin_form_step_navigation.dart`.
- `apps/superadmin/lib/shared/presentation/widgets/superadmin_underline_tabs.dart`.
- `packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart`.
- `.agents/skills/coelo-ui/**`, índice e catálogo administrativo.
- Documentos de produto, arquitetura, design e READMEs afetados por Happens.

O worktree contém muitas outras alterações concorrentes de Health Care, Grupos,
Unidades, Perfis, Chat, Attendance e outras superfícies. Elas não foram
auditadas como parte desta tarefa e não podem entrar por acidente em um commit
de Atividades.

## Concluído

- Diretório, tabs, toggle 64 x 48, flyout e tabela estão conformes com o plano.
- Callbacks do wizard não persistem dados.
- Renomeação Happens e documentação/indexação estão conformes; ocorrências
  restantes de Flow são históricas ou termos técnicos genéricos permitidos.
- `SuperadminFormStepNavigation` atualmente usa vertical em medium/wide e resumo
  acessível no compacto, alinhado ao contrato Coelo UI.
- Revisão independente não encontrou P0.

## Parcialmente concluído

- Revisão de conformidade: concluída, mas revelou pendências P1/P2 abaixo.
- Preparação do commit: apenas inventário; nada foi staged ou commitado.
- Novo localhost: não iniciado.

## Ainda não iniciado

- Correção das pendências encontradas na revisão.
- Validação final após essas correções.
- Staging seletivo, commit e nova instância local em porta livre.

## Pendências e débitos técnicos conscientes

1. **P1 — hidratação de edição incompleta:**
   `activity_form_controller.dart` inicializa edição somente com identidade,
   instituição e governança e escolhe a primeira unidade disponível. Não
   recupera categoria, atividade sugerida, local, unidades e turmas existentes.
   Antes do commit, definir um contrato de apresentação de edição completo e
   adicionar teste que impeça sobrescrita acidental de vínculos.
2. **P1 — controle Material cru:**
   `activity_form_sections.dart`, no card de permissões profissionais, usa
   `Switch` diretamente. Criar um componente pequeno e público no
   `coelo_ui_admin` para label + estado `toggled` + alvo de 48 px + tokens e sem
   hover cinza; indexar, catalogar, testar e então substituir o uso local. Não
   ampliar a allowlist para forçar o gate.
3. **P2 — contrato no layer incorreto:**
   `ActivityFormDraft` e bytes de imagem estão em `domain/activity_directory.dart`,
   apesar de serem contratos de apresentação. Mover somente depois das P1, em
   alteração isolada e com testes verdes.
4. **P2 — microcopy:**
   governança não obrigatória aparece apenas como `Opcional`; o combinado era
   deixar explícito `Simples/Opcional`.

## Verificações já executadas na entrega

- Diretório + controller de Atividades: 14/14 testes verdes.
- Wizard de Atividades: 4/4 testes verdes.
- Goldens existentes: 6/6; novos estados de local/profissionais: 2/2.
- Flyout + tabela compartilhada: 19/19.
- Planos/Happens: 5/5.
- Análise focada de Atividades: `No issues found`.
- Gates Coelo UI de índice/superfícies e validador administrativo: PASS.
- Gates Coelo Knowledge: PASS.
- `git diff --check` focado: exit 0.

Estas verificações ocorreram antes desta revisão final; devem ser repetidas após
qualquer correção. A análise ampla do router havia encontrado erros concorrentes
de Health Care fora do escopo.

## Verificações desta revisão final

- `dart analyze` focado em Atividades, stepper e respectivos testes: exit 0,
  `No issues found`.
- Testes do stepper, controller e página do formulário: 11/11 verdes.
- `git diff --check` deste checkpoint: exit 0.
- Nenhum teste de Supabase foi executado e nenhum artefato de banco foi alterado.

## Bloqueios e avisos

- O worktree está altamente sujo e recebe alterações concorrentes. `git add .`
  é proibitivo para esta retomada; usar lista explícita e revisar `git diff --cached`.
- Não há commit desta revisão e nenhum localhost novo foi iniciado.
- O repositório está funcional para os testes focados executados, mas a entrega
  não está pronta para commit enquanto as duas pendências P1 permanecerem.

## Estado atual do Git

- Branch: `dev`.
- Worktree: centenas de arquivos modificados, removidos e não rastreados por
  tarefas concorrentes.
- Existem alterações em Supabase/migrations no worktree pertencentes a outras
  tarefas; não incluir, não editar e não reverter.
- Nenhum arquivo foi staged nesta revisão.

## Resumo do diff

O diff global ultrapassa 700 linhas de status e mistura Atividades com grandes
mudanças concorrentes. O lote de Atividades inclui diretório, wizard, contratos
locais, router, componentes compartilhados, testes/goldens, Happens e memória.
O lote concorrente inclui Health Care, Grupos, Unidades, Perfis, Chat,
Attendance, imports, notices, Supabase e artefatos `failures/`; mantê-lo fora do
commit de Atividades salvo decisão explícita do owner.

## Próximo passo exato

Abrir primeiro
`apps/superadmin/lib/features/activities/presentation/activity_form_sections.dart`
na função local `permission(...)` da classe `_ProfessionalPermissionCard`.
Comparar com os controles públicos existentes em `coelo_ui_admin`, criar o teste
RED de um `CoeloAdminToggleField`, implementar a menor API pública aprovada,
indexar/cadastrar o componente e substituir somente os quatro switches de
Atividades. Depois corrigir a hidratação de edição como segunda unidade atômica.

## Comandos de retomada

```powershell
Get-Content -LiteralPath 'docs\superpowers\checkpoints\2026-08-04-superadmin-activities-review-handoff.md'
rtk git status --short
rtk git diff -- apps/superadmin/lib/features/activities packages/coelo_ui_admin .agents/skills/coelo-ui apps/catalog
& '.agents\skills\coelo-ui\scripts\query-index.ps1' -Query 'toggle switch formulario permissao'
```

## Critérios para concluir a próxima etapa

- Nenhum `Switch` cru em Atividades.
- Novo controle possui teste de semântica `toggled`, disabled, alvo mínimo,
  teclado/mouse/toque e estados sem hover cinza.
- Índice, catálogo e validador administrativo permanecem verdes sem ampliar
  allowlist por conveniência.
- Testes do wizard e análise focada passam novamente.
- Hidratação de edição preserva todos os vínculos apresentados antes de salvar.
- Somente após isso: staging explícito, revisão do cached diff, commit e novo
  localhost em porta livre sem encerrar os existentes.
