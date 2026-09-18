---
title: "Handoff da revisão, padronização e commit de Saúde e Cuidado"
source: "Solicitações do Owner Coelo em 2026-08-04; specs/020-superadmin-health-care.md"
status: "completed"
generated_at: "2026-08-04"
updated_at: "2026-08-05"
---

# Handoff da revisão, padronização e commit de Saúde e Cuidado
## Fechamento da retomada em 2026-08-05

- O staging foi revisado hunk a hunk e contém somente Saúde e Cuidado, suas
  rotas, navegação, documentação canônica, goldens e padrões reutilizáveis
  necessários no Coelo UI.
- Foram excluídas do commit todas as alterações concorrentes de outras telas.
- Verificações verdes nesta retomada: 79 testes do módulo/rotas/toggle, 95
  testes de `coelo_ui_admin`, 13 testes de `coelo_tokens`, análise estática
  focada nos três escopos e `git diff --cached --check`.
- O teste amplo de navegação foi bloqueado por erros concorrentes já existentes
  em Avisos e Pessoas; nenhum deles foi corrigido ou incluído neste lote.
- Os gates PowerShell de índice/contratos/memória e os validadores Dart do
  catálogo travaram sem produzir saída e foram encerrados com segurança. As
  fontes canônicas, projeções de conhecimento, índice e catálogo específicos
  de Saúde e Cuidado foram preservados no staging.
- Por orientação do usuário, a abertura de um novo localhost deixou de fazer
  parte desta entrega.

## Encerramento

- Data e hora: 2026-08-04 21:03 -03:00.
- Branch preservada: dev.
- Motivo: encerramento solicitado em ponto seguro, antes de staging, commit e novo localhost.
- Estado preferencial alcançado: funcional e validado para a menor unidade alterada agora, o toggle canônico Cards/Tabela.

## Objetivo original

Revisar se o módulo Saúde e Cuidado foi implementado conforme o plano aprovado,
fortalecer na Coelo UI os padrões que devem ser obrigatórios, criar um commit
somente com o lote intencional e iniciar outro localhost sem encerrar os já
existentes.

## Escopo efetivamente trabalhado nesta etapa

- Releitura dos contratos obrigatórios da skill coelo-ui e da memória
  coelo-knowledge.
- Consulta do índice Coelo UI para diretório, toggle, tabela, flyout,
  multi-select, Histórico e formulários.
- Revisão da componentização já presente:
  CoeloAdminMultiSelectField, CoeloStatusColors de Histórico,
  CoeloAdminResizableTable, SuperadminDirectoryViewToggle, contratos, índice,
  catálogo, testes e goldens.
- Inspeção do worktree para separar Saúde e Cuidado de centenas de mudanças
  simultâneas de outras features.
- Correção atômica do toggle compartilhado: cada segmento voltou a 64 x 48 px,
  total de 128 x 48 px, e o BOM acidental do arquivo foi removido.
- Formatação, teste focado, análise estática focada e diff check do toggle.

## Decisões de produto e UI/UX a preservar

- O módulo se chama Saúde e Cuidado em código, rotas, documentação e interface.
- Perfis de cuidado e Planos de medicação são áreas irmãs e distintas.
- Perfis guardam características permanentes da criança; planos representam
  vigência, horários, responsáveis e contexto de administração.
- Rotas canônicas:
  /health-care/profiles;
  /health-care/profiles/new;
  /health-care/profiles/:childId;
  /health-care/profiles/:childId/edit;
  /health-care/medication-plans;
  /health-care/medication-plans/new;
  /health-care/medication-plans/:medicationId;
  /health-care/medication-plans/:medicationId/edit.
- Instituições é a baseline dos diretórios, cards, toggle e tabela.
- Criar/Editar Instituição é a baseline dos formulários.
- Toggle Cards/Tabela tem segmentos imutáveis de 64 x 48 px.
- Tabela seleciona Agrupado diretamente. Com uma única visão, não abre flyout.
  Com mais de uma visão, usa CoeloAdminFlyout, teclado, toque e retorno de foco.
- Cards clicáveis usam CoeloAdminInteractiveCard; criação usa
  CoeloAdminCreateAction; status usa CoeloAdminExpandableStatusIndicator.
