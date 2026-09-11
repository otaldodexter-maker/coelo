---
title: "Deltas propostos às skills — R06 publicacoes-agenda"
source: "comunicacao/publicacoes-agenda.json rev 44–48; branch work/etapa2-r06-publicacoes-agenda"
status: "proposta ao coordenador (escritor central das skills)"
generated_at: "2026-09-11"
---

## coelo-backend

- **Edge Functions e o preflight do supabase_flutter:** `functions.invoke` envia `X-Client-Info`; o navegador pede `apikey, authorization, content-type, x-client-info` no `Access-Control-Request-Headers`. Função cujo `Access-Control-Allow-Headers` não lista `x-client-info` responde OPTIONS 200 e o POST morre com `net::ERR_FAILED` (nenhuma linha no servidor). Provas por script Node/Deno não pegam isso; só a rota real no navegador. `circular-media` corrigida em `b2e61a22e`; `chat-media`, `moments-media`, `happens-media` e `now-media` têm a mesma lista.
- **Origens locais:** as `*_MEDIA_ALLOWED_ORIGINS` só têm `localhost/127.0.0.1` nas portas 3000/3009/3014/3020; servir o build de QA numa porta fora da lista dá `403 origin_not_allowed` no preflight. Usar uma porta da lista em vez de regravar o secret compartilhado.

## coelo-frontend

- **Família Publicação vive uma vez** em `apps/superadmin/lib/shared/presentation/widgets/publication_surface.dart` (`PublicationSurface`, `PublicationLabel`, `PublicationTextField`, `PublicationCard`, `PublicationRow`, `PublicationChip`, `PublicationToggleRow`, `PublicationNote`, `PublicationPreviewPanel`): título "Sua publicação" + subtítulo da ação, prévia à direita a partir de 1200 px, rodapé `SuperadminFormActionFooter` em card (empilhado no mobile com a primária primeiro). Circular e Evento já a consomem; Agora/Acontece/Momentos/Lançar chamada devem consumir em vez de reimplementar.
- **Bordas de card sobre `ColoredBox`:** `Ink` pinta no `Material` ancestral, que fica *abaixo* do `ColoredBox` da superfície; cards contornados usam `Container` (decoração) com `Material` transparente por dentro para o ripple.
- **Capacidade composta que não chega ao host** é um gate silencioso: `SupabaseCircularMediaRepository` existia no auth scope desde a R04, mas o router nunca o passava aos hosts do compositor; a UI respondia "Envio de anexos indisponível" e a prova por RPC mascarou isso por duas rodadas. Ao declarar "backend done, falta a tela", conferir o parâmetro no `GoRoute`.
- **Decisão 7 por rota:** `AgendaModuleShell` ganhou `showChatLauncher`; criar/editar evento passam `false` (o balão cobria "Publicar evento" no 1440).
- **Rota real:** driver `tap` por `ByValueKey` funciona no build profile com `set_frame_sync false`; `tap` por `ByText` num rótulo de campo (`Local (opcional)`) trava o driver — clicar por coordenada (CDP) e digitar com `enter_text`.

## coelo-frontend-backend

- `agenda.location` e `circulars.respond` chegaram a E2E na R06 pela régua do MVP (rota real com `qa-r06-publicacoes`, CRUD em produção, RLS em pgTAP, reload).
- `circulars.attach` fica `local-green` no FE até o deploy da `circular-media` (o gancho do `qa_main` chegou ao `prepare`).
- Sino do shell: `context_notification_recipients` (own_read/own_update em `read_at`) + `context_notification_events` (recipient_read) já bastam para leitura e marcação sem RPC nova; a composição entra em `SuperadminAuthScope.contextNotificationRepository`.
