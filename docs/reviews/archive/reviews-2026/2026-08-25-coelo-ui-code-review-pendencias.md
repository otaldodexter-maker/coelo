---
source: "Code review profundo com correção Coelo UI/UX"
status: "open"
generated_at: "2026-08-25"
---

# Pendências da revisão profunda Coelo UI/UX

## 1. Resumo executivo

O lote corrigiu causas compartilhadas do shell, navegação, flyouts, toolbar de diretórios, formulários e previews internos. A evidência fresca cobre 175 rotas reais no router (79 de produção e 96 DEV) no nível de composição; não cobre renderização visual individual de todas elas. As famílias marcadas como **comprovadas** abaixo possuem teste, render/golden ou inspeção visual específica. As demais permanecem **não revisadas**, **parcialmente revisadas** ou **não implementadas**; nenhuma delas deve ser interpretada como aprovada.

O worktree já continha mais de mil alterações antes deste lote. Os diffs foram preservados, não houve commit, merge, rebase, push, restauração destrutiva ou promoção de imagens de `failures/`. Há 1.540 artefatos sob diretórios `failures/`, todos excluídos como baseline.

## 2. Cobertura por rota e família

| Família / rotas | Cobertura desta revisão | Evidência | Estado |
| --- | --- | --- | --- |
| Autenticação: login, recuperação e redefinição | Baseline protegida localizada; sem alteração rastreada em golden de Login | índice Coelo UI e inventário de PNG | Parcialmente revisada; fluxos completos não rerenderizados |
| Home / Central de ajuda | Composição do shell e atalhos revisados | gate conjunto shell/router 88/88 | Parcialmente comprovada |
| Shell, sidebar/rail, busca, flyouts, conta, logout | Navegação declarativa, seleção, expansão, busca compacta, teclado, `Esc`, foco interno e confirmação de logout | revalidação final do Menu: 43/43 no pacote focado e 4/4 nas rotas de perfis; analyzer, validador visual e diff-check verdes | Aprovada no escopo testado; decisão A preservada |
| Instituições | Picker de data canônico e baseline consultada | testes focados do lote de formulários | Comprovada apenas na correção alterada |
| Unidades | Dialog migrado para `CoeloAdminDialogShell` | testes focados do lote de formulários | Comprovada apenas na correção alterada |
| Turmas | Baseline localizada; 31 goldens já alterados no worktree | inventário de imagens | Não revisada visualmente neste lote |
| Atividades e avaliações | Rotas de diretório, detalhe, edição, configuração, lançamento e fechamento compostas no router | testes focados de roteamento | Parcialmente revisada; telas/estados não receberam smoke visual completo |
| Assiduidade | Revisão independente somente leitura cobriu domínio, controller/adapter, páginas, auth scope, RPC e pgTAP; a rodada SQL reaberta foi corrigida e revalidada com funções reais | pgTAP real 24/24; domínio 5/5; adapter 4/4; reset 148; lint das duas funções e padrões proibidos zero; canônico=espelho SHA256 `DF580EBBE884E03C3B7513495844F52611870826E96D785C699340C51A58A985` | Reaprovada no escopo reduzido; 2 goldens preexistentes continuam divergentes e não foram atualizados |
| Rotina diária | Rotas compostas; sem smoke visual completo | inventário do router | Não revisada visualmente |
| Acompanhamento de alunos | Rotas de visão e gerenciamento compostas | testes focados de roteamento | Parcialmente revisada; estados internos não renderizados integralmente |
| Pessoas | Wizard usa `SuperadminShell` + `SuperadminFormFrame`; transição de etapa removida; cabeçalho canônico comprovado | 20/20 testes funcionais e 1/1 teste de golden; create light 375 e edit dark 1440 inspecionados conscientemente | Correção comprovada; 8 goldens preexistentes do diretório permanecem divergentes e não foram promovidos |
| Segurança da criança | Rotas DEV completadas | testes focados de roteamento | Parcialmente revisada; revogação não implementada |
| Usuários internos | Wizard usa frame canônico; Cancelar/Salvar retornam ao diretório estável | 4/4 testes funcionais e 1/1 teste de golden; create light 375 e edit dark 1440 inspecionados conscientemente | Correção comprovada; visualização e desativação não implementadas, portanto a ação de abrir foi desabilitada |
| Perfis, permissões e modelos | Rotas e formulários com domínio compostos; criação válida permanece no diretório após seleção de domínio; opção A aprovada: atalhos globais sem domínio permanecem fora da árvore | testes focados de roteamento, asserções de ausência e decisão do Coordenador | Comprovada no roteamento corrigido; launcher/capability snapshot global ficou deliberadamente fora desta entrega |
| Perfis de cuidado e medicação | Rotas compostas | inventário do router | Não revisada visualmente |
| Planos | Wizard migrado; 3 goldens inspecionados | lote de formulários | Comprovada no fluxo alterado |
| Cardápios | Wizard migrado; 4 goldens inspecionados | lote de formulários | Comprovada no fluxo alterado |
| Formulários | Respostas usam dialog canônico; rotas DEV completadas | lote de formulários | Comprovada na correção; monitoramento/arquivos/mídia não tiveram smoke global |
| Importações | Rotas compostas | inventário do router | Não revisada visualmente; download de relatório não implementado |
| Agenda | Rotas DEV presentes | inventário do router | Não revisada visualmente |
| Conversas | Rotas compostas | inventário do router | Não revisada visualmente; mídia e grupos não comprovados |
| Convites | CTA de criação removido de `unauthorized` | testes focados do lote de formulários | Comprovada na correção |
| Comunicações | Rotas compostas | inventário do router | Não revisada visualmente; arquivamento não comprovado |
| Suporte e implantação | Navegação de produção corrigida | testes de rota focados | Comprovada no roteamento; superfícies internas não revisadas integralmente |
| Auditoria | Rota composta | inventário do router | Não revisada visualmente |
| Catálogo | Navegação, índice e fronteiras aprovados; projeções geradas sincronizadas | relatório `status: synchronized`, `diagnostics: []`; 80/80 testes focados e 137/137 na suíte completa | Comprovada no escopo alterado; 8 divergências reduzidas a zero sem ampliar allowlist |
| Acontece | Conteúdo enquadrado sem segundo app bar/rail/bottom nav | testes/goldens do lote de previews | Comprovada no escopo alterado |
| Para você | Conteúdo enquadrado e rota corrigida | testes/goldens do lote de previews | Comprovada no escopo alterado |
| Agora | Viewer imersivo e dialog de publicação corrigidos | testes/goldens do lote de previews | Comprovada internamente; retorno de foco externo pendente |
| Momentos | Viewer imersivo e X/Fechar restaurado à família canônica `error/errorContainer` | testes/goldens do lote de previews | Comprovada internamente; retorno de foco externo pendente |
| Perfil Principal e circulares | Rotas existentes inventariadas | inventário do router | Não revisada visualmente neste lote |
| Meu perfil, configurações e sair | Conta/tema/reduced motion e logout exercitados pelo shell | testes de shell e conta existentes | Parcialmente comprovada |
| Busca na navegação | Busca expandida e compacta, teclado e `Esc` | testes de navegação | Comprovada |
| Tours | Nenhum conteúdo aprovado encontrado | fontes canônicas | Não implementados; proposta necessária |
| Erros 403/404/500/503 | Baselines protegidas localizadas e sem PNG rastreado alterado | inventário de imagens | Não rerenderizadas integralmente nesta revisão |

