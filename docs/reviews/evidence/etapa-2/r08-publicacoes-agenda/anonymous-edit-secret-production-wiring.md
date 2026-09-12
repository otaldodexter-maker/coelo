---
source: "C0 R08; commit 72e6e6f22; revisão 770bb79e3; ciclo 150 origin/dev 7e889abac"
status: "local-green; production-route-composed; e2e-not-executed"
generated_at: "2026-09-12"
---

# Composição produtiva do segredo de edição anônima

Recorte: `apps/superadmin -> Formulários -> Responder -> forms.respond`, sem
Chrome, SQL, deploy ou mutação em produção.

## Implementação

- `createSuperadminAuthScope` deriva uma identidade canônica e client-safe do
  projeto configurado: project ref para `*.supabase.co` e origem normalizada
  para stack local.
- O provider usa a conta real em `client.auth.currentUser.id`; `sessionId` não
  participa da partição.
- Sessão não autorizada, usuário ausente e password recovery retornam `null`.
- O resolver conserva uma instância para a mesma conta, solta o contexto ao
  receber conta nula e cria outra instância quando a conta muda.
- O provider atravessa `SuperadminAuthScope -> SuperadminApp -> router` sem ser
  reconstruído. A rota normal passa o store atual para `FormResponsePage`.
- `FormsTestPage` da rota `/forms/:formId/test` permanece sem store porque é
  preview read-only da definição e não abre nem salva resposta.

O store continua persistindo e relendo o segredo antes de `openResponseDraft`.
Nenhum segredo é colocado em rota, log, evidência ou identificador de projeto.

## Verificação

Base integrada antes da prova: merge `e71bc1777d`, com
`origin/dev@7e889abac` e implementação `c17df4900`.

- `flutter test` em
  `forms_anonymous_edit_secret_store_test.dart`,
  `superadmin_app_config_test.dart` e
  `forms_media_composition_test.dart`, `--concurrency=1`: **17/17 PASS**;
- `dart analyze` nos nove arquivos produtivos/de teste afetados: **No issues
  found**;
- `git diff --check`: limpo;
- teste E2E/rota real: não executado;
- Flutter liberado ao C0 após a prova; nenhum processo retido.

Os casos novos cobrem identidade estável, troca/null de conta, canonicalização
do projeto, forwarding após mudança de contexto e bloqueio da rota sem sessão.
