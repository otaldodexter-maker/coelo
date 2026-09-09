---
title: "R02 D01 — recibo de qualificação do pacote Auth"
source: "Saídas observadas Node/exec e MCP Supabase nesta sessão; r02-d01-auth-proof*.mjs; revisão independente auth_visual; 2026-09-09-r02-d01-auth-remote-package.md"
status: "local-checks-pass; readonly-provider-observed; mutations-not-executed"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Recibo D01-AUTH-PROOF-R02-v1

Etapa 2 → apps/superadmin → Auth → `auth.login`, `auth.recover`, `auth.reset`,
`auth.logout`. Plano nominal: `52edcfbe-adec-4614-b9a5-a10bc543379d`.
Worktree observada: `C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d01-autenticacao`.

SHA256 final do executor, medido sem executar o programa:
`97B25D6E8E954044870BB87D5CEFC509538D7577AF80B8612C19DD3A3320ACFB`.
Arquivo: `packages/coelo_database/scripts/r02-d01-auth-proof-executor.mjs`.
Revisão independente `auth_visual` aprovada no recorte fonte/contrato após
correção de cleanup e reconciliação do formato SQL. O delta posterior de headers
Admin foi conferido na documentação oficial e por um teste focal aprovado;
o hash acima identifica esse arquivo final. Revisão de fonte não prova execução
de mutações ou COMMIT produtivo.

## Testes locais únicos

Preflight: **P=6, F=0, E=6, N=6, B=0, S=0, U=0**.
Executor: **P=16, F=0, E=16, N=16, B=0, S=0, U=0**.
São 22 testes distintos deste pacote, não 22 ações Auth concluídas.
As falhas encontradas em review foram corrigidas antes do aceite de fonte;
nenhuma falha de execução Node foi observada nos comandos registrados.

Os IDs abaixo são os nomes exatos dos testes nos respectivos arquivos.

`packages/coelo_database/scripts/r02-d01-auth-proof.test.mjs`:

1. `local config requires exact production redirect within auth section`
2. `mismatched project and origins never issue a request`
3. `secret and absent API keys are rejected before network`
4. `public settings uses one GET, blocks redirects, and emits only allowlisted booleans`
5. `network and malformed provider errors are sanitized`
6. `nominal qualification SQL only reads aggregate/schema data and never calls bootstrap`

`packages/coelo_database/scripts/r02-d01-auth-proof-executor.test.mjs`:

1. `default and named action are offline without reading credentials or using network`
2. `opaque secret key uses apikey only while actor JWT stays in Authorization`
3. `target, approval and secret-key guards reject before any request`
4. `non-Owner context denies Auth creation before mutations`
5. `unowned ID, mailbox collision, cross-realm and private drift deny all mutations`
6. `provision creates banned Auth user, confirms private COMMIT then activates exact user`
7. `confirmed provision replay with existing sessions does not repeat creation or activation`
8. `ambiguous Auth creation never retries, inserts bindings or activates`
9. `wrong create response ownership stops before private writes`
10. `ambiguous private COMMIT never retries SQL or unbans account`
11. `cleanup bans exact user and atomically revokes bindings and provider sessions without deleting history`
12. `cleanup does not depend on missing or expired synthetic token and never sends Owner to logout`
13. `ambiguous ban is not retried and cannot prevent terminal session revocation`
14. `unconfirmed ban still revokes bindings and sessions but never reports complete cleanup`
15. `cleanup of partial banned creation needs no synthetic login or private insertion`
16. `mutation SQL enforces live Owner, ownership, cross-realm, exact versions and audit within transaction`

O executor teve execução inicial de 14 casos. Após revisão, somente sete casos
afetados por cleanup/replay/SQL foram executados (incluindo um caso novo),
preservando oito provas válidas; o teste novo de headers completou os 16 IDs.
O teste focal de colisão do preflight foi repetido somente quando seu SQL ganhou
IDs nominais adicionais. Reruns não foram somados aos denominadores.

## Comandos observados

Comandos abaixo retornaram código 0 em suas execuções; esta entrega documental
não os executou novamente:

