---
title: "Handoff - grupo acessos-pessoas, Rodada 7"
round: "E2-R07-20260911"
base: "origin/dev após git fetch; work/etapa2-r07-acessos-pessoas"
status: "checkpoint 30 min; rota real retida por renderer/driver"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff R07 — checkpoint 23:58

Recorte: `apps/superadmin` → Coelo (Principal) → Pessoas, Perfis/Modelos de
acesso, Usuários internos e Convites.

## Evidência local

- Build: `flutter build web --release -t test_driver/qa_main.dart
  --dart-define-from-file=.env.local` concluído; `apps/superadmin/build/web/main.dart.js`
  foi gerado.
- Análise: `flutter analyze lib/features/people lib/features/access_profiles
  lib/features/platform_users lib/features/invites lib/features/students` —
  `No issues found!`.
- Suíte direcionada: testes de `PersonHandleSection`, lookup de identidade,
  modelos/perfis, convites e students executados sem falha reportada no lote.
- Suíte ampliada: 749 testes executados, 744 aprovados e 5 falhas. As falhas
  ficam registradas como contratos de teste desalinhados/pendentes de triagem:
  `people_creation_requirements_red_test` ainda espera bloqueio em
  `people.create` apesar do gate produtivo 170700; o subconjunto de
  `person_identity_fail_closed_routes_test` também reproduziu uma expectativa
  de composição que não corresponde ao adapter atualmente importado. Nenhuma
  dessas falhas foi promovida a defeito produtivo sem prova pela rota real.

## Rota real

O `flutter run -d chrome -t test_driver/qa_main.dart --web-port=3020` abriu
Chrome separado com CDP. O `qa_drive.dart` não recebeu resposta do
`Runtime.evaluate`/`window.$flutterDriver` em 60 segundos; o app foi encerrado
sem login e sem escrita produtiva. Não há captura nem certificação E2E neste
checkpoint.

## Gates

- `internal-users.create`: Edge Function `internal-user-create` ainda sem
  deploy; manter FE/BE `local-green`.
- `invites.resend`: produção não tem convite expirado e nenhum pacote sintético
  foi criado sem fixture/pgTAP seguro.
- `internal-users.suspend`: não suspender usuários QA em uso; requer interno
  sobressalente.

## Commits publicados

- `4626a1d56` — inicia revisão R07 de acessos e pessoas.
- `1e6ac1077` — registra checkpoint local da R07 de acessos.

Nenhum segredo foi copiado para Git, JSON ou este handoff.

## Fechamento C0

- Branch publicada: `work/etapa2-r07-acessos-pessoas`.
- SHA final publicado: `6bf1b576c2ed10456c924ddbfe7de30fdbf170d7`.
- Estado local: `git status` limpo; nenhum stash; nenhum arquivo de trabalho
  adicional pendente.
- Não foram criados dados sintéticos, migrations, chaves ou segredos nesta
  rodada. Não há fixture expirada para `invites.resend`.
- Handoffs da frente disponíveis para R03, R04, R05, R06 e R07; R01/R02
  permanecem referenciadas pelos relatórios/manifests históricos da operação.
- O delta restante é estimado em 1–2 horas de prova real após renderer Chrome
  estável, além dos gates independentes de deploy da Edge Function e fixture
  expirada com pgTAP.
- A worktree pode ser removida sem perda depois que o coordenador integrar e
  verificar o SHA remoto; antes disso, mantê-la para inspeção é mais seguro.

## Hotfix C0 — internal-user-create

- Commit publicado: `fcecf66bf014fe8d110b3b345cf578d5fb9beb20`.
- Arquivos: `packages/coelo_database/supabase/functions/internal-user-create/index.ts`
  e `cors_test.ts`.
- Causa corrigida: `reply` serializava corpo com status 204, causando erro de
  runtime; `Access-Control-Allow-Headers` não incluía `x-client-info`.
- Comportamento coberto: OPTIONS permitido retorna 204 com corpo vazio e
  headers corretos; origem não autorizada não recebe `allow-origin`; POST
  anônimo continua 401.
- Verificação: `deno check --config deno.json index.ts` limpo; `deno test
  --config deno.json --allow-env cors_test.ts`: 3 passaram, 0 falharam.
- Não houve deploy, uso de segredo, criação de usuário ou execução de
  Flutter/Chrome.
