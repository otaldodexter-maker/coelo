---
source: "Sessão A da R15 (Fable 5.1), 17/09/2026; R15-pendencias.md (ordem 8, E8); owner.r12-47; r15-coordenacao/auth-recover-mfa-decisoes-20260916.md (auth.recover BE done, allowlist 127.0.0.1:8765/reset-password); decisão do Owner de 17/09 relatada pela coordenadora (ADR 0042 E10)"
status: evidence
generated_at: 2026-09-17
---

# Auth › Recuperar senha (`auth.recover`) e › Redefinir senha (`auth.reset`; owner.r12-47) — rota real, 17/09/2026

Ambiente: produção (`evvbomzejfijozbtgvpt`); build QA `ab96072de` servido também em `127.0.0.1:8765`
(origem cuja `http://127.0.0.1:8765/reset-password` já está na allowlist de redirect do Auth, evidência de
16/09); Chrome CDP 9414, tema escuro (sessão anônima). Nenhum link, token ou conteúdo de e-mail foi
registrado. Capturas em `capturas/auth-recover-*.png`.

| action_id | Rota normal | Backend em produção | Reload / repetição | Negativa |
|---|---|---|---|---|
| auth.recover | `/login` → "Esqueci minha senha" → `/forgot-password` "Recupere seu acesso" → e-mail do Owner (`adrieldasbc@live.com`, caixa do Owner) → "Enviar link de recuperação" (17:43:45Z) → tela "**Confira seu e-mail** · Se existir uma conta associada a este e-mail, enviaremos as instruções para redefinir a senha." com "Voltar para entrar" e "Reenviar e-mail" (00). | `POST /auth/v1/recover` → **200** (rede da página, sem cabeçalhos), com `redirectTo` construído pelo app a partir da origem (`http://127.0.0.1:8765/reset-password`, na allowlist). Confirmação por leitura D1 da coordenação (só leitura): `auth.users.recovery_sent_at = 2026-09-17 17:43:40Z` para a conta do Owner (bate com o POST da tela às 17:43:45Z); para o e-mail inexistente, **0 linhas criadas**. Entrega real do e-mail (SMTP do Supabase) já provada em 16/09 (`auth.recover` BE done). | "Reenviar e-mail" disponível na mesma tela; nova visita a `/forgot-password` volta ao formulário vazio (validação "Informe seu e-mail." ao enviar em branco). | E-mail inexistente (`nao-existe-r15a-9f3c@coelo.me`, 17:46:45Z) → **mesma tela "Confira seu e-mail"** (01) e `POST /auth/v1/recover` → `200 {}` também por chamada direta (0,1 s): **sem enumeração** de contas. |
| auth.reset | Não executado pela caixa de e-mail: o Owner decidiu em 17/09 (relato da coordenadora, ADR 0042 E10) **não fazer hoje a prova da caixa** ("considere como correto; verificamos no detalhe na Etapa 3"). A rota `/reset-password` existe no app, valida o token de recuperação da URL (`superadminPasswordRecoveryAccessToken`) e o build está servido na origem da allowlist; a prova de link real, senha nova, nova sessão e uso único fica para a Etapa 3 junto do SMTP próprio. | Contrato de Auth do Supabase (recovery → `access_token` de tipo recovery → `PUT /auth/v1/user`), sem RPC própria. FE `verified` desde a R02 (36 TAP + 9 HTTP + 1 cold, `9e7e23f18`). | — | — |

## owner.r12-47

- Provado hoje: pedido normal pela tela com o e-mail do Owner (200, mensagem sem enumeração) e endereço
  inexistente (200, mesma tela); redirect local dentro da allowlist (8765); nenhum link/token registrado.
- Aceito por decisão do Owner (17/09, E10): redefinição real pela caixa, nova sessão, expiração e uso único →
  verificação detalhada na Etapa 3 (SMTP próprio). Credenciais QA preservadas; a senha do Owner não foi
  alterada.
