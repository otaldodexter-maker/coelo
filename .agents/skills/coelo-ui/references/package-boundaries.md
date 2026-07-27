---
source: "specs/013-ui-packages-componentization.md"
status: "active"
generated_at: "2026-07-24"
---

# Fronteiras de pacote

Usar `ownerPackage` do índice como fonte primária. Confirmar no código antes de
alterar uma fronteira.

- `coelo_tokens`: decisões visuais semânticas recorrentes; não tokenizar todo
  número técnico.
- `coelo_ui_core`: Flutter visual neutro, sem domínio, repository, rota,
  permissão ou ViewModel.
- `coelo_ui_admin`: padrões compartilhados por Admin e Superadmin.
- `coelo_ui_superadmin`: visual exclusivo do Superadmin.
- `coelo_ui_principal`: visual exclusivo do Principal. Nunca importar
  componentes administrativos.
- App/feature: composição de domínio, comportamento experimental e contratos
  acoplados à entidade permanecem locais.
- Astro futuro: `coelo_ui_web` e CSS derivados da futura fonte neutra. Nunca
  importar widget Flutter, Dart compilado ou cópia visual falsa.

Componente visual genérico já aprovado pode ser promovido sem segundo
consumidor. Componente especulativo permanece local. Não criar package vazio.

Ao tocar navegação, contexto, autoria ou chat do Principal, ler
`decisions/0012-contextual-experiences-and-conversation-history.md` e
`docs/contexts/principal-context.md`.