## 3. Pendências visuais

| Severidade | Rota / estado | Arquivo e linha | Evidência | Impacto | Correção e teste recomendados | Bloqueio / decisão |
| --- | --- | --- | --- | --- | --- | --- |
| Médio | Pessoas — diretório | `apps/superadmin/test/goldens/people/` | 8 goldens preexistentes do diretório continuam divergentes; os 2 goldens do formulário foram inspecionados e promovidos separadamente | estados do diretório não possuem referência visual verde neste lote | comparar os 8 resultados com Instituições antes de qualquer atualização | ownership distinto do formulário; nunca promover `failures/` |
| Alto | Assiduidade — goldens existentes | `apps/superadmin/test/features/attendance/attendance_pages_golden_test.dart:35` e `:56` | execução independente: 375 light diverge 13,05%/44.027 px; 1440 dark diverge 11,86%/153.704 px | as referências preexistentes permanecem sem evidência visual verde | comparar conscientemente com a spec/baseline antes de qualquer atualização | fora do refactor aprovado; não atualizar golden apenas para fazê-lo passar |
| Médio | Baselines protegidas | `apps/superadmin/test/**/goldens/*.png` | 66 PNGs protegidos rastreados já estavam alterados: dev menu 1, conta 8, ajuda 2, Instituições 7, Unidades 17, Turmas 31 | Não é possível atribuir ou aprovar em massa sem inspeção consciente | Revisar família por família; nunca copiar `failures/` | Ownership das alterações preexistentes |
| Médio | Menus/dialogs Material preexistentes | `superadmin_activity_center.dart:65`; `superadmin_advanced_color_picker_dialog.dart:59`; `superadmin_bug_report_dialog.dart:232`; `superadmin_help_center_page.dart:416`; `institution_directory_toolbar.dart:412`; `support_kanban.dart:194` | busca fresca encontrou 15 ocorrências em 7 arquivos; todas já existiam no SHA histórico `65094e10` | podem divergir do flyout/dialog canônico, mas Login e Instituições são baselines protegidas e não devem ser alteradas sem regressão visual comprovada | Renderizar cada overlay aberto e migrar somente os casos comprovadamente divergentes; preservar `CheckboxListTile` do Login enquanto a baseline permanecer aprovada | requer inspeção visual específica e ownership das mudanças preexistentes |
| Médio | Demais rotas da matriz | router e páginas correspondentes | não houve render individual em todas as 175 rotas reais | Regressões locais podem permanecer | Smoke por família nos quatro breakpoints, dois temas e texto a 200% | Timebox encerrado |

