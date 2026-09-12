---
source: H14 decision from C0; ContextNotificationFeed composition
status: reconciled-no-new-action-id
generated_at: 2026-09-12
---

# Sino do shell — mapeamento H14

O C0 confirmou que a carga e a contagem de notificacoes remotas pertencem ao
subaceite nomeado de `shell.load`. Abrir o centro e persistir `read_at` sao
evidencias complementares do mesmo comportamento; nao criam novo `action_id`,
nao alteram o denominador e nao promovem backend/E2E para uma acao classificada
como Flutter-only.

Composicao conferida:

1. `SuperadminAuthScope` instancia `SupabaseContextNotificationRepository`.
2. O router cria `ContextNotificationFeed` sobre o
   `SuperadminActivityController` do shell.
3. `load()` preserva lido/nao lido e alimenta a contagem.
4. Ao abrir o centro, `markAllRead()` persiste `read_at` pelas policies do
   destinatario.

O teste historico `context_notification_feed_test.dart` continua valido; a R08
nao tocou esse codigo e, por isso, nao repetiu nem promoveu certificacao.
