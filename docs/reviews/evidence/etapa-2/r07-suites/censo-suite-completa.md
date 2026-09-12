---
title: "R07 · Suítes pré-existentes (G8) — censo da suíte completa do Superadmin"
source: "flutter test apps/superadmin --reporter json -j 6 na worktree e2-r07-suites; fase0.json (grupo suites, round E2-R07-20260911); R05-fechamento.md (suíte completa 6692/53/11)"
status: "encerrado; execucao 2 nao realizada (sessao caiu ~00:30, retomada apos o corte so para fechar)"
generated_at: "2026-09-12"
timezone: "America/Sao_Paulo"
---

# Censo da suíte completa — Rodada 7, frente Suítes pré-existentes

Conversa: Claude Opus 5 (esforço médio), 3 h a partir de T0 23:19:34 de
11/09/2026. Base: `origin/dev` `7b229593c`; branch `work/etapa2-r07-suites`.
Sem Chrome, sem rota real, sem usuário sintético, sem deltas de estado por
`action_id`. Um `flutter test` por vez.

## 1. Censo inicial do recorte (base limpa `7b229593c`)

| Suíte | Aprovados | Falhos | Pulados | Causa por falha |
| --- | ---: | ---: | ---: | --- |
| `test/app` (inteiro) | 637 | 16 | 1 | 4 nos arquivos do recorte (abaixo); 12 em outros arquivos de `test/app` (classificados na seção 4) |
| `test/core/config` | 35 | 5 | 0 | 5 teste desatualizado |
| `test/shared` | 35 | 11 | 0 | 11 teste desatualizado |
| `institution_directory_page_golden_test` | 6 | 1 | 0 | golden defasado por decisão pendente (P53) |

Observação: o prompt citava 18 falhas em `test/app` (dev_menu,
import_development_routes, prototype_navigation_routes) e 4 em
`test/core/config`. Medido na base de hoje: `import_development_routes_test`
já passa; as falhas de `test/app` nos arquivos nomeados são 4 (3 testes + 1
golden), e `test/core/config` tem 5.

### Classificação por teste

| Arquivo · teste | Causa | Correção |
| --- | --- | --- |
| `test/app/dev_menu_test.dart` · offers the floating dev menu… | teste desatualizado: dependia de `--dart-define=COELO_APP_ENV=local` (o padrão de `allowDevelopmentPreview` foi endurecido em 25/08), o que colide com `superadmin_app_config_test` (espera `staging`) na mesma execução | liga `allowDevelopmentPreview: true` no `createSuperadminRouter`, como os demais testes de rota |
| `test/app/router/prototype_navigation_routes_test.dart` · prototype destinations navigate… | teste desatualizado: idem (`/dev` redirecionava) e, depois, seções `governance`/`principal` fora da viewport da `ListView` (navegação cresceu com Coelo (Principal)); `find.byKey` pula offstage | `allowDevelopmentPreview: true` e `skipOffstage: false` antes do `ensureVisible` |
| `test/app/dev_menu/development_dataset_contract_test.dart` · development dataset preserves… | teste desatualizado: dataset reduzido a 5 instituições em `d9232a94d` (01/09, mesmo `take(5)` dos goldens de Instituições); Maré Alta tem 28 turmas numa unidade; 12 modelos de atividade | faixas e contagens atualizadas com comentário |
| `test/app/dev_menu_overlay_test.dart` · matches the approved open preview menu (golden 0,61%) | golden defasado: ainda tinha "Modelos de perfil", unificado em Perfis e permissões em `320a6f09f` (01/09) | regravado (`--update-goldens`), diferença conferida na imagem: só o item removido |
| `test/core/config/person_detail_composition_test.dart` · configured scope… | teste desatualizado: `structureMutationsEnabled` ligada na composição de produção em `58bfe1fed` (ADR 0034) | espera `isTrue` |
| `test/core/config/structure_detail_composition_test.dart` · configured composition… | idem: diretórios de Unidades/Turmas saíram de `Unavailable` para Supabase (13 RPCs em `20260910160000`) | espera os adapters Supabase e mutações ligadas; título do teste atualizado |
| `test/core/config/unit_fail_closed_composition_source_test.dart` · 2 testes | idem: o auth scope constrói `SupabaseUnitDirectoryRepository`/`SupabaseUnitBackendCommandsGateway`; o router passa `backendCommands: hasStructureMutationCapability() ? unitBackendCommands : null` | teste de fonte passa a exigir que só o auth scope configurado construa os adapters (app e router mantêm o padrão indisponível e o scope sem configuração segue fail-closed) |
| `test/core/config/superadmin_auth_scope_test.dart` · initializes Supabase… | idem: `personIdentityRepository` real desde 170700 em produção (`7f13ee42d`, lote 54) | espera `SupabasePersonIdentityRepository` |
| `test/shared/…/superadmin_underline_tabs_test.dart` · 9 testes | teste desatualizado: chave renomeada ao mover o widget para `coelo_ui_admin` (`coelo-admin-underline-tab-*`) | chaves substituídas; 11/11 |
| `test/shared/…/superadmin_form_action_footer_adoption_test.dart` · 2 testes | teste desatualizado: Agenda (`0322e511d`) e publicadores do Principal (`14abb3b0a`) foram reconstruídos na família Publicação; `PublicationSurface` embute o `SuperadminFormActionFooter` e o Principal usa `PrincipalPublicationActionFooter` (referências aprovadas pelo Owner em 11/09); cinco candidatos novos eram falsos positivos do regex (classe de dados, páginas de operação de Formulários, edição de perfil do Principal); um é lacuna real (abaixo) | regra de rodapé canônico por composição; lista de wrappers sem rodapé atualizada e comentada |
| `institution_directory_page_golden_test` · matches disabled pagination references (2 goldens, 0,21%) | golden defasado pelo launcher do chat ("Mens." → "Mensagens"), mesma causa de P53, que ficou sem resposta (= B, registrar) | **não regravado**; registrado para o Owner/estrutura |

