---
title: "Perfis oficiais do Coelo seguidos automaticamente no Principal (OQ-032)"
source: "docs/open-questions.md (OQ-032, 2026-09-14); ADR 0034 P35 (handle `coelo` reservado; pessoa técnica Coelo `c0e10000-…0001`); decisions/0037-* (Principal hospedado); dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.follow_links (gatilho global de follows), public.people, public.person_handles, reserved_handles (`coelo`, `coelo.me`)"
status: "draft-for-review"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Perfis oficiais do Coelo seguidos automaticamente

Spec **sem prova**; a lista final é decisão do Owner **antes de fechar o
MVP** (OQ-032). Fixa o contrato para que a escolha vire só carga de catálogo.

## Comportamento

1. Todo usuário do Principal segue automaticamente os **perfis oficiais**
   ativos no catálogo (3 a 7; hoje existe só `coelo`). O follow automático é
   criado na ativação da conta e ao ativar um perfil oficial novo (job
   server-side idempotente); somando **1 a 4 publicações por dia** entre eles.
2. O usuário **não pode deixar de seguir** o perfil `Coelo` (novidades do app,
   avisos de versão); pode deixar de seguir os demais (proposta; Owner decide).
3. Quem publica: equipe Coelo pelo **Superadmin**, com perfil de conta de
   serviço (uma pessoa técnica por perfil oficial, como a pessoa técnica
   Coelo já existente), auditado.
4. Conteúdo entra como **Acontece** (post do perfil oficial no feed misto),
   sem tipo novo; Momentos e Agora continuam institucionais.

## Lista proposta (Owner escolhe de 3 a 7)

1. Coelo — novidades, dicas, versões (existe; obrigatório).
2. Coelo Alimentação — lanches, cardápios, alergias, rotina alimentar.
3. Coelo Educa — desenvolvimento infantil, limites, sono, telas.
4. Coelo Escola — comunicação escola–família, calendário, adaptação.
5. Coelo Cuidado — saúde e segurança infantil, primeiros socorros, medicação.
6. Coelo Brincar — atividades, brincadeiras e passeios por faixa etária.
7. Coelo Famílias — histórias, rotina dos responsáveis, bem-estar.

## Modelo (esboço, forward-only)

- `public.official_profiles`: `person_id` (pessoa técnica), `handle`
  (reservado em `reserved_handles`), `display_name`, `description`,
  `mandatory boolean` (só Coelo), `status`, `sort_order`, `posts_per_day_target`.
- `follow_links` ganha `origin` (`user`|`official_auto`) para o job não
  recriar follow removido pelo usuário (quando permitido) e para métricas.
- Job `app_private.official_profiles_backfill_follows_v1()` (pg_cron, idempotente).
- Publicação: `superadmin_official_profile_publish_v1(p_request_id,
  p_profile_id, p_payload)` no contexto interno (`platform.content.publish`,
  permissão nova no catálogo), reaproveitando o pipeline do Acontece com
  audiência "todos os seguidores".

## Aceite (futuro recorte)

pgTAP: conta nova segue todos os oficiais ativos; ativar oficial novo faz
backfill; `Coelo` não pode ser desseguido; publicação só por permissão de
plataforma; FE Principal: feed "Para você" com posts oficiais e reload; Superadmin
publica pelo perfil de serviço.

## Decisões pendentes do Owner

Lista final (3–7), possibilidade de deixar de seguir os não obrigatórios,
frequência por perfil e se algum conteúdo entra como Momentos.
