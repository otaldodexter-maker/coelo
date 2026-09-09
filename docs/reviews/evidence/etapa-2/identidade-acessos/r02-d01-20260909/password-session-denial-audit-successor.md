---
title: "D01 — sucessor da falha real de auditoria do gate 35"
source: "docs/reviews/etapa-2-operacao/next-round/R02-20260909/assignments/D01.md r14; packages/coelo_database/migrations/20260901190927_deploy_superadmin_internal_auth.sql; packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql"
status: "successor-prepared-not-executed"
generated_at: "2026-09-09"
---

Etapa 2 → apps/superadmin → Auth → Redefinir senha → recovery negado no
contexto backend → `auth.reset`, dependência de `auth.login` e auditoria.

Resultado comunicado no assignment canônico D00 r14, 15:25:01 BRT:
ensaio com 173000 aplicado, 36 pgTAP executados, 35 PASS e um FAIL no gate 35;
nove HTTP e um cold composto bloqueados, sem execução. O gate que exigia três
eventos de auditoria verificados com `SAI_SESSION_INVALID` não passou.

A inspeção de fonte explica a falha: os wrappers públicos retornam o código
original no envelope, mas sua allowlist para auditoria omite
`SAI_SESSION_INVALID` e converte esse motivo em `SAI_INTERNAL_ERROR`.
Antes do novo guard, sessões ausentes/expiradas não eram auditadas porque
`audit_superadmin_internal_denial_if_identified` recusava a própria sessão.
Agora uma sessão GoTrue válida sem AMR password é negada pelo helper e pode
ser identificada para auditoria. O wrapper perde o motivo correto nesse caminho.
Essa conclusão deriva do código e do FAIL informado; não houve nova leitura
das linhas de auditoria ou execução SQL pelo autor deste recibo.

O helper de auditoria identifica auth link e membership reais do fixture, de
modo que os três eventos esperados são `hash_version=2`, ator
`superadmin_internal`, papel `operations`. Não devem ser recategorizados como
atores anônimos `auth_session` v3 para satisfazer o teste. O dispatcher e a cadeia
de hashes não foram alterados.

Sucessor separado:
`20260909173100_superadmin_password_session_denial_audit.sql` acrescenta apenas
`SAI_SESSION_INVALID` à allowlist de motivo nos wrappers
`superadmin_auth_bootstrap_context()` e
`superadmin_auth_resolve_institution_context(uuid)`. Ambos têm o mesmo defeito
de origem. Corpo, autorização, tenant, chamadas de auditoria e envelopes são
preservados; nenhuma função privada de autorização é alterada.

| Função | MD5 prosrc antes / caracteres | MD5 prosrc depois / caracteres |
| --- | --- | --- |
| bootstrap | `cf411ecb47a0e3e42aeb4ee654f6b079` / 1929 | `5db2c318fb52cb9014392727985bbc32` / 1951 |
| resolve institution | `e16a3b61cffba4230c7fb4235da9382d` / 2093 | `c3948273e90ca59235a1a5f226ec9641` / 2115 |

Os corpos baseline normalizados CRLF→LF são idênticos nas migrations
20260827233000 (prefixo Auth) e 20260901190927 (última definição do repo).
A coordenação confirmou os mesmos fingerprints em consulta remota somente
leitura. Preflight exige esses corpos exatos, owner postgres, security definer,
volatile, retorno jsonb, search_path vazio e ACL pública apenas authenticated.
Também exige o fingerprint do helper após 173000:
`6b3f7d0a6b374786137ed62ae8cf1c18`. Postconditions exigem os corpos novos e a
mesma metadata/ACL. A migration 173000 permaneceu byte a byte intacta.

O gate 35 mantém seu ID e ficou mais estrito: conta três correlações distintas
sem filtrar previamente motivo/outcome; verifica cadeia, motivo, versão/ator,
vínculos internos, hash da sessão correta, permission/AAL, contexto global e
ausência de campos de pessoa, suporte, objeto, instituição e payloads. A
associação com membership usa LEFT JOIN e a expressão usa `coalesce(...,false)`
para não esconder eventos inesperados ou valores nulos no agregado.
O caso 104 de AMR/metadata adulterados chama o resolver institucional com NULL:
o helper deve negar a sessão antes de avaliar a instituição. Isso cobre a segunda
allowlist sem nova entidade/tenant. O gate 35 exige ação de resolver para 104 e
bootstrap para 102/103, mantendo três eventos e os mesmos 36 IDs do plano.

SHA-256 da preparação:

- 173000 inalterada: `A57E3F85C3906F2E83F28AE90BFBFD58E10BED6A25AFA8352019DF0210342BD8`.
- 173100: `F47F96D4F1C7CAB124A2A7608C50BF5CFBCC11E4FD502AB90C8893657166F863`.
- TAP36: `D0A37156E218AA1C445A6412338184292D13664FE92CCD6C7B5AECE6D127600B`.

`git diff --check` passou. SQL e Docker não foram executados nesta preparação.
Nova campanha coordenada deve usar os dois adicionais em ordem, target
173100, TAP36 + HTTP9 + cold1, sem somar a repetição como novos testes.
O ensaio predecessor permanece 35P/1F/10B; a prova do sucessor ainda está
pendente. Nenhuma escrita remota ou promoção FE/BE/E2E ocorreu.
