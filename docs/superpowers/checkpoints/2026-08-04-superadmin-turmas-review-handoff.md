---
title: "Handoff da revisão de UI/UX de Turmas no Superadmin"
source: "Solicitação do Owner Coelo em 2026-08-04"
status: completed
generated_at: "2026-08-04"
updated_at: "2026-08-04"
---

# Handoff da revisão de UI/UX de Turmas no Superadmin

## Encerramento

- Data e hora: 2026-08-04 21:03 -03:00.
- Ponto seguro: revisão interrompida após análise estática direcionada e auditoria
  somente leitura por dois subagentes. Nenhuma correção de produção foi iniciada
  nesta etapa de encerramento.

## Objetivo original

Revisar a implementação da tela Turmas do Superadmin e os fluxos Criar/Editar
Turma, confirmar se o plano foi concluído e corrigir somente regressões dentro
desse escopo. A alteração permanece exclusivamente local de UI/UX, sem
Supabase, backend, migrations, integrações ou mudança de regra de negócio.

## Escopo efetivamente trabalhado

- Diretório de Turmas: nomenclatura, tabs exclusivas de status, toggle
  Cards/Tabela, flyout de visões, centralização e scrollbar horizontal.
- Formulário: identidade, atividades, pessoas, profissionais/admins e convites
  demonstrativos locais.
- Componentes compartilhados diretamente envolvidos: toggle de diretório e
  tabela administrativa redimensionável.
- Testes e documentação Coelo UI/Knowledge relacionados.

## Decisões que devem ser preservadas

- Turma é o termo visível; identificadores técnicos group* permanecem.
- Baseline do diretório: Instituições, com tabs lineares de Pessoas/Instituições.
- Baseline de Criar/Editar: formulário de Instituições,
  SuperadminFormStepNavigation e SuperadminFormActionFooter.
- Status: Todos, Ativos, Em Implantação e Inativos.
- Em Implantação mapeia para GroupStatus.draft.
- Inativos agrega inactive, suspended e archived no estado atual.
- Toggle Cards/Tabela: segmentos de 64 x 48 px e CoeloAdminFlyout quando houver
  mais de uma visão de tabela.
- A tabela nasce centralizada quando a largura natural é menor que a viewport e
  mantém scrollbar/track acima da coluna fixa.
- Pessoas, profissionais e convites permanecem UI local demonstrativa, sem
  persistência ou integração externa.
- Não introduzir Material cru, hover cinza, componente público ou token sem
  aprovação específica.

## Referências consultadas

- .agents/skills/coelo-ui/SKILL.md
- .agents/skills/coelo-knowledge/SKILL.md
- surface-interaction-contracts.md
- approved-superadmin-visual-baselines.md
- rejected-visual-patterns-inbox.md
- admin-directory-flyout-contracts.md
- directory-linear-tabs-contract.md
- form-layout-contracts.md
- interactive-state-evidence-matrix.md
- weekly-superadmin-ui-review.md
- verification.md
- package-boundaries.md
- docs/knowledge/team/superadmin-group-directory.md
- Implementações reais de Instituições/Pessoas e componentes compartilhados,
  também inspecionadas pelos subagentes.

## Arquivos afetados pelo lote já existente

- apps/superadmin/lib/features/groups/domain/group_directory.dart
- apps/superadmin/lib/features/groups/presentation/group_directory_page.dart
- apps/superadmin/lib/features/groups/presentation/group_directory_view_model.dart
- apps/superadmin/lib/features/groups/presentation/group_form_page.dart
- apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart
- packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart
- apps/superadmin/test/features/groups/presentation/group_directory_page_test.dart
- apps/superadmin/test/features/groups/presentation/group_form_page_test.dart
- apps/superadmin/test/features/groups/presentation/group_golden_test.dart
- apps/superadmin/test/shared/presentation/widgets/superadmin_directory_view_toggle_test.dart
- .agents/skills/coelo-ui/SKILL.md
- .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md
- docs/knowledge/team/superadmin-group-directory.md

## Concluído

- Análise estática direcionada dos arquivos de Turmas, router, toggle e tabela:
  No errors.
- Busca direta confirmou que o filtro de status antigo não existe na página;
  somente group-status-tabs está renderizado.
- Não foram encontrados CheckboxListTile, RadioListTile, DropdownButton,
  PopupMenuButton ou MenuAnchor no formulário de Turmas.
- Auditoria paralela do diretório e formulário concluída em modo somente leitura.
- Nenhum arquivo de produção foi alterado durante esta etapa de revisão.

## Parcialmente concluído

- A suíte focada foi iniciada, mas expirou após 184,6 segundos sem resultado.
- group_golden_test.dart:171 ainda referencia group-status-filter. A tentativa de
  patch não concluiu e o arquivo permaneceu inalterado.
- Não houve inspeção visual dos goldens nem execução do validador bloqueante de
  contratos administrativos nesta retomada.

## Achados preservados

- Médio: group_form_page.dart:995 mantém a seção de convites em Row/Expanded sem
  fallback compacto equivalente ao usado em Pessoas.
- Médio: group_form_page.dart:1030 mostra role.name cru; deve reutilizar o label
  localizado já existente.
- Baixo: FilterChip em torno da linha 648 e ActionChip em torno da linha 712
  precisam de verificação visual para confirmar ausência de hover cinza.
- Testes do formulário ainda não exercitam diretamente Pessoas, Profissionais e
  Convites.
