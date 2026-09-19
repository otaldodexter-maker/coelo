---
name: coelo-frontend
description: Use when implementing, correcting or verifying Coelo front-end in Flutter/Dart (apps/superadmin, Principal hospedado) or Astro (apps/site).
metadata:
  status: "active"
  updated_at: "2026-09-18"
---

# Coelo Front-end (modo de construção, ADR 0045 §7)

Corrija, teste, mostre a tela. Sem recorte, evidência, handoff ou rodada.
Versão anterior em `docs/archive/skills-20260918/`.

## Onde está

- App: `apps/superadmin` (Flutter web). Principal (app das famílias) é hospedado
  nele nas rotas `/principal-*`. `apps/admin` e `apps/principal` são Etapa 4.
- Rotas: `lib/app/router/superadmin_router.dart`; menu: `lib/app/navigation/superadmin_navigation.dart`;
  shell: `lib/app/shell/superadmin_shell.dart`; features: `lib/features/<módulo>/`.
- UI compartilhada: `packages/coelo_ui_core`, `packages/coelo_ui_admin` (tokens, temas, Directory, Flyout, Table). Use `coelo-ui` para componente novo.

## Como rodar e testar

- `flutter run -d chrome --web-port 3014` em `apps/superadmin` (produção real; login QA em `Coelo-backups`).
- `flutter test` (widget) e `flutter analyze` antes do commit.
- Golden vermelha: a tela atual é a referência. `flutter test --update-goldens <arquivo>` e siga.
- Ambiente `/dev/*` é mock; não vale como prova de produção.

## Regras que não mudam

- O cliente só pede e renderiza; autorização, tenant e regra de negócio são do servidor.
- Erro de versão defasada chega como `PT409` (ou `SAI_CONCURRENT_CHANGE`): mostrar conflito com "Recarregar", nunca o erro genérico.
- Nenhum segredo, CPF ou dado de criança em bundle, asset, URL ou log.
- Shell aceita só identidade interna; conta só de responsável não abre tela.
- Responsivo: 375, 600 e 1440 sem estouro horizontal; teclado e semântica nos controles.
- Tour: texto só em `apps/superadmin/lib/app/tour/` (menu em `superadmin_menu_tour_steps.dart`, telas em `screens/<destino>_tour.dart`, registro em `superadmin_screen_tours.dart`); componente compartilhado leva `CoeloTourAnchor` com id genérico (`directory.*`, `form.*`, `page.*`) uma vez só; a tela só envolve o que é específico dela. Todo destino roteado novo entra no registro ou em `superadminScreenTourExclusions` com motivo (teste cobra).
- Tokens pelo contexto: `context.coeloScrim`, `context.coeloStatusColors`,
  `context.coeloActionColors`, `context.coeloVisualColors`,
  `context.coeloOnMediaColors` (texto/ícone/véu SOBRE mídia: `foreground`,
  `foregroundMuted`, `foregroundSubtle`, `scrim*`, `backdrop`; iguais no claro
  e no escuro — nunca `Colors.white/black` sobre foto) (coelo_tokens); nada de
  `Theme.of(context).extension<…>()!` nem `Colors.black54` em `barrierColor`.
  Seção de formulário: `SuperadminFormSection`/`SuperadminFormSectionHeader`
  (`shared/presentation/widgets`). CPF: `CoeloCpfInputFormatter`; telefone:
  `CoeloBrazilianPhoneInputFormatter`; CEP: `CoeloCepInputFormatter`; CNPJ:
  `CoeloCnpjInputFormatter` (o campo guarda a máscara; payload, validação e
  lookup usam `.digits()`; ao carregar um registro, `.format()`); data: `CoeloDateTimeField`
  (`pickTime: false` para só data) ou `showCoeloDateRangePicker`, nunca
  `showDatePicker` do Material.
- Header custom para o servidor (ex.: `x-coelo-surface`) vai só em `Supabase.instance.client.rest.headers`; nunca em `Supabase.initialize(headers:)`, porque as Edge Functions têm `Access-Control-Allow-Headers` fixo e o preflight de todas cai.
- Acesso contextual (ADR 0035): o cliente só reflete `access_blocked`/`access_popup` de `list_my_principal_contexts`; nunca esconde o vínculo nem decide localmente (`principal_runtime_context_route.dart`).
- Diálogo de posse da tela: `superadminDialogRoute<T>(context, builder:)` e o
  mixin `SuperadminOwnedDialogs` (`showOwnedDialog`, `pushOwnedRoute`,
  `dismissOwnedRoutes`) em `shared/presentation/widgets/superadmin_owned_dialogs.dart`;
  nunca `DialogRoute<T>(…)` cru. Só data: `CoeloDateField`. Ação destrutiva
  confirmada: `FilledButton` com `coeloDestructiveFilledButtonStyle(context)`.
- @ (Decisão 16): campo "@ da unidade/turma (opcional)"; vazio, o servidor gera
  o padrão e a nota mostra a prévia (`structure_handle_preview.dart`); na
  criação o valor viaja como `handle` no payload; na edição só "Alterar @".
- Negação com motivo (lote 91): `PT403`/`STAFF_ACCESS_DENIED` é reconhecido uma vez só, em `StaffAccessDeniedHttpClient` (o `httpClient` do `Supabase.initialize`) e publicado em `staffAccessDenied`; `StaffAccessDeniedListener` mostra o popup (raiz do app e rota do Principal). Repositório não trata esse código.
- Campos da regra de acesso (superfícies, janelas, vigência, popup) vivem em `features/staff_access/presentation/staff_access_rule_fields.dart` (`StaffAccessRuleEditor` e blocos) e são reutilizados pelo passo "Utilização do app" do perfil; não duplique.
- Comando novo numa tela com muitos fakes de teste (`implements XRepository`): não engorde a interface; crie uma interface pequena (`InstitutionLifecycleCommands`, `NoticeCtaTargetOptionsReader`, `LocationMapReader/Writer`) implementada pelo repositório Supabase e passada como parâmetro opcional — sem ela o menu/seletor some.
- Canvas que depende da posição do toque (`location_map_panel.dart`) usa `GestureDetector(excludeFromSemantics: true)`: com semântica ligada (prova por CDP, leitor de tela) o nó reduz o gesto ao centro do elemento; a alternativa acessível é a lista abaixo do canvas.
- Prova por CDP: `node Coelo-backups/etapa3-proof.cjs <fluxo> [largura] [env]` com fluxos em `etapa3-flows/`; build com `--dart-define-from-file=.env.local` (sem isso o app não inicializa o Supabase e a tela fica branca) e `MSYS_NO_PATHCONV=1` quando passar rota por variável no Git Bash.