```powershell
rtk proxy node --test packages/coelo_database/scripts/r02-d01-auth-proof.test.mjs
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof.mjs --local
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof.mjs --remote-readonly
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof.mjs --sql
rtk proxy node --test packages/coelo_database/scripts/r02-d01-auth-proof-executor.test.mjs
rtk proxy node packages/coelo_database/scripts/r02-d01-auth-proof-executor.mjs
rtk proxy node --test --test-name-pattern="^(cleanup|ambiguous ban|unconfirmed ban|mutation SQL|confirmed provision replay)" packages/coelo_database/scripts/r02-d01-auth-proof-executor.test.mjs
rtk proxy node --test --test-name-pattern="nominal qualification" packages/coelo_database/scripts/r02-d01-auth-proof.test.mjs
rtk proxy node --test --test-name-pattern="opaque secret key" packages/coelo_database/scripts/r02-d01-auth-proof-executor.test.mjs
```

O comando completo do executor corresponde à revisão inicial de 14; o estado
final utiliza os deltas focais acima. Os testes usam HTTP controlado, não SQL
mutante real. O modo default do executor retornou `offline-no-network`, alvo
nominal e `sendEmail=false`; nenhum `--execute` foi invocado.

## Leituras remotas sanitizadas

| Observação | Resultado real observado |
|---|---|
| MCP `list_projects` / `get_project_url` | `coelo`, `evvbomzejfijozbtgvpt`, `ACTIVE_HEALTHY`, `sa-east-1`; `https://evvbomzejfijozbtgvpt.supabase.co` |
| `--local` | Redirect produtivo presente no TOML; `productionConfigVerified=false`; sessão/contexto não exercitados |
| GET `/auth/v1/settings` do modo somente leitura | `emailProviderEnabled=true`, `signupDisabled=true`; SMTP não exercitado; allowlist remota de redirect não exposta por esse endpoint |
| SQL de qualificação em `BEGIN READ ONLY` via MCP | RPC de contexto, auth links, memberships e `auth.sessions` presentes; papel `operations` nominal pronto; zero usuários e zero sessões marcados com este pacote |
| Colisões de IDs | Três IDs privados livres; UUID Auth `8d7a34f8-6230-4f43-82c3-45743d62ab96` também livre em consulta própria; todos estão no guard final do preflight |
| Schema do executor | Tipo de contexto, helper canônico e assinatura exata de auditoria presentes; grant `platform.read` do papel nominal ativo |
| Dependências de `auth.sessions` | FKs reais `auth.refresh_tokens` e `auth.mfa_amr_claims` com `ON DELETE CASCADE`; nenhuma exclusão executada |
| `stateSql` gerado com mailbox fictícia da fixture | `[{receipt:{planId,auth_exists:false,owned:false,banned:false,bindings:"absent",sessions:0,role_ready:true,no_global_link:true,mailbox_collisions:0}}]` |
| Envelope SQL com literal falso | `BEGIN READ ONLY; SELECT jsonb_build_object('authorized',false) AS actor; COMMIT;` devolveu `[{actor:{authorized:false}}]`; nenhuma sessão real foi usada |

A chave publishable para GET settings foi obtida por MCP, passada somente ao
processo e não impressa/persistida no pacote. Nenhuma chave de servidor, token
Management ou JWT do Owner foi obtido para esta preparação. O ref fixado no
SQL é rótulo nominal; o parâmetro de projeto do MCP vincula a conexão real.

Snapshots de relógio efetivamente lidos durante o trabalho: **13:07:08**,
**13:11:57** e **13:29:20**, em 09/09/2026, America/Sao_Paulo. Não são timestamps
individuais dos testes; horário exato de cada comando não foi preservado.
Os recibos vieram das saídas das ferramentas desta sessão. Não foi criado
arquivo de log bruto e não se alega que exista um.

## Limite do aceite

Qualificados: preparação local executável, guards e recibos simulados,
configuração pública e consultas remotas somente leitura. Não executados:
provisionamento, ban/unban, escrita/exclusão SQL, COMMIT de mutação, email,
senha/token real, revogação funcional real e E2E. Nenhuma conta do Owner foi
alterada. Mailbox/identidade controlada, autorização nominal, credenciais de
execução e prova dos gates continuam no pacote principal. Este recibo não
promove FE/BE/E2E das quatro ações para concluído.