- Tabela usa CoeloAdminResizableTable, largura natural centralizada e scrollbar
  visível acima da coluna fixa.
- Multi-select de formulário usa CoeloAdminMultiSelectField com rascunho,
  busca opcional, Limpar/Aplicar, teclado, Esc e largura do gatilho.
- Histórico usa historyContainer/onHistoryContainer, com texto e ícone e
  contraste AA nos temas claro e escuro.
- Não usar hover cinza, HEX local, Material cru, RadioListTile ou menu local.
- Não alterar banco, migrations, RLS, Supabase remoto ou regra de negócio neste lote.

## Referências consultadas

- AGENTS.md e RTK.md.
- .agents/skills/coelo-ui/SKILL.md.
- .agents/skills/coelo-ui/references/surface-interaction-contracts.md.
- .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md.
- .agents/skills/coelo-ui/references/rejected-visual-patterns-inbox.md.
- .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md.
- .agents/skills/coelo-ui/references/form-layout-contracts.md.
- .agents/skills/coelo-ui/references/interactive-state-evidence-matrix.md.
- .agents/skills/coelo-ui/references/package-boundaries.md.
- .agents/skills/coelo-ui/references/verification.md.
- .agents/skills/coelo-knowledge/SKILL.md.
- docs/design/design-system.md.
- specs/020-superadmin-health-care.md.
- docs/knowledge/team/health-care.md.
- docs/knowledge/admin/health-care.md.
- Tela e testes de Instituições como baseline persistente.

## Arquivos criados pelo lote Saúde e Cuidado

- apps/superadmin/lib/features/health_care/data/demo_health_care_repository.dart
- apps/superadmin/lib/features/health_care/domain/health_care.dart
- apps/superadmin/lib/features/health_care/presentation/health_care_controller.dart
- apps/superadmin/lib/features/health_care/presentation/health_care_detail_page.dart
- apps/superadmin/lib/features/health_care/presentation/health_care_directory_page.dart
- apps/superadmin/lib/features/health_care/presentation/health_care_form_pages.dart
- apps/superadmin/lib/features/health_care/presentation/health_medication_plan_detail_page.dart
- apps/superadmin/lib/features/health_care/presentation/health_medication_plan_directory_page.dart
- apps/superadmin/test/app/router/health_care_routes_test.dart
- apps/superadmin/test/features/health_care/ com 8 arquivos de teste.
- apps/superadmin/test/goldens/health_care/ com 12 goldens.
- docs/data/health-care-future-data-model.md
- docs/knowledge/admin/health-care.md
- docs/knowledge/team/health-care.md
- packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_field.dart
- packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_field_test.dart
- specs/020-superadmin-health-care.md
- Este checkpoint.

## Arquivos removidos ou substituídos pelo lote

- apps/superadmin/lib/features/health_safety/ inteiro.
- apps/superadmin/test/features/health_safety/ inteiro.
- apps/superadmin/test/app/router/health_safety_routes_test.dart.
- docs/data/health-safety-future-data-model.md.
- docs/knowledge/admin/health-safety.md.
- docs/knowledge/team/health-safety.md.
- specs/020-superadmin-health-safety.md.

## Arquivos compartilhados afetados que exigem revisão de staging

- apps/superadmin/lib/app/router/superadmin_routes.dart
- apps/superadmin/lib/app/router/superadmin_router.dart
- apps/superadmin/lib/app/shell/superadmin_shell.dart
- apps/superadmin/lib/app/dev_menu/dev_menu_overlay.dart
- apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart
- apps/superadmin/test/shared/presentation/widgets/superadmin_directory_view_toggle_test.dart
- packages/coelo_tokens/lib/src/coelo_status_colors.dart
- packages/coelo_tokens/test/coelo_tokens_test.dart
- packages/coelo_ui_admin/lib/coelo_ui_admin.dart
- packages/coelo_ui_admin/README.md
- apps/catalog/assets/coelo-ui.index.jsonl
- apps/catalog/assets/admin-visual-contract-allowlist.json
- apps/catalog/lib/catalog/catalog_foundations.dart
- apps/catalog/lib/catalog/catalog_registry.dart
- apps/catalog/test/catalog/catalog_registry_examples_test.dart
- .agents/skills/coelo-ui/SKILL.md
- .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md
- .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md
- docs/design/design-system.md
- docs/architecture, docs/product, docs/security e specs/README.md somente nos
  hunks de renomeação Saúde e Cuidado.

