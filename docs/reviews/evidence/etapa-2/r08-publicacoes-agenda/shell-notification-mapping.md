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

## Gate focal adicional

A inspecao solicitada pelo C0 encontrou dois defeitos concretos no ciclo
existente, sem criar novo `action_id`:

- se `load()` terminava depois de o centro ja estar aberto, os itens remotos
  entravam como nao lidos e `read_at` nao era sincronizado;
- se a primeira gravacao de `read_at` falhava, reabrir o centro nao repetia a
  tentativa porque o estado local ja estava lido.

O feed agora registra o callback antes da leitura, sincroniza imediatamente
quando a carga termina com o centro aberto e o controlador dispara o callback
em toda transicao real de fechado para aberto. Foram preparados testes para a
corrida de carga e para falha seguida de retry. Resultado final do arquivo do
feed mais a regressao do controlador: 13/13 PASS. Analyze focal: verde.
