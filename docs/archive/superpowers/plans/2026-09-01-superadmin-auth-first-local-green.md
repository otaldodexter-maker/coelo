---
source: "docs/superpowers/specs/2026-09-01-superadmin-auth-first-local-green-design.md; pacote de 6 horas autorizado pelo usuario"
status: "in-progress"
generated_at: "2026-09-01"
---

# Plano de implementacao Auth-first local

> Executar por TDD, preservar AAL2 fail-closed e nunca mutar o remoto.

**Objetivo:** produzir evidencia `local-green` do lifecycle Auth e conectar de
verdade Login, Recuperacao e Redefinicao de senha ao Supabase local.

**Arquitetura:** ampliar `coelo_auth` como boundary unico do SDK, conservar o
dominio Flutter injetavel e fazer o router distinguir sessao comum de sessao de
recovery. Reusar a fundacao SQL interna da spec 039 e alterar somente objetos
Auth diretamente necessarios.

## 1. Baseline e REDs

- Rodar as suites atuais de `packages/coelo_auth`, Auth do Superadmin e lifecycle
  local, registrando falhas externas sem mascara-las.
- Adicionar primeiro testes que exijam redirect explicito, evento de recovery,
  update de senha, sign-out pos-reset, callback invalido e wiring produtivo.
- Executar cada teste novo e confirmar a falha esperada antes de editar codigo
  de producao.

## 2. Contrato compartilhado Auth

**Arquivos:**

- `packages/coelo_auth/lib/src/coelo_auth_gateway.dart`
- `packages/coelo_auth/lib/src/supabase_coelo_auth_gateway.dart`
- `packages/coelo_auth/test/coelo_auth_gateway_test.dart`

Implementar resultado tipado de recovery, estado do callback e redefinicao.
`resetPasswordForEmail` recebe redirect calculado pelo composition root;
`onAuthStateChange` preserva o evento `passwordRecovery`; `updateUser` troca a
senha e `signOut` encerra a sessao temporaria. Todo erro vira codigo/mensagem
estavel sem detalhe sensivel.

## 3. Composition root, sessao e router

**Arquivos:**

- `apps/superadmin/lib/core/config/superadmin_auth_scope.dart`
- `apps/superadmin/lib/core/guards/superadmin_session.dart`
- `apps/superadmin/lib/app/superadmin_app.dart`
- `apps/superadmin/lib/app/router/superadmin_router.dart`
- testes correspondentes em `apps/superadmin/test/`

Injetar a acao real de reset e o estado de recovery. Permitir
`/reset-password` somente durante recovery valida ou enquanto o callback esta
sendo processado; sessoes comuns continuam direcionadas a `/`. Ao concluir,
limpar a sessao e navegar ao Login.

## 4. Telas Auth

**Arquivos:** manter os widgets atuais em
`apps/superadmin/lib/features/auth/**` e seus testes/goldens.

Conectar os estados existentes sem redesenho. Cobrir login valido/invalido,
pedido neutro, callback processando/valido/invalido, reset real, duplo envio,
sucesso e retorno ao Login. Executar a matriz responsiva e os goldens sem
atualizacao automatica de baseline.

## 5. Lifecycle real e autorizacao backend

**Arquivos:**

- `packages/coelo_database/scripts/Test-LocalAuthLifecycle.ps1`
- `packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql`
- migration Auth nova somente se um RED provar lacuna real
- `packages/coelo_database/supabase/config.toml`

Estender o harness descartavel para recovery via Mailpit/GoTrue e provar login,
restore/refresh/rotacao, logout, refresh antigo, reset unico/expirado, senha
antiga e access token de sessao revogada. Reexecutar as negativas da spec 039:
sem vinculo, ativo, suspenso, revogado, realm, role/capability, tenant A/B,
contexto/ID adulterado e auditoria minimizada.

## 6. Verificacao, review e rastreadores

- Preparar/verificar mirror e replay limpo; executar pgTAP focado e regressao
  proporcional.
- Rodar formatter, analyze, build web, validador do Catalogo, secret scan,
  advisors locais focados, `git diff --check` e cleanup.
- Validar as tres telas no navegador compartilhado nas larguras contratadas,
  sem inserir credencial real em log ou evidencia.
- Solicitar revisao independente do delta e corrigir achados por TDD.
- Atualizar os tres rastreadores e executar o gate `coelo-knowledge`, com fonte
  canonica antes de qualquer projecao duravel.