Os quatro arquivos de router, shell e menu têm diffs grandes e misturados com
outras features. Devem ser staged por hunk, nunca por arquivo inteiro.
A skill Coelo UI e o índice também contêm hunks concorrentes de Perfis e
Permissões; stage somente toggle, multi-select, Histórico e Saúde e Cuidado.

## Componentes, rotas e superfícies afetadas

- SuperadminDirectoryViewToggle.
- CoeloAdminMultiSelectField.
- CoeloAdminResizableTable, apenas como padrão já existente; o diff atual do
  arquivo de tabela inclui API concorrente de controller/scrollbar e não deve
  ser assumido como pertencente a este lote sem revisão.
- CoeloStatusColors.
- Diretórios e formulários de Perfis de cuidado.
- Diretórios, detalhes e formulários de Planos de medicação.
- Shell, menu de desenvolvimento e roteador do Superadmin.
- Catálogo e índice da Coelo UI.

## Concluído

- Implementação funcional do módulo e separação das duas áreas.
- Renomeação global de HealthSafety/health_safety para HealthCare/health_care na
  busca auditada; três referências antigas em plano técnico também foram corrigidas.
- Padrões de toggle, flyout com uma visão, multi-select e Histórico registrados.
- Status e contexto responsável adicionados ao diretório de medicação.
- Contextos de administração adicionados ao formulário de medicação.
- Doze goldens disponíveis.
- Correção atômica atual do toggle para 64 x 48 px por segmento.
- Nenhum arquivo foi staged e nenhum commit foi criado nesta etapa de encerramento.
- Nenhum localhost existente foi encerrado.

## Parcialmente concluído

- Manifesto de commit identificado, mas staging parcial ainda não executado.
- Revisão de diffs compartilhados iniciada. Já foi confirmado que:
  - o diff atual de CoeloAdminResizableTable contém API concorrente e não deve
    ser staged automaticamente;
  - a skill Coelo UI contém hunk concorrente de Perfis e Permissões;
  - o índice contém hunk concorrente de Perfis e Permissões;
  - router, shell e dev menu possuem mudanças misturadas.
- O novo localhost ainda não foi criado.

## Ainda não iniciado

- Staging por hunk do lote.
- Revisão final do staged diff.
- Commit.
- Escolha de uma porta livre e inicialização do novo web-server.
- Verificação HTTP e dos logs do novo localhost.

## Verificações executadas nesta unidade de encerramento

- Formatação:
  C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format
  apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart
  apps/superadmin/test/shared/presentation/widgets/superadmin_directory_view_toggle_test.dart
  Resultado: 2 arquivos verificados, 1 formatado.
- Teste focado:
  flutter test --no-pub
  test/shared/presentation/widgets/superadmin_directory_view_toggle_test.dart
  Resultado: 5/5 testes passaram.
- Análise focada:
  dart analyze no componente e no teste do toggle.
  Resultado: No issues found.
- Diff check focado:
  git -c core.safecrlf=false diff --check nos dois arquivos.
  Resultado: exit code 0; somente aviso esperado de conversão LF/CRLF no diff stat.

## Evidências anteriores que devem ser revalidadas antes do commit

Na auditoria imediatamente anterior foram obtidos:
- 79 testes de Saúde e Cuidado, toggle e rotas verdes.
- 95 testes do pacote coelo_ui_admin verdes.
- 13 testes de coelo_tokens verdes.
- 12 goldens regenerados e comparados.
- Gates de índice, contratos e memória verdes.
- Análise focada do módulo sem issues.

Essas evidências são úteis, mas o worktree está recebendo mudanças simultâneas.
Rode novamente os gates direcionados antes de criar o commit.

## Erros e avisos ainda existentes

- O validador visual global apontou ocorrências fora deste lote em Chat,
  Importações, Avisos e Suporte.
- A suíte global de router/shell foi bloqueada por erros sintáticos e de API em
  mudanças concorrentes de Chat, Importações e Avisos.
