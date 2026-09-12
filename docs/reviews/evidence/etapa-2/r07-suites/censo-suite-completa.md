---
title: "R07 · Suítes pré-existentes (G8) — censo da suíte completa do Superadmin"
source: "flutter test apps/superadmin --reporter json -j 6 na worktree e2-r07-suites; fase0.json (grupo suites, round E2-R07-20260911); R05-fechamento.md (suíte completa 6692/53/11)"
status: "em-execucao"
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

_(preenchido ao fim da execução)_

## 4. Falhas restantes de `test/app` fora dos arquivos nomeados

_(preenchido ao fim da execução)_
