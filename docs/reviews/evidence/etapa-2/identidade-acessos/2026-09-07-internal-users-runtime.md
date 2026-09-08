---
source: "E2E 1 — Identidade e Acessos; commits 4206f2bb and 10730253"
status: "incremental-evidence"
generated_at: "2026-09-07"
---

# Usuários internos — runtime protegido

## Recorte

O recorte cobre a composição do repositório nominal em `apps/superadmin`, a
listagem produtiva e a abertura de detalhe somente leitura. Criação, edição,
convites, mutações remotas e deploy Supabase permanecem fora deste incremento.

## Implementado

- `PlatformUserDetailPage` usa `PlatformUserRemoteLoader` como fonte
  autoritativa; não reexibe cache após ausência, erro ou negação.
- Respostas atrasadas são descartadas quando repositório, identidade, capacidade
  ou sessão mudam.
- `/internal-users/:internalUserId` exige a capacidade derivada
  `platform.member.read`; sem ela, não consulta o backend e exibe estado de
  acesso não autorizado.
- Repositório ausente ou demo continua retornando o estado 503 de composição.
- A rota de edição permanece explicitamente indisponível, sem mutação falsa.
- O login não revoga uma sessão vencedora concorrente: a proteção compara o ID
  da sessão e a revisão de autorização; negação do bootstrap atual ainda revoga
  uma autorização antiga quando não houve autorização posterior.

## Evidência local

- Commit `4206f2bb`: detalhe remoto isolado e cinco testes de widget.
- Commit `10730253`: rota produtiva protegida, constantes e conexão da lista ao
  detalhe.
- `flutter test test/features/platform_users/presentation/platform_user_detail_page_test.dart` — 7/7,
  incluindo callback de volta e troca direta de capability para acesso negado.
- `flutter test test/features/platform_users/data/supabase_platform_user_repository_test.dart` — 24/24.
- `flutter test test/app/router/internal_user_routes_test.dart` — 4/4.
- `flutter test test/app/router/platform_user_preview_routes_test.dart` — 2/2.
- `flutter test test/app/router/internal_user_detail_routes_test.dart` — 4/4,
  em viewport 800×1000: deep link permitido, capability ausente sem RPC,
  negação do servidor, retry, navegação real Voltar → lista → card → detalhe,
  troca de sessão com nova consulta, perda de capability por notificação real
  de SuperadminSession e redirecionamento de logout. Usa HTTP simulado;
  não comprova Supabase real nem autorização do servidor.
- `flutter test test/features/auth/domain/coelo_auth_login_action_test.dart` — 10/10,
  incluindo corridas de sessão A→B, reautorização no mesmo ID, negação atual,
  autorização durante `auth.signOut()` e autorização divergente pré-cleanup.
- `flutter test test/features/auth/domain/logout_action_test.dart` — 3/3,
  cobrindo logout concorrente sem limpar uma autorização vencedora.
- Analyzer focado e `dart format` sem diagnósticos.

A execução consolidada anteriormente informada como 60/60 retornou `+59`:
foram 59 testes (10 login + 12 sessão + 24 repository + 7 detalhe + 4 diretório
normal + 2 preview). As contagens de 25 e 6 publicadas anteriormente eram
incorretas; os resultados acima corrigem essa leitura do runner.

## Gates ainda abertos

O pacote ainda não prova verified-e2e: falta sessão Supabase real com replay de
401/403, persistência/reload e auditoria em produção. A autorização vencedora
foi comprovada no controlador local, sem provar seu estado no SDK/servidor após
revogação concorrente. O hook de mídia aguarda consumidor real da E2E 3.

A transição detalhe → logout → login em 1440×1000 trava no primeiro pump de
renderização após o signOut; em 800×1000 passa. A localização foi confirmada
por interrupções diagnósticas antes/depois das etapas, já removidas do teste.
O gate desktop segue aberto, com causa ainda em investigação. A suíte ampla
apresenta divergência de fixture (5 instituições versus expectativa de 12) e
goldens; não foi provado nesta evidência que sejam todas anteriores à branch.
