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
