---
source: "Sessão 7 da R14 (Opus 5), 16/09/2026; briefing comum R14; inventario-etapa-2.json (momentos.*)"
status: evidence
generated_at: 2026-09-16
---

# Momentos (`momentos.view`, `momentos.publish`, `momentos.remove`, `momentos.create`) — fatia não executada, 16/09/2026

## Resultado

Nenhum estado alterado. A fatia não pôde começar pela rota real porque o PostgREST de produção
ficou sem responder a qualquer chamada que toque o banco (REST e Edge) das 12:35 até pelo menos
14:02 (BRT) — mais de 85 minutos, 60+ sondagens a cada 30–70 s com `list_my_principal_contexts`
pela identidade `qa-r06-publicacoes`. Sintomas: `504 upstream request timeout`, depois
`504 PGRST003 Timed out acquiring connection from connection pool`, depois requisições sem
resposta (timeout do cliente a 25–40 s); `GET /rest/v1/` sem banco responde `401` em 60 ms; Auth
(`/auth/v1/token`) responde normalmente; Management API reporta o projeto `ACTIVE_HEALTHY`.
Fechar o Chrome da sessão não alterou o quadro. A leitura de `pg_stat_activity`/locks para
diagnóstico (`supabase db query`, `supabase inspect db locks`) foi negada pelo classificador de
permissões da sessão. Bloqueio classificado: **ambiente (PostgREST de produção sem pool)**.

## O que foi verificado antes do incidente (vale para a retomada)

- O bloqueio histórico de `momentos.create` (`blocked-environment`: preflight `OPTIONS` do
  `upload_url`/Edge `happens-media` com origem `3016` não permitida, Principal-pos-R10) **não se
  aplica na origem `127.0.0.1:3020`**: `OPTIONS https://<projeto>/functions/v1/moments-media` com
  `Origin: http://127.0.0.1:3020` → `200` + `Access-Control-Allow-Origin: http://127.0.0.1:3020`
  (mesmo resultado para `3000`, `3009`, `3014`; `3018` → `403`). O `PUT` presignado no R2 respondeu
  `OPTIONS 204` + `PUT 200` a partir dessa origem no fluxo do Agora (`now-media`), que usa o mesmo
  bucket/transporte que `moments-media`.
- Rota real disponível: `/principal-moments/publish` (publicador com chips de audiência
  Famílias/Alunos/Equipe escolar/Somente responsáveis — ao contrário do Agora, permite escolher
  `Equipe escolar`, visível ao leitor `owner`) e `/principal-moments` (feed com `Retirar momento`
  para o autor via `can_withdraw` do servidor).
- Negativas planejadas por PostgREST: `save_moments_draft` com `institution_id …0099`;
  `list_visible_moments(…0099)`; `withdraw_moment` de publicação alheia pela identidade leitora
  (não autora) → esperado `403`; `moments-media read` com `asset_id` alheio.

## Roteiro para a retomada (mesmo build, mesma origem 3020)

1. Login `qa-r06-publicacoes` → `/principal-moments/publish` → PNG real 64×64 pelo
   `cdp_filechooser.dart` → legenda `R14 S7 Momento QA` → chips Famílias + Equipe escolar →
   Publicar → feed com o momento → reload.
2. Login `qa-r06-principal` → `/principal-moments` → momento visível com mídia R2 → reload
   (`momentos.view`); `Retirar momento` ausente para não autor.
3. Login `qa-r06-publicacoes` → `Retirar momento` → confirmar → some do feed → reload →
   `withdraw_moment` 200 e `list_visible_moments` sem o item (`momentos.remove`).
4. Negativas acima; se tudo passar, `momentos.create` sai de `blocked-environment`.

## Separação FE / BE / E2E

Nada certificado nesta sessão; estados permanecem os do corte de 16/09.
