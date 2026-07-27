---
source: "specs/013-ui-packages-componentization.md; docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md"
status: "completed"
generated_at: "2026-07-24"
---

# Checkpoint — Task 15

## 1. Resultado obtido

O Superadmin passou a oferecer `Governança > Catálogo` em uma rota protegida
`/governance/catalog`. O shell é preservado e indica o destino selecionado.
Não existe `/dev/catalog`; a ação encontrada em `/dev/institutions` segue a
rota normal e, sem sessão, passa pelo guard e retorna ao login.

O host recebe somente uma origem configurada. URLs HTTP externas, credenciais,
query, fragmento, caminhos adicionais e a própria origem do Superadmin são
rejeitados. No Flutter web, o catálogo real é incorporado por iframe com
`no-referrer`, `sandbox`, título semântico e abertura externa com
`noopener,noreferrer`. Plataformas sem embedding exibem fallback.

O catálogo continua uma aplicação independente. O Superadmin não importa o
registry, `apps/catalog`, `package:coelo_catalog` ou
`coelo_ui_principal`.

## 2. Arquivos alterados

- `apps/superadmin/lib/app/router/superadmin_routes.dart`
- `apps/superadmin/lib/app/router/superadmin_router.dart`
- `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- `apps/superadmin/lib/features/catalog/presentation/catalog_host_page.dart`
- `apps/superadmin/lib/features/catalog/presentation/catalog_platform_host.dart`
- `apps/superadmin/lib/features/catalog/presentation/catalog_platform_host_stub.dart`
- `apps/superadmin/lib/features/catalog/presentation/catalog_platform_host_web.dart`
- `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- testes de catálogo e router em `apps/superadmin/test/`
- `.superpowers/sdd/task-15-build-size-report.md`

## 3. Componentes criados, promovidos ou mantidos locais

- `CatalogHostPage` e o adaptador de plataforma permanecem locais ao
  Superadmin; não são componentes do Design System.
- Nenhum componente público, variante, token ou dependência foi criado.
- A navegação existente foi parametrizada por destino/callback para suportar a
  rota real sem acoplá-la ao router.

## 4. Diferença visual encontrada

A tela de instituições e seus componentes não receberam alteração visual nesta
task. O menu ganhou o item aprovado `Catálogo` em `Governança`; seus estados
expandido/recolhido reutilizam o padrão existente e os testes/goldens do shell
continuam verdes.

## 5. Testes executados

- testes focados de host, bundle e rota: 8 aprovados;
- testes focados incluindo a suíte completa do shell: 46 aprovados;
- suíte completa de router: 16 aprovados;
- `flutter analyze --no-pub`: zero issues;
- `flutter build web --no-pub --dart-define=COELO_DEV_MFA=true
  --dart-define=COELO_CATALOG_URL=http://127.0.0.1:8770`: concluído;
- `git diff --check` no escopo: sem erro;
- scanner de bundle: zero import/dependência proibida.

O build manteve 40 arquivos. O total passou de 43.804.236 para 43.907.996
bytes (+103.760; +0,237%) e `main.dart.js` passou de 3.275.257 para 3.378.670
bytes (+103.413; +3,157%). Não há alegação de redução.

## 6. Pendências

- Antes de qualquer publicação, o host/edge do catálogo deve proteger todos os
  arquivos estáticos com autenticação Coelo e enviar CSP com
  `frame-ancestors` restrito ao Superadmin. Nenhum deploy foi realizado.
- A inspeção visual integrada e a verificação ampla de light/dark, viewports,
  acessibilidade, goldens, índice e catálogo pertencem à Task 16.
- O build emitiu aviso não bloqueante sobre fonte transitiva
  `CupertinoIcons`; não há uso direto no Superadmin e nenhuma dependência foi
  adicionada.

## 7. Decisão que precisa de aprovação

Nenhuma decisão nova para concluir o código da Task 15. A configuração e
publicação da proteção host/edge continuarão bloqueadas até autorização
explícita para infraestrutura/deploy.