## 4. Pendências de acessibilidade e responsividade

| Severidade | Superfície | Arquivo e linha | Evidência | Impacto | Próximo passo |
| --- | --- | --- | --- | --- | --- |
| Alto | Agora/Momentos — fechar viewer | `apps/superadmin/lib/app/router/superadmin_router.dart:3293` e `:3310` | fechamento navega para Acontece e desmonta a origem; não há evidência de `FocusNode` externo restaurado | usuário de teclado pode perder o ponto de retorno | Criar teste de integração no shell que abre pelo item, fecha com `Esc` e comprova foco no item de origem |
| Médio | Rotas não renderizadas | páginas listadas como “não revisada” | matriz completa light/dark, 200%, mouse/teclado/toque e reduced motion não foi executada em cada rota | overflows ou foco incompleto podem permanecer | Executar smoke incremental por família; não marcar como aprovada antes da evidência |
| Médio | Assiduidade — KPIs compactos | `apps/superadmin/lib/features/attendance/attendance_dashboard_page.dart:378` | grid força duas colunas em 375 px mesmo com texto a 200%; o teste só prova ausência de exceção | densidade e leitura ficam degradadas | reduzir para uma coluna quando a largura funcional ou `textScale >= 1.5` não comportar duas |
| Médio | Assiduidade — gráfico comparativo | `apps/superadmin/lib/features/attendance/attendance_dashboard_page.dart:760` | alternativa semântica anuncia apenas série atual; série anterior não tem legenda e `dashed` apenas muda espessura | comparação depende de cor/traço não explicitado | adicionar legenda e texto atual/anterior; usar diferenciação não cromática real |

## 5. Dívida técnica de código e segurança

| Severidade | Arquivo e linha | Evidência | Impacto | Correção recomendada | Teste necessário | Decisão exigida |
| --- | --- | --- | --- | --- | --- | --- |
| Baixo | analyzer do Superadmin | análise completa final: 0 errors, 0 warnings, 56 infos | ruído dificulta gate estrito | resolver infos em lote separado, sem misturar com UI | analyze completo | não bloqueante |
| Baixo | worktree global | `git diff --check` emite avisos EOL/CRLF no worktree; o filtro fresco por `blank line at EOF`, trailing whitespace, space-before-tab e marcadores de conflito retornou zero erros materiais | gate global permanece ruidoso por normalização de EOL | normalizar somente com ownership por arquivo | diff-check por manifesto | mudanças preexistentes |
| Alto | `apps/superadmin/lib/features/attendance/attendance_pages.dart:621` e `:858` | loading/error/not-found saem do shell; erro de comando usa `_loadError` e substitui a chamada por texto cru; bulk não captura falha | shell desmonta e o usuário perde leitura/recuperação após conflito ou rede | manter shell, separar erro inicial/comando, preservar snapshot e oferecer retry/reload | testes unauthorized/conflict/network/bulk | dívida preexistente do fluxo canônico, fora deste refactor; próxima revisão |
| Médio | `apps/superadmin/lib/features/attendance/data/supabase_attendance_repository.dart:91` | contrato de status/download invoca a futura Edge Function `attendance-export`, mas não há worker de materialização e a UI permanece corretamente oculta | exportação ainda não é uma funcionalidade utilizável | implementar worker, storage privado, status/download autorizado e só então expor a UI | integração backend/cliente, expiração de URL e cross-tenant | limitação aceita, fora deste refactor |
| Médio | `apps/superadmin/lib/features/attendance/attendance_pages.dart:429` | criação não tem in-flight guard, tratamento de erro ou `mounted` antes do callback | duplo acionamento pode criar chamadas concorrentes e falha não tem feedback | `_submitting`, desabilitar entradas, try/catch e mounted | teste com `Completer`, duplo toque e falha | dívida preexistente do fluxo canônico, fora deste refactor; próxima revisão |

