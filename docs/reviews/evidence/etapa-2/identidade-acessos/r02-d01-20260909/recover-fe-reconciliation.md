---
title: "D01 auth.recover — continuidade das provas Front-end"
source: "coelo-frontend/SKILL.md; specs Auth; R01-delta-2005.md; logs originais C00; Git; evidências D01"
status: "client-verified; proposed-to-D00; backend-e2e-pending"
generated_at: "2026-09-09"
observed_at: "2026-09-09T13:20:11-03:00"
---

# Recorte e decisão

Etapa 2 → apps/superadmin → Autenticação → Recuperar senha → formulário,
envio, confirmação neutra, reenvio e retorno → `auth.recover`.
Inspeção somente leitura, sem testes novos nesta reconciliação. Base R02
`56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`; HEAD observado ao concluir
`6dfec55a49e1caa9808807dbea5068836f419ab8`.

Decisão atual D01: **`auth.recover` verified FE**, proposta nominal ao escritor
D00. O gate dos nove casos foi executado e aprovado às13:26 BRT, conforme
recibo ao final. Não foi encontrado defeito funcional novo. Não exigir SMTP
ou conta remota para certificar esta camada; BE/E2E continuam independentes.

O contrato `.agents/skills/coelo-flutter-review/SKILL.md`, seção
“Progresso e limite de verified”, permite double fiel em teste e exige que a
composição normal não caia em fixture. Falta de backend não rebaixa FE válido.

# Aceites já demonstrados e wiring

- `recover-reset-client.txt`: testes existentes da tela de recuperação,
  cinco goldens e matriz responsiva das três telas aprovados no lote D01
  de 61 casos. Para recuperação: formulário, validação, loading/disabled,
  falha segura, confirmação neutra, reenvio/loading/falha, anúncio semântico,
  retorno ao login, light/dark, 375/768/1024/1440 e 375 a 200%.
- `keyboard-motion.txt`: caso `D01 keyboard recovery submits the email once
  with done` aprovado; falhas de compilação de outros arquivos naquele lote
  não invalidam esse resultado individual. Não reexecutar esse caso por rotina.
- `router-recovery.txt`: rota pública normal e retorno ao login cobertos no
  recorte de 14 casos; preservar os limites de cada teste.
- Composição produtiva inspecionada: `superadmin_auth_scope.dart:321` e
  `:399` constroem `createCoeloAuthPasswordRecoveryAction` com gateway real e
  redirect explícito. `superadmin_router.dart:986` injeta essa ação na rota
  normal. A ocorrência de fallback em rota de desenvolvimento é separada e
  não é a composição normal usada para esta conclusão.
- `password_recovery.dart` encaminha email e redirect ao gateway e traduz
  sucesso/falha segura. O ViewModel normaliza o email, impede envio concorrente,
  conserva o sucesso após falha de reenvio e evita notificação depois de dispose.

As fontes visuais são a spec Login de 13/07, a spec de solicitação de
recuperação de 16/07 e a baseline Login da coelo-ui. A spec Auth-first de 01/09
amplia o lifecycle; sua prova full-stack não é substituída por este certificado
cliente. AAL1 segue o aditivo vigente; MFA permanece adiada.

# Prova histórica preservada

O recibo `docs/reviews/etapa-2-operacao/reports/R01-delta-2005.md:69`
registra a integração `90de1968`/`f7230db9`, pacote 47 PASS e cliente 75 PASS.
Os dois logs originais ainda existem e foram abertos diretamente:

| Log original | SHA256 |
|---|---|
| `C:/Users/adrie/AppData/Local/Temp/coelo-c00-auth-package-2012.log` | `0485B50AF74518CCDA9FA9DF33C3696189312E40B613019B2A0DB576C679C5DE` |
| `C:/Users/adrie/AppData/Local/Temp/coelo-c00-auth-client-2012.log` | `27D73FAC49878025E548EF162812DDFC796C6E08BF3870F20EB3E7CC17030C65` |

