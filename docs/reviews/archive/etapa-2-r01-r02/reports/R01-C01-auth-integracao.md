---
source: "C01 handoff r3; git 1fd7f9ec; C00 git 2dd5a9bc; testes executados na C00"
status: "integrated-local-verified; pending-delivery-dev; not-e2e"
generated_at: "2026-09-08T12:34:18-03:00"
timezone: "America/Sao_Paulo"
---

# Integração incremental C01 — Auth

Origem `1fd7f9ecd8805379ca4d24b09000f4abcff041af` → C00 `2dd5a9bc`; cherry-pick sem conflito sobre44de3d76. Handoff r3 preservado em origem10f893a7, ponta remota conferida por C00. Somente os três arquivos de código/testes entraram; nenhum handoff de executor foi copiado para C00.

Revisão Dart: exclusão entre login e updatePassword adquirida antes do primeiro await e liberada em finally, mantendo recovery/cleanup/falha genérica. Sem mudança de interface, dependência, scope, shell ou router. Testes reproduzem interleaving de operações e retry após falha. Limite: substituição externa diretamente no SDK permanece aberta. API corrente consultada em08/09: [updateUser](https://supabase.com/docs/reference/dart/auth-updateuser) e [signOut](https://supabase.com/docs/reference/dart/auth-signout); o limite de concorrência é evidência do código/testes, não promessa dessas páginas.

Verificação C00, Windows/Flutter local, HTTP sintético e sem remoto:

- Em apps/superadmin: `rtk proxy flutter pub get --offline` exit0; `rtk proxy flutter test --no-pub test/features/auth/domain/coelo_auth_recovery_sdk_test.dart test/app/router/login_remount_sdk_test.dart --reporter expanded`: **11/11 PASS**, processo36814 exit0.
- Em packages/coelo_auth: `rtk proxy flutter pub get --offline` exit0; `rtk proxy flutter test --no-pub --reporter expanded`: **25/25 PASS**, processo39975 exit0.
- Nenhum arquivo de dependência/manifest alterado. Diff e árvore conferidos.
- Executor relata regressão ampliada155/155 e analyzer dos três arquivos sem achados; essa execução é do C01, não repetição C00.

IDs afetados: `auth.login`, `auth.reset`. Verificação de camada: **2/219 ações FE auditadas parcialmente** quanto a exclusão/cleanup e regressão; IDs acima, resultado focal aprovado. Não são dois aceites completos. Backend real auditado nesta integração0/212; E2E0/187. Conclusão certificada permanece FE0/219,BE0/212,E2E0/187; não há IDs certificados. Classes do inventário mantidas194 ativas,22 adiadas,3 gates,7 N/A BE/E2E.

Implementado: impedir login/reset concorrentes pelo mesmo gateway. Falta testar/implementar conforme reprodução: substituição externa de sessão no SDK; critérios visuais/rotas restantes; SMTP/token/revogação reais. Integração local concluída, push C00 será conferido após commit deste registro, dev ainda84985b54 neste snapshot. Nenhuma produção/deploy/mutação remota.

Estimativa observada do primeiro lote C01: cerca8min relatados pelo executor até push; C00 revisão/integração/testes aproximadamente3min, incluindo resolução offline. Isso não estima outras ações. C01 prossegue Usuários/Modelos/Convites; C00 nominaliza personas e verifica catálogo/ledger para posterior autorização. Tempo remoto desconhecido.

Memória: no-op de nova regra durável; evidência técnica registrada aqui e nos rastreadores, sem mudança de produto aprovado.