- O comando git pelo shim C:\Program Files\Git\cmd\git.exe ficou travando.
  Usar C:\Program Files\Git\bin\git.exe, que respondeu normalmente.
- O wrapper RTK ficou travado em algumas execuções; os runners oficiais Dart e
  Flutter foram usados como fallback.
- Existem avisos de normalização LF/CRLF. O diff check focado passou.
- Não corrigir esses problemas externos durante a retomada deste lote.

## Bloqueios encontrados

- Worktree altamente compartilhado e mutável, com alterações simultâneas.
- Não é seguro executar git add em arquivos compartilhados inteiros.
- A criação de commit exige staging seletivo e revisão de cada hunk.
- A suíte global não é critério confiável enquanto as features concorrentes
  estiverem sintaticamente quebradas; usar os testes focados e registrar o bloqueio.

## Débitos técnicos conscientes

- A implementação continua demonstrativa, sem persistência produtiva do módulo.
- O visualizador local de imagens travou; a comparação automatizada dos goldens
  passou, mas a última rodada não teve inspeção manual pixel a pixel.
- O validador visual global continua vermelho por outras features.
- O novo localhost deve escolher porta livre sem parar processos existentes.

## Estado atual do git status

- Branch: dev.
- 430 entradas no status.
- 0 entradas staged.
- 228 modificadas.
- 107 deletadas.
- 95 não rastreadas.
- O volume inclui muitos trabalhos não relacionados; não usar git add -A,
  git add . ou commit -a.

## Resumo do git diff

- Diff tracked global: 335 arquivos, 10.479 inserções e 9.838 remoções.
- O lote Saúde e Cuidado inclui a substituição dos antigos arquivos
  health_safety, oito arquivos de produção health_care, testes, 12 goldens,
  documentação, token Histórico e o novo multi-select.
- O toggle compartilhado contém a mudança intencional para tamanho imutável,
  seleção Agrupado direta e ausência de flyout com uma única visão.
- Os arquivos compartilhados listados acima têm mudanças misturadas e precisam
  de staging por hunk.
- Não existe diff cached neste checkpoint.

## Próximo passo exato, pequeno e executável

1. Ler integralmente este checkpoint.
2. Conferir status e diff usando C:\Program Files\Git\bin\git.exe.
3. Abrir primeiro
   apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart
   e confirmar as constantes _segmentWidth = 64.0 e
   _toggleWidth = _segmentWidth * 2.
4. Reexecutar o teste focado do toggle.
5. Montar o staging do lote começando pelos arquivos exclusivos:
   health_safety removidos, health_care criados, respectivos testes/goldens,
   spec, modelo futuro e memória.
6. Só depois fazer staging por hunk dos arquivos compartilhados.
7. Revisar git diff --cached --check e git diff --cached antes do commit.
8. Criar um único commit coerente de Saúde e Cuidado.
9. Após o commit, localizar porta livre e iniciar novo web-server sem encerrar
   qualquer processo existente; validar HTTP e logs.

## Primeiro arquivo a abrir na retomada

apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart

## Comandos de retomada

    [IO.File]::ReadAllText('C:\Users\adrie\Documents\Coelo\docs\superpowers\checkpoints\2026-08-04-health-care-commit-handoff.md')

    & 'C:\Program Files\Git\bin\git.exe' status --short --untracked-files=all

    & 'C:\Program Files\Git\bin\git.exe' diff -- apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart

    C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test --no-pub test/shared/presentation/widgets/superadmin_directory_view_toggle_test.dart

## Critérios de conclusão da próxima etapa

- Staged diff contém somente Saúde e Cuidado e seus padrões públicos aprovados.
- Nenhuma mudança concorrente de Chat, Unidades, Atividades, Perfis e Permissões,
  Importações, Avisos, Suporte ou outro lote entra no commit.
- Testes focados do módulo, toggle, coelo_ui_admin e tokens passam novamente.
- Gates de índice, contratos e memória passam ou bloqueios externos são
  reproduzidos e documentados.
- git diff --cached --check passa.
- Commit é criado na branch dev sem push, merge ou troca de branch.
- Novo localhost responde HTTP 200 em porta diferente das já ocupadas, sem
  encerrar processos existentes.