## 6. Evidência de correções concluídas

- Shell/router/navegação: 88 testes aprovados, 0 falhos.
- `coelo_ui_admin`: 107 testes aprovados, 0 falhos; analyzer sem issues.
- Diretórios/formulários: 128 testes aprovados, 0 falhos; 7 goldens comparados e atualizados conscientemente.
- Previews: 106 testes aprovados, 0 falhos na verificação independente; após restaurar o contrato canônico do X/Fechar, o gate final passou em 45/45, incluindo 12 goldens reinspecionados.
- Analyzer focado do shell/router: sem issues.
- Analyzer completo do Superadmin: 0 errors, 0 warnings e 56 infos.
- Validador visual, índice Coelo UI e fronteiras: aprovados.
- Teste de wiring de produção: 3/3 aprovados após delimitar corretamente o trecho de rotas DEV; suporte e conta em memória permanecem confinados ao preview de desenvolvimento e não há senha demonstrativa exposta.
- Pessoas/Usuários internos: 24/24 testes funcionais e 2/2 testes de golden representando 4 imagens; create light 375 e edit dark 1440 de cada família foram inspecionados conscientemente; analyzer, validador visual e diff-check focados passaram. A execução ampla do golden de diretório terminou com 26 testes aprovados e 1 teste falho contendo 8 comparações divergentes, todas registradas como dívida preexistente.
- Catálogo: 8 divergências reduzidas a zero; 80/80 testes focados e 137/137 na suíte completa, analyzer, sync, índice, fronteiras, contratos visuais/interativos e diff-check focado passaram.
- Menu: os quatro achados da revisão final foram corrigidos — launcher DEV no login somente em ambiente autorizado, seleção específica de deep links com pais visíveis, finder semântico de permissões e busca sem nós `routeName == null`. Revalidação independente: 43/43 + 4/4, analyzer sem issues, validador visual e diff-check verdes; decisão A preservada.
- Assiduidade: a revisão independente comprovou UI/controller/adapter e a rodada SQL reaberta corrigiu `42P01`, `42702`, `42703` e o helper que mascarava SQLSTATE inesperado. O gate final executou as funções reais: pgTAP 24/24, seis guards de `assignments`, tabela/FK/escopo/status canônicos, variáveis `requested_*`, `child_contexts`, lint e padrões proibidos zero; canônico e espelho têm SHA256 `DF580EBBE884E03C3B7513495844F52611870826E96D785C699340C51A58A985`.

## 7. Ordem recomendada para a próxima revisão

1. Implementar a visualização de usuário interno apenas com contrato aprovado; até lá, manter a ação indisponível.
2. Tratar separadamente as dívidas preexistentes de comando/criação e os dois goldens divergentes de Assiduidade.
3. Provar retorno de foco externo de Agora/Momentos com teste de integração do shell, após cessão formal de ownership do router.
4. Revisar os 8 goldens divergentes do diretório de Pessoas e os demais 66 goldens protegidos preexistentes por família.
5. Executar smoke visual incremental nas famílias marcadas como não revisadas.
6. Tratar infos do analyzer e avisos globais de EOL somente com ownership confirmado.

## 8. Cadência

Manter revisão semanal enquanto houver mudanças frequentes de UI ou qualquer achado Bloqueador/Alto. Manter semanal até duas revisões consecutivas sem Bloqueador/Alto; depois passar para quinzenal durante estabilização. Passar para mensal somente com UI estável, goldens e gates executados continuamente. Qualquer regressão visual crítica antecipa a próxima revisão, independentemente da cadência.

## 9. Gate de conhecimento