O pacote confirma requests sem revelar estado da conta, falha genérica,
fallback sem configuração e contenção de Exception/StateError/TypeError/Error
na recuperação com e sem redirect. Seu resultado é histórico reutilizado,
não nova execução D01. O log cliente 75 não inclui os dois arquivos da lacuna.
Não atribuir automaticamente os 122 casos a todo teste existente de Auth.

Comparação Git entre `f7230db9` e HEAD: zero diferenças nos seis arquivos
abaixo; igualdade dos blobs confirmada individualmente. A árvore de trabalho
não apresentava delta nesses paths.

| Arquivo | Blob Git igual nas duas revisões |
|---|---|
| `apps/superadmin/lib/features/auth/domain/password_recovery.dart` | `66b0899a2a223bd5bb4e834987fe44b2e69f4e00` |
| `apps/superadmin/lib/features/auth/presentation/view_models/password_recovery_view_model.dart` | `aa304ce40093992840714a5847e9265a33ba239e` |
| `apps/superadmin/test/features/auth/domain/coelo_auth_password_recovery_action_test.dart` | `3da45fdcf85de482b0d7feccf57c560ad0639052` |
| `apps/superadmin/test/features/auth/presentation/view_models/password_recovery_view_model_test.dart` | `dc1fd65a1b2e4032b4df55bba25424131c1469bb` |
| `packages/coelo_auth/lib/src/supabase_coelo_auth_gateway.dart` | `f366cf79705b88763f268482c6758032a2291912` |
| `packages/coelo_auth/test/coelo_auth_gateway_test.dart` | `dd8f402b569b50fb5562ca56a4fdb18abfda013a` |

# Gate focal encontrado na inspeção e fechado nesta campanha

O adapter e seu teste foram alterados por `a2c6eaab619b611ff99ae3a05618a664c185dd90`
em 01/09 (compatibilidade do gateway/redirect). O ViewModel e seu teste estão
inalterados desde `54cd9b260bd30ee6af3ee7a5235a83141d059c2b`.
A nota histórica de conclusão de julho não é recibo suficiente do adapter
posterior. Não foi localizado recibo nominal destes dois arquivos no lote C00
consultado; a ausência de recibo não afirma que nunca foram executados.

Executar somente estes arquivos, sem filtro de nome, em `apps/superadmin`:

```powershell
rtk proxy flutter test --no-pub test/features/auth/domain/coelo_auth_password_recovery_action_test.dart test/features/auth/presentation/view_models/password_recovery_view_model_test.dart --reporter expanded
```

Paths completos na worktree D01:

- `C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d01-autenticacao/apps/superadmin/test/features/auth/domain/coelo_auth_password_recovery_action_test.dart`: 2 casos, encaminhamento email/redirect com sucesso e tradução de falha segura.
- `C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d01-autenticacao/apps/superadmin/test/features/auth/presentation/view_models/password_recovery_view_model_test.dart`: 7 casos, inicial privado, normalização/loading/sucesso, falha inicial, exceção genérica, concorrência, reenvio preservando sucesso e dispose durante request.

Recibo atual: `recover-adapter-viewmodel.txt`, execução local em13:26 BRT,
exit0, **P9/F0/B0/S0/U0**, duração4s de teste. Fonte produtiva/testes inalterados
no HEAD6dfec55a; nenhum rerun das suítes verdes anteriores. A lacuna U9 está
fechada. Com tela/estados, semântica/teclado, responsividade/goldens, adapter,
ViewModel, gateway fiel e wiring normal reconciliados, D01 propõe promoção
nominal de `auth.recover` a verified FE. Este documento não altera trackers
globais nem declara integração dessa promoção em dev.

# Limites mantidos

Entrega real do email, configuração SMTP/redirect no provedor e consumo do
token pertencem ao pacote nominal BE/E2E. Os quatro casos browser bloqueados
tratam credencial, persistência/reload e logout; não são motivo automático
para reabrir a apresentação da solicitação de recuperação.
A falha do validador global em Locais é preexistente e externa a Auth; permanece
registrada no handoff e não é uma falha nova destes aceites.
Nenhuma decisão de produto nova; memória durável não alterada.