- Um subagente reportou filtro duplicado, mas a busca direta contradisse o
  achado: group-status-filter aparece somente no golden test obsoleto, não na
  página. Não reabrir essa hipótese sem nova evidência.

## Não iniciado

- Correção responsiva da tabela de convites.
- Localização do papel na lista de convites.
- Cobertura comportamental das novas subseções.
- Atualização ou aprovação de goldens para o novo estado de tabs.
- Inicialização de novo localhost funcional.

## Verificações executadas e resultados

- MCP Dart analyze_files no escopo: No errors.
- flutter test de diretório, formulário e toggle: timeout após 184,6 s, sem
  saída conclusiva.
- rg de controles Material crus e pontos de scrollbar/tabela: somente usos
  internos do componente canônico e os chips citados.
- rg de group-status-filter: ocorrência somente em group_golden_test.dart:171;
  a página usa group-status-tabs.
- query-index.ps1 e Search-CoeloKnowledge.ps1 ficaram presos no terminal e foram
  interrompidos; as referências foram lidas diretamente por rg.
- Nenhum push, merge ou troca de branch foi executado.

## Erros, bloqueios e débitos conscientes

- Muitos processos Dart/Flutter concorrentes; testes e alguns comandos
  PowerShell ficaram bloqueados ou expiraram.
- O worktree possui centenas de mudanças preexistentes e concorrentes fora de
  Turmas. Elas foram preservadas e não devem ser revertidas.
- apply_patch não concluiu durante o encerramento. Nenhuma edição parcial foi
  deixada.
- Falta evidência visual específica aprovada para as novas subseções; não
  atualizar goldens para esconder regressões.

## Estado atual do git status e diff

- Worktree amplamente sujo, com alterações preexistentes em várias features,
  goldens/failures, packages, skills e documentação.
- O conjunto relevante está listado em Arquivos afetados.
- git status --short direcionado foi tentado no encerramento, mas não concluiu
  devido ao bloqueio do ambiente; repeti-lo na retomada.
- Resumo do diff relevante: renomeação visível para Turmas; status por tabs;
  ajustes do toggle/flyout; centralização/scrollbar da tabela; expansão local do
  formulário; testes e contratos correspondentes.
- Não assumir ownership das demais mudanças do worktree.

## Próximo passo exato

1. Abrir primeiro
   apps/superadmin/test/features/groups/presentation/group_golden_test.dart
   em torno da linha 171.
2. Trocar a interação obsoleta com group-status-filter/Rascunho por toque na tab
   Em Implantação, sem atualizar o golden automaticamente.
3. Formatar somente esse teste e executar os testes funcionais/golden de Turmas
   com timeout controlado.
4. Se o golden divergir, inspecionar a imagem de falha e confirmar a referência
   antes de atualizar o baseline.

## Comandos de retomada

```powershell
git status --short -- apps/superadmin/lib/features/groups apps/superadmin/test/features/groups
git diff -- apps/superadmin/lib/features/groups apps/superadmin/test/features/groups
dart format apps/superadmin/test/features/groups/presentation/group_golden_test.dart
Push-Location apps/superadmin
flutter test test/features/groups/presentation/group_directory_page_test.dart
flutter test test/features/groups/presentation/group_form_page_test.dart
flutter test test/features/groups/presentation/group_golden_test.dart
Pop-Location
```

## Critérios de conclusão da próxima etapa

- Nenhuma referência a group-status-filter permanece nos testes de Turmas.
- Testes funcionais de diretório e formulário concluem com resultado real.
- Golden de tabs é inspecionado e não é atualizado sem referência aprovada.
- Validador administrativo não encontra ocorrência proibida nova no lote.
- Nenhum arquivo fora do escopo autorizado é alterado.


## Encerramento final - 2026-08-05 09:28:19 -03:00

- Estado: implementação de UI/UX de Turmas concluída e validada no escopo local, sem localhost e sem Supabase.
- Correção final: convites usam linha compacta responsiva abaixo de `CoeloBreakpoints.medium.minWidth`, papel localizado e fundo semântico `colorScheme.surface`.
- Regra visual preservada: mobile/tablet usam base limpa em `surface`; `surfaceContainer*` fica restrito a superfícies secundárias funcionais.
- Testes funcionais: `group_form_page_test.dart` (4/4) e `group_directory_page_test.dart` (8/8) passaram.
- Testes visuais: `group_golden_test.dart` (10/10) passou após atualização exclusiva dos goldens de Turmas; repetido sem `--update-goldens`.
- Análise estática: `flutter analyze lib/features/groups test/features/groups` sem problemas.
- Verificação de diff: `git diff --check` sem erros; apenas avisos de normalização LF/CRLF.
- Busca de legado: nenhuma ocorrência de `group-status-filter`, `Grupos`, `Criar grupo` ou `Editar grupo` no código/testes da feature.
- Gate visual global: executou e falhou somente por cinco `InkWell` preexistentes fora de Turmas, em Importações, Avisos e Suporte. Não corrigidos por estarem fora do escopo.
- Artefatos temporários em `test/features/groups/presentation/failures` foram removidos.
- Próximo passo: revisão visual do usuário sobre os goldens de Turmas; qualquer ajuste posterior deve começar em `apps/superadmin/lib/features/groups/presentation/group_form_page.dart` ou `group_directory_page.dart`, conforme a seção apontada.

- Complemento final: chips de atividades e obrigatoriedade deixaram de herdar fundo/hover Material; estados agora usam somente `surface`, `primaryContainer` e tonal primário semântico. Após o ajuste, formulário (4/4), análise e goldens (10/10) permaneceram aprovados.
