---
title: "Handoff R06 — frente Principal, Chat e Sistema"
source: "comunicacao/principal-chat-sistema.json revs 30–32; rota real com qa-r06-principal em 11/09/2026 (20:25–21:05)"
status: "entregue ao coordenador da R06"
generated_at: "2026-09-11"
---

# Handoff R06 — Principal, Chat e Sistema

Branch `work/etapa2-r06-principal-chat-sistema` (base `origin/dev ca60b096b`), publicada em origin.

## Fechado (com prova)

- **Item 0** — `principal_real_route_test` 4/4 (`08c46b1b7`): os quatro casos falhavam porque o Acontece composto passou a exigir `principalMixedFeedRepository` (feed misto) e, desde P28, o `+` do dock publica no Acontece.
- **Item 1 (cliente)** — P47 = A (`e689033ff`): o assistente de Cardápios não falha fechado por tenant vazio; o servidor valida (`meal_plan_scope_allowed`). **Rota real**: `meal-plans.model-create` e `model-edit` criam/editam e persistem (modelo `d132698c…` published v1 → v2, reload carrega do servidor; capturas 02–08). `meal-plans.create/edit/publish`: o assistente abre e chega a *Enviar e publicar*, mas `meal_plan_create_or_update_draft` caía com `cannot extract elements from an object` porque o cliente enviava `scopeRules` como mapa e a RPC itera `jsonb_array_elements`; com a lista a gravação cai na check `meal_plans_scope_rules_array_check` (exige objeto): contrato contraditório no backend; o ajuste do cliente foi revertido e a correção é um candidato de backend (RPC deriva `meal_plan_scopes` do mapa e grava o objeto).
- **Item 2 (telas)** — V-4/V-5/V-6 reprovados → publicadores reconstruídos na **família Publicação**: `PrincipalPublicationSheet`, `PrincipalPublicationBlock`, `PrincipalPublicationNote` em `principal_shared/presentation/principal_publication_frame.dart`; rodapé em card contornado (sem blur, `Wrap` sem overflow); Acontece (`14abb3b0a`), Agora (`c7a614737`), Momentos (`e9c67d9f9`, legenda 0/220). Sem etapas, sem wizard, sem fundo cinza. Suítes 67/95/88 verdes com goldens regravados; na rota real as três telas abrem dentro do contêiner do Superadmin com a barra *Vendo como* (capturas 12, 16, 17).
- **Item 6** — P48 = A: candidato `packages/coelo_database/candidatos/principal-chat-sistema/20260911130400_internal_actor_institution_access_by_role_v1.sql` (`060d21e53`): papel de sistema `institution_reader` (só `*.read`) e sincronizador por papel interno (owner → `institution_admin`; operations → `institution_reader`; demais sem vínculo automático, revogando o que o 130000 deu). pgTAP 16/16 + regressões 22/22, 13/13, 17/17, 6/6 no descartável `coelo_pcs6_db` (clone `pg_dumpall` do espelho `coelo_baseline`).
- **Rota real extra**: `principal.for-you` e `principal.profile-view` abrem (18, 19); `errors.404` pela rota real (21).

## Aberto (primeiro gate)

- **momentos.create / agora.create / acontece.create com mídia** — gate medido: mídia entra pelo seletor (13), `save_moments_draft` 200 (rascunho `b173843d-5ea4-46d4-a913-7d177443f591`, v2), e o `PUT` presigned no R2 falha por **CORS**: `coelo-media-prod` responde 204 só para `Origin: http://localhost:3000` e 403 para `127.0.0.1:3009` (sonda OPTIONS no `upload_url`); a allowlist da `moments-media` aceita `127.0.0.1:3009` e `localhost:3000` (`prepare` 200 por sonda direta). A porta 3000 estava ocupada por outra frente. **Pedido ao coordenador (sem custo)**: acrescentar `http://127.0.0.1:3009` ao CORS do R2 (ou reservar a 3000 para esta frente).
- **meal-plans.create/edit/publish** — candidato `20260911130500` (pgTAP 9/9) corrige o contrato de `scopeRules`; falta o coordenador aplicar e esta frente reprovar pela tela; capturas 11 e 23.
- **chat.create-group (UI) / chat.attach (cliente)** — não iniciados (tempo).
- **V-1 / V-2 / V-3** (Perfil, Para você, Acontece feed) — não aplicados nesta rodada.
- **errors.403/409/500/503/retry** — só 404 provado pela rota real.
- **agora.expire** — agendador ausente (desde a R04).

## Dados sintéticos criados em produção (limpeza no fim da Etapa 2, P42)

- Modelo de cardápio `d132698c-605d-46b4-bb11-124f85563604` ("Modelo sintetico R06 editado (qa-r06-principal, pode apagar)"), publicado, instituição `d0c40000-0000-4000-8000-000000000001`.
- Rascunho de Momentos `b173843d-5ea4-46d4-a913-7d177443f591` (v3, legenda "Momento sintetico R06 (qa-r06-principal, pode apagar)"); assets `708456ae` e `24868396` preparados sem upload e `8064d199` **finalizado no R2** por sonda (prepare → PUT → finalize 200 com Origin 127.0.0.1:3009, 21:32): backend e R2 corretos, só a chamada do navegador falha (captura 24).
- Nenhum cardápio (não-modelo) criado; nenhuma chave ou segredo criado.

## Ferramentas e lições

`ferramentas/rpc.py` (sonda de RPC/Edge Function com a credencial de `qa-r06-principal` só em memória). Com a semântica ligada, o `type` do `cdp_sem` escreve no input DOM mas não no controller Flutter; funciona `clickxy` no centro do campo + `qa_drive cmd command=enter_text`; rolagem por `qa_drive cmd command=scrollIntoView finderType=ByText`; taps por `ByValueKey` para chips e botões. Descartável rápido: `docker run` da mesma imagem `supabase/postgres` + `pg_dumpall -U supabase_admin` do espelho (3 min), realinhando grants de `anon`/`app_private` e `auth.uid()` que o clone perde.
