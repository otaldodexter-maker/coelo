---
title: "R15 — auth.recover entregue em produção; MFA fora do MVP (ADR 0042 E8/E9)"
source: "Owner em 16/09/2026 (sessão coordenadora); decisions/0042-r14-closure-r15-opening-20260916.md; auth.users em produção (leitura D1)"
status: "evidence"
lifecycle: "current"
generated_at: 2026-09-16
audience: "team"
---

# auth.recover em produção e decisões E8/E9

## auth.recover — backend provado em produção (16/09/2026)

- Pedido pela API pública de Auth (mesma chamada da tela `/recover`):
  `POST /auth/v1/recover` com a chave pública e o e-mail do Owner
  (`adrieldasbc@live.com`, usuário `b06025c3…`, confirmado) → `HTTP 200`
  às 17:47:44 e novamente às 17:52:10 BRT.
- Persistência: `auth.users.recovery_sent_at` passou de `null` para
  `2026-09-16 20:47:44+00` (leitura por `supabase db query --linked`).
- Entrega real: o Owner recebeu "Reset your password" de
  `Supabase Auth <noreply@mail.app.supabase.io>` às 18:47 e 18:52 (capturas
  fornecidas pelo Owner no chat; link não registrado). Nenhum token ou link
  consta desta evidência.
- Limites observados: o e-mail padrão do Supabase não permite template
  personalizado no plano gratuito (`400 Email template modification is not
  available for free tier projects using the default email provider`);
  assunto/corpo/remetente "Coelo" exigem SMTP próprio. O template pt-BR ficou
  pronto em `packages/coelo_database/supabase/templates/recovery.html` para
  a Etapa 3.
- Allowlist de redirect em produção: `http://127.0.0.1:8765/reset-password` e
  `https://superadmin.coelo.me/reset-password`; o push mínimo que adiciona
  `http://127.0.0.1:*` e `http://localhost:*` está preparado
  (scratchpad `auth-redirect/supabase/config.toml`) e depende do Owner.

## Separação FE / BE / E2E

- FE: `verified` histórico (R11) — mantido.
- BE: `done` — entrega em produção comprovada acima.
- E2E: `pending-verification` — a prova pela tela (pedir na rota `/recover`
  do app QA, receber, abrir o link em `/reset-password` no app local, definir a
  senha nova e entrar) entra no Bloco A da R15 com a caixa do Owner (E8).
  `auth.reset` permanece FE verified / BE pending / E2E pending até essa prova.

## Decisões do Owner (16/09, registradas na ADR 0042)

- **E8**: reset de senha fica no MVP e é provado com a caixa do Owner; SMTP
  próprio (remetente/assunto/corpo Coelo) vai para a **Etapa 3**.
- **E9**: MFA **não** entra no MVP: `auth.mfa`, `account.mfa` e
  `internal-users.mfa` → `deferred-post-mvp` (BE e E2E; FE preservado). O
  denominador E2E ativo passa de 186 para 183.