Nenhuma regra durável nova foi aprovada neste lote: resultado esperado e registrado como `no-op`. As correções aplicam contratos canônicos já existentes; não criam nova projeção de conhecimento.

## 10. Inventário de arquivos tocados por esta tarefa

Fontes e testes alterados diretamente durante o lote principal:

- `apps/superadmin/lib/app/activity/superadmin_activity.dart`
- `apps/superadmin/lib/app/brand/superadmin_brand_mark.dart`
- `apps/superadmin/lib/app/dev_menu/dev_menu_overlay.dart`
- `apps/superadmin/lib/app/dev_menu/development_person_directory_repository.dart`
- `apps/superadmin/lib/app/navigation/superadmin_navigation.dart`
- `apps/superadmin/lib/app/router/superadmin_router.dart`
- `apps/superadmin/lib/app/router/superadmin_routes.dart`
- `apps/superadmin/lib/app/shell/superadmin_activity_center.dart`
- `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart`
- `apps/superadmin/lib/features/people/data/fake_person_directory_repository.dart`
- `apps/superadmin/lib/features/people/presentation/person_file_actions.dart`
- `apps/superadmin/lib/features/people/presentation/person_form_page.dart`
- `apps/superadmin/lib/features/platform_users/data/fake_platform_user_repository.dart`
- `apps/superadmin/lib/features/platform_users/presentation/platform_user_directory_page.dart`
- `apps/superadmin/lib/features/platform_users/presentation/platform_user_form_page.dart`
- `apps/superadmin/lib/features/principal_happens/presentation/principal_happens_preview_page.dart`
- `apps/superadmin/lib/features/units/presentation/widgets/unit_file_actions.dart`
- `packages/coelo_ui_admin/lib/src/listing/coelo_admin_listing_toolbar.dart`
- `apps/superadmin/test/app/dev_menu_overlay_test.dart`
- `apps/superadmin/test/app/dev_menu_test.dart`
- `apps/superadmin/test/app/navigation/superadmin_navigation_test.dart`
- `apps/superadmin/test/app/router/assessment_routes_test.dart`
- `apps/superadmin/test/app/router/catalog_routes_test.dart`
- `apps/superadmin/test/app/router/persistent_shell_routes_test.dart`
- `apps/superadmin/test/app/router/platform_user_preview_routes_test.dart`
- `apps/superadmin/test/app/router/principal_for_you_preview_route_test.dart`
- `apps/superadmin/test/app/router/principal_now_preview_route_test.dart`
- `apps/superadmin/test/app/router/production_repository_wiring_red_test.dart`
- `apps/superadmin/test/app/router/superadmin_router_test.dart`
- `apps/superadmin/test/app/router/support_routes_test.dart`
- `apps/superadmin/test/app/shell/superadmin_activity_center_test.dart`
- `apps/superadmin/test/app/shell/superadmin_shell_test.dart`
- `apps/superadmin/test/features/people/people_production_boundary_test.dart`
- `apps/superadmin/test/features/people/presentation/person_file_actions_test.dart`
- `apps/superadmin/test/features/people/presentation/person_form_page_test.dart`
- `apps/superadmin/test/features/platform_users/data/fake_platform_user_repository_test.dart`
- `apps/superadmin/test/features/platform_users/presentation/platform_user_pages_test.dart`
- `packages/coelo_ui_admin/test/listing/coelo_admin_listing_toolbar_test.dart`

Artefatos de catálogo, relatório e evidência visual alterados no fechamento:

- `apps/catalog/assets/coelo-ui.index.jsonl`
- `apps/catalog/assets/catalog-sync-report.json`
- `apps/superadmin/test/goldens/people/person_form_create_light_375.png`
- `apps/superadmin/test/goldens/people/person_form_edit_dark_1440.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_create_light_375.png`
- `apps/superadmin/test/features/platform_users/presentation/goldens/platform_user_edit_dark_1440.png`
- `docs/reviews/2026-08-25-coelo-ui-code-review-pendencias.md`

O experimento incompleto de retorno de foco foi removido hunk a hunk de `superadmin_router.dart`, `principal_happens_preview_page.dart` e `principal_now_preview_route_test.dart`; nenhum hunk concorrente do Menu foi restaurado ou sobrescrito. O runner de golden deixou 40 imagens de feedback no diretório ignorado `apps/superadmin/test/features/people/presentation/failures/`; elas não foram lidas, copiadas, promovidas nem usadas como baseline, e não houve cleanup por determinação da coordenação.