## 2. Fora do recorte (registrado, não corrigido)

- **Criar modelo de atividade** (`_ActivityTemplateCreatePage`,
  `lib/features/activities/presentation/activity_directory_page.dart`
  ~1239–1262) usa `Wrap` de `OutlinedButton`/`FilledButton` em vez do
  `SuperadminFormActionFooter` ancorado (P15/P34). Dono sugerido: frente
  Estrutura. Prova: remover a linha desse arquivo da lista esperada em
  `superadmin_form_action_footer_adoption_test` e rodar `test/shared`.
- **Goldens de paginação de Instituições** (`pagination_disabled` e
  `pagination_page_size_open`, 1440 claro): só o launcher difere. Quando P53
  = A, regravar junto com os 9 de `activity_golden_test` num único commit.

## 3. Censo da suíte completa

Execução 1 (00:03–00:13 de 12/09, `flutter test --reporter json -j 6`, HEAD
`bc93f4b6c` = base + correções das seções 1–2): **6713 aprovados / 42 falhos /
11 pulados** (R05: 6692 / 53 / 11). Por diretório:

| Diretório | Aprovados | Falhos | Pulados |
|---|---:|---:|---:|
| `test/app` (raiz) | 17 | 0 | 0 |
| `test/app/activity` | 11 | 0 | 0 |
| `test/app/dev_menu` | 29 | 0 | 0 |
| `test/app/navigation` | 24 | 0 | 0 |
| `test/app/prototype` | 3 | 0 | 0 |
| `test/app/router` | 428 | 12 | 1 |
| `test/app/shell` | 127 | 0 | 0 |
| `test/app/widgets` | 2 | 0 | 0 |
| `test/architecture` | 2 | 0 | 0 |
| `test/contracts` | 13 | 1 | 0 |
| `test/core/config` | 40 | 0 | 0 |
| `test/core/guards` | 12 | 0 | 0 |
| `test/core/isolates` | 1 | 0 | 0 |
| `test/features` (raiz) | 10 | 0 | 0 |
| `test/features/access_profiles` | 298 | 0 | 0 |
| `test/features/account` | 124 | 0 | 0 |
| `test/features/activities` | 346 | 9 | 0 |
| `test/features/agenda` | 291 | 0 | 0 |
| `test/features/assessments` | 42 | 0 | 0 |
| `test/features/attendance` | 86 | 3 | 0 |
| `test/features/audit` | 62 | 0 | 0 |
| `test/features/auth` | 194 | 0 | 2 |
| `test/features/catalog` | 6 | 0 | 0 |
| `test/features/chat` | 212 | 0 | 0 |
| `test/features/children` | 38 | 0 | 0 |
| `test/features/circulars` | 68 | 0 | 0 |
| `test/features/daily_routine` | 113 | 0 | 4 |
| `test/features/errors` | 37 | 0 | 0 |
| `test/features/forms` | 828 | 0 | 1 |
| `test/features/groups` | 167 | 0 | 0 |
| `test/features/health_care` | 204 | 1 | 2 |
| `test/features/help_center` | 12 | 1 | 0 |
| `test/features/imports` | 36 | 0 | 1 |
| `test/features/institutions` | 223 | 1 | 0 |
| `test/features/invites` | 93 | 1 | 0 |
| `test/features/locations` | 464 | 0 | 0 |
| `test/features/meal_plans` | 137 | 0 | 0 |
| `test/features/notices` | 135 | 0 | 0 |
| `test/features/people` | 224 | 2 | 0 |
| `test/features/plans` | 45 | 0 | 0 |
| `test/features/platform_users` | 104 | 1 | 0 |
| `test/features/principal_chat` | 29 | 0 | 0 |
| `test/features/principal_circulars` | 103 | 10 | 0 |
| `test/features/principal_for_you` | 97 | 0 | 0 |
| `test/features/principal_happens` | 91 | 0 | 0 |
| `test/features/principal_happens_publication` | 67 | 0 | 0 |
| `test/features/principal_moments` | 62 | 0 | 0 |
| `test/features/principal_moments_publication` | 88 | 0 | 0 |
| `test/features/principal_now` | 59 | 0 | 0 |
| `test/features/principal_now_publication` | 95 | 0 | 0 |
| `test/features/principal_profile` | 137 | 0 | 0 |
| `test/features/principal_shared` | 19 | 0 | 0 |
| `test/features/profile_about` | 31 | 0 | 0 |
| `test/features/safety` | 174 | 0 | 0 |
| `test/features/student_tracking` | 41 | 0 | 0 |
| `test/features/students` | 15 | 0 | 0 |
| `test/features/support` | 70 | 0 | 0 |
| `test/features/units` | 179 | 0 | 0 |
| `test/shared/presentation` | 46 | 0 | 0 |
| `test/support` | 2 | 0 | 0 |
| **Total** | **6713** | **42** | **11** |

