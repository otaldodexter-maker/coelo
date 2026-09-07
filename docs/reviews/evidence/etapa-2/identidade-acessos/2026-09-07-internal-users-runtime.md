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
  incluindo volta à listagem e troca de revisão para acesso negado.
- `flutter test test/features/platform_users/data/supabase_platform_user_repository_test.dart` — 25/25.
- `flutter test test/app/router/internal_user_routes_test.dart` — 4/4.
- `flutter test test/app/router/platform_user_preview_routes_test.dart` — 6/6.
- `flutter test test/features/auth/domain/coelo_auth_login_action_test.dart` — 8/8,
  incluindo corridas de sessão A→B, reautorização no mesmo ID e negação atual.
- A mesma suíte foi ampliada para 10/10 com o caso de autorização concorrente
  durante `auth.signOut()` e o caso divergente criado antes do cleanup.
- Analyzer focado e `dart format` sem diagnósticos.

## Gates ainda abertos

O pacote ainda não prova verified-e2e: falta sessão Supabase real com replay de
401/403, persistência/reload e auditoria em produção. O hook de limpeza de mídia
em logout/revogação aguarda reserva dos hunks de lifecycle compartilhados da
E2E 3. A suíte ampla também conserva falhas pré-existentes de fixture (5
instituições observadas versus expectativa histórica de 12) e goldens de
renderização; nenhum golden foi atualizado por inferência.