Contagem por teste (`testDone` não oculto, sem `loading`/`setUpAll`/
`tearDownAll`); o log JSON bruto fica fora do Git (`%TEMP%/r07-censo.json`).

Depois do censo, mais 6 falhas de `test/app/router` foram corrigidas (seção 4)
e provadas isoladamente; a execução 2 da suíte completa **não aconteceu**: a
sessão caiu por volta de 00:30 e só foi retomada às 09:20, depois do corte
(T0+3h10). Número esperado com as 6 correções: 6719 aprovados / 36 falhos /
11 pulados — a confirmar por quem integrar (`flutter test apps/superadmin`).

## 4. As 42 falhas do censo, por causa e dono sugerido

### Corrigidas nesta frente depois do censo (6, todas em `test/app/router`, só teste)

| Teste | Causa | Correção |
| --- | --- | --- |
| `person_identity_fail_closed_routes_test` · composition roots never import… | teste desatualizado: auth scope compõe `SupabasePersonIdentityRepository` atrás de `enablePersonHandles` (170700 em produção) | exige que só o auth scope configurado construa o adapter |
| `people_creation_requirements_red_test` | teste desatualizado: `people.create` abre quando o repositório de Pessoas está composto (`2891e6977`) | dois testes: bloqueado sem repositório; busca de identidade em produção e em `/dev` com repositório |
| `superadmin_error_routes_test` · unavailable /profile… | teste desatualizado: `/profile` abre a Conta com estado próprio desde `ce4939227` (P43/P53 da R06) | rota removida da lista de 503 |
| `persistent_shell_routes_test` · propagates the activity footer inset… | teste desatualizado: Decisão 7 tira o balão de chat de criar/editar | passa a exigir launcher ausente sobre o rodapé |
| `persistent_shell_routes_test` · keeps standalone Principal bounds… | teste desatualizado: publicadores sem etapas (`happens-publication-scroll`, `now-publication-scroll`) e Momentos em moldura a partir de 840 | chaves novas; tela cheia só até 768 |
| `principal_moments_publication_route_test` | teste desatualizado: `PrincipalPublicationFrame`/`StepNavigation` deram lugar a `PrincipalPublicationSheet` | componentes atualizados |

Aviso ao coordenador: os três últimos tocam telas do Principal (frente G4);
se a G4 alterar os mesmos testes na R07, integrar por conteúdo.

### Permanecem (36) — fora do recorte desta frente

| Testes | Causa medida | Dono sugerido |
| --- | --- | --- |
| `activity_golden_test` (9) | launcher "Mensagens" (P53 = B) | Owner (P53) / Estrutura |
| `institution_directory_page_golden_test` · pagination (1 teste, 2 goldens) | idem | Owner (P53) / Estrutura |
| `structure_detail_golden_test` (4: unit/group 375 claro e 1440 escuro) | sino do shell (R06), item ativo do menu no escuro (MENU, Fase 0) e launcher (P53); imagem conferida | Estrutura, depois de P53 |
| `person_detail_golden_test` (2: 375 claro, 1440 escuro) | mesma causa (shell) | Acessos e Pessoas, depois de P53 |
| `test/contracts/rpc_contract_test` (1) | `create_unit_for_superadmin`, `update_unit_for_superadmin`, `get_unit_form_for_superadmin`, `list_units_for_superadmin`, `unit_directory_filter_options` passaram a existir no pacote: remover de `_rpcsAusentesConhecidas` (a mensagem do teste já diz isso) | coordenação (correção de uma linha, fora do meu recorte) |
| `attendance_pages_golden_test` (3: compact footer 375 claro/escuro 3,7%; new call marking 1440 escuro 0,14%) | imagem conferida: no compacto 375 mudou o bloco "Sentimento" (rótulos, "Ver mais" e aviso "não está disponível nesta etapa" reposicionados); no 1440 escuro só o item ativo "Chamada" do submenu (MENU) | Formulários, Cuidado e Rotina |
| `medication_plan_ui_contract_test` (1) | **defeito de layout**: `RenderFlex overflowed by 23 pixels` na `Column` de `superadmin_form_frame.dart:37` a 375 px e 200% (o tap em "Selecionar data" cai fora) | Formulários, Cuidado e Rotina (`lib/shared/presentation`) |
| `superadmin_help_center_page_golden_test` (1 teste, 2 goldens: empty 1440 claro 4,52% e 375 escuro) | imagem conferida: estados do menu (Home ativo/hover), bloco de texto do cabeçalho e o campo "Perguntar sobre o Coelo" com botão de enviar no rodapé — mudança de conteúdo da Central de ajuda, não ruído | Operações |
| `invite_golden_test` (1: invite_form_mobile_light, 9,67%) | imagem conferida: rodapé Criar/Cancelar saiu do fim do conteúdo e ficou ancorado no fim da viewport (P15) | Acessos e Pessoas |
| `person_form_page_test` · keeps the canonical footer after the compact scroll region (1) | espera respiro 24 e mede 40 (`space10` do P15) — teste desatualizado | Acessos e Pessoas |
| `person_golden_test` (1: person_form_create_light_375, 5,33%) | imagem conferida: rodapé ancorado (P15) e campos de "Endereço local" deslocados | Acessos e Pessoas |
| `platform_user_pages_golden_test` (1: platform_user_create_light_375, 9,44%) | imagem conferida: rodapé ancorado (P15) | Acessos e Pessoas |
| `principal_circular_golden_test` (10: composer 375/768/1024/1440 claro e escuro + 200%) | Circular reconstruída na família Publicação (R06, G6) sem regravar os goldens do composer do Principal | Publicações e Agenda |
