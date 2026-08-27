---
title: "Auth, sessão e contexto interno do Superadmin"
source: "decisions/0019-superadmin-internal-identity.md; specs/011-superadmin-database-rls.md; specs/018-profiles-permissions-superadmin.md; specs/023-superadmin-internal-users-local-preview.md; docs/security/auth-multitenant-permissions.md; decisão aprovada pelo Owner Coelo em 2026-08-27"
status: "approved-for-implementation"
generated_at: "2026-08-27"
---

# Auth, sessão e contexto interno do Superadmin

## Objetivo e decisão vinculante

Materializar a identidade, a sessão e a autorização dos Usuários Internos do
Superadmin no **mesmo projeto Supabase** do Coelo, sem misturá-las à identidade
global de Admin ou Principal.

Cada Usuário Interno usa uma conta distinta em `auth.users`, com e-mail distinto
da conta que a mesma pessoa eventualmente use em Admin ou Principal. A
unicidade normalizada de e-mail é a do próprio Supabase Auth; não se copia e-mail
para a base interna apenas para duplicar essa regra. A conta interna nunca é
ligada a `people`, `person_auth_links` ou `platform_memberships`, inclusive como
atalho de migração, compatibilidade ou auditoria.

O catálogo já existente de `platform_roles`, `platform_permissions` e
`platform_role_permissions` é reutilizado exclusivamente como catálogo de papel,
capacidade e relação papel–capacidade. `platform_memberships` e
`platform_member_permission_overrides` não participam de nenhuma decisão interna
nova.

## Escopo

- principal interno privado, vínculo de credencial, membership com escopo e
  contexto derivado mínimo;
- bootstrap autorizado, resolução/revalidação institucional sem persistir a
  seleção e revalidação por comando;
- validação de `auth.uid()`, `session_id` da JWT e sessão correspondente em
  `auth.sessions`;
- autorização por papel/capacidade do catálogo, incluindo AAL2 (segundo fator)
  obrigatório para Owner e por `platform_permissions.requires_mfa` para os demais;
- grants, RLS, auditoria minimizada, erros estáveis e testes de isolamento;
- transição incremental dos domínios Superadmin, sem pessoa sintética.

## Fora de escopo

- convite, envio de e-mail, aceite, senha, OTP, recuperação, reset de senha,
  gerenciamento de fatores MFA, troca de e-mail e listagem/revogação de
  dispositivos;
- criar, editar ou ampliar papéis, capacidades, overrides individuais ou escopos
  além do catálogo aprovado;
- vínculo referencial futuro com Admin ou Principal;
- alterar Flutter, telas `/dev`, RLS/migrations existentes ou o ledger nesta
  entrega documental;
- qualquer transição de estado além de `active`, `suspended` e `revoked`.

O preview local da spec 023 permanece fake até a cadeia deste contrato estar
implantada e comprovada; ele não é bootstrap nem evidência de Auth produtivo.

## Threat model e invariantes

| Ameaça | Controle obrigatório |
| --- | --- |
| Uma conta de Admin/Principal chama RPC do Superadmin | O principal precisa ter `auth_link` interno `active` por `auth.uid()` e membership interna `active`; e-mail, rota, claim, `user_metadata`, papel informado pelo cliente e `platform_memberships` não concedem acesso. |
| IDOR/BOLA trocando identidade, membership, instituição ou papel | O servidor deriva identidade, membership, sessão e contexto; IDs de ator/contexto enviados pelo cliente são ignorados ou comparados estritamente ao contexto derivado. |
| JWT válida após logout, revogação ou troca de senha | Cada comando consulta novamente `auth.sessions` pelo `session_id` da JWT e por `auth.uid()`, além de reler `auth_link`, membership, escopo e capacidade. Não existe contexto autorizado em cache do cliente. |
| AAL1 executa ação privilegiada | Owner exige AAL2 inclusive no bootstrap; os outros papéis exigem AAL2 quando a capacidade possui `requires_mfa = true`. |
| Reuso de identidade global | Gatilhos simétricos bloqueiam `auth_user_id` interno em `person_auth_links` e `auth_user_id` de `person_auth_links` em `superadmin_internal_auth_links`. Não há backfill que crie ou associe `people`. |
| Exposição direta de tabelas ou helper privilegiado | Objetos ficam em `app_private`, fora da Data API, com RLS forçada, sem grants diretos a `anon`/`authenticated`; helpers `SECURITY DEFINER` têm `search_path = ''` e execução mínima. |
| Escalonamento via perfil ou parâmetro | A capacidade vem de `platform_role_permissions`; negação explícita do catálogo conserva precedência. Cada comando informa no código qual capacidade requer, mas a confere no banco. |
| Log vira diretório de pessoas ou vaza sessão | Auditoria guarda IDs opacos, código, resultado e correlação; nunca e-mail, nome, JWT, refresh token, cabeçalho, IP bruto, segredo, conteúdo de `user_metadata` ou PII. |

## Entidades físicas propostas

As tabelas abaixo pertencem a `app_private`; a migration futura define FKs,
checks, índices e gatilhos em uma única unidade transacional. `uuid` segue o
padrão físico vigente; não há tabela de perfil pessoal nem cópia de contato.

| Objeto | Campos exatos | Regra |
| --- | --- | --- |
| `app_private.superadmin_internal_identities` | `id uuid PK`; `created_at timestamptz NOT NULL`; `created_by_internal_identity_id uuid NULL` | Principal interno mínimo, sem credencial. A linha não tem e-mail, CPF, nome, foto, sessão, `auth_user_id` ou estado. |
| `app_private.superadmin_internal_auth_links` | `id uuid PK`; `internal_identity_id uuid NOT NULL`; `auth_user_id uuid NOT NULL UNIQUE`; `status superadmin_internal_auth_link_status NOT NULL`; `created_at timestamptz NOT NULL`; `suspended_at timestamptz NULL`; `revoked_at timestamptz NULL`; `changed_by_internal_identity_id uuid NULL`; `version bigint NOT NULL` | Liga a identidade à credencial Auth sem ligá-la a `people`. `auth_user_id` referencia `auth.users(id)` e é único em todo o histórico. O lifecycle contém somente `active`, `suspended` e `revoked`; seus timestamps obedecem ao estado. Link revogado não é reativado: nova credencial exige novo link e fluxo futuro aprovado. |
| `app_private.superadmin_internal_memberships` | `id uuid PK`; `internal_identity_id uuid NOT NULL`; `platform_role_id uuid NOT NULL`; `scope_kind superadmin_internal_scope_kind NOT NULL`; `scope_institution_id uuid NULL`; `status superadmin_internal_membership_status NOT NULL`; `created_at timestamptz NOT NULL`; `suspended_at timestamptz NULL`; `revoked_at timestamptz NULL`; `changed_by_internal_identity_id uuid NULL`; `version bigint NOT NULL` | A membership é a unidade de autorização. `platform_role_id` referencia apenas `public.platform_roles(id)` e `scope_institution_id` referencia `public.institutions(id)`. `scope_kind` contém somente `platform` e `institution`: `platform` exige `scope_institution_id IS NULL`; `institution` exige `scope_institution_id IS NOT NULL`. Status permitidos: `active`, `suspended`, `revoked`; seus timestamps obedecem ao estado; membership revogada não é reativada: novo acesso exige nova linha e novo fluxo futuro aprovado. |
| `app_private.superadmin_internal_context` | Tipo de retorno, não tabela: `internal_identity_id uuid`; `internal_auth_link_id uuid`; `internal_membership_id uuid`; `auth_user_id uuid`; `session_id uuid`; `platform_role_id uuid`; `platform_role_code text`; `scope_kind text`; `scope_institution_id uuid NULL`; `resolved_institution_id uuid NULL`; `aal text`; `permission_code text`; `requires_mfa boolean` | Snapshot derivado dentro da transação atual; a instituição resolvida só existe no retorno da chamada atual e não é aceita nem persistida como fonte de autorização. |

Índices mínimos: unicidade de `superadmin_internal_auth_links.auth_user_id`;
índice de lookup do link em `(internal_identity_id, status)`; unicidade parcial
de uma única membership `active` por identidade; índices de
lookup em `(internal_identity_id, status)` e
`(scope_kind, scope_institution_id, status)`; e FKs indexadas para identidade,
papel, instituição e ator de mudança. Se a consulta produtiva filtrar apenas
links ou memberships ativos, os índices parciais devem refletir
`WHERE status = 'active'` e ser confirmados com `EXPLAIN` na implementação.

O enum `app_private.superadmin_internal_membership_status` contém **somente**
`active`, `suspended` e `revoked`. Não criar `invited`, `pending`, `disabled`,
`deleted` ou transições implícitas nesta spec.

O enum `app_private.superadmin_internal_auth_link_status` tem os mesmos três
valores e `app_private.superadmin_internal_scope_kind` contém somente
`platform` e `institution`. Não adicionar lifecycle ou escopo implícito.

### Barreiras de exclusão entre realms lógicos

1. Ao inserir/alterar `superadmin_internal_auth_links.auth_user_id`, um gatilho
   privado recusa se existir qualquer `public.person_auth_links` para o mesmo
   Auth user, independentemente de seu status histórico.
2. Ao inserir ou alterar `public.person_auth_links`, o gatilho complementar
   recusa se o Auth user já estiver em `superadmin_internal_auth_links`.
3. O bootstrap e qualquer comando futuro de provisionamento consultam o Auth
   user pelo identificador fornecido pelo servidor e falham fechado se não houver
   conta, se o e-mail não estiver confirmado conforme a política Auth vigente ou
   se a conta já pertencer ao realm global.
4. `platform_memberships` não recebe backfill nem ponte. Registros legados ficam
   históricos até cada consumidor ser migrado; não autorizam o principal novo.

## Interfaces exatas

### Helper obrigatório de contexto

```sql
app_private.require_superadmin_internal_context(
  p_permission_code text
) returns setof app_private.superadmin_internal_context
```

O helper é `SECURITY DEFINER`, com `SET search_path = ''`, não é exposto e não
tem `EXECUTE` para `PUBLIC`, `anon` ou `authenticated`. Ele, nesta ordem:

1. obtém `auth.uid()`; se nulo, falha;
2. lê `session_id` exclusivamente de `auth.jwt()` e converte-o a UUID;
3. encontra `auth.sessions.id = session_id` **e** `auth.sessions.user_id =
   auth.uid()`, aceitando somente sessão ainda válida segundo o estado e os
   limites do Auth; nenhuma data/claim fornecida pelo cliente substitui essa
   checagem;
4. encontra pelo mesmo `auth_user_id` o `auth_link` `active`, sua identidade e
   uma única membership `active`; link ou membership `suspended`/`revoked`
   nunca são promovidos a contexto;
5. resolve o papel e a capacidade `p_permission_code` em catálogos ativos,
   aplicando a precedência de negação já definida para
   `platform_role_permissions`;
6. lê `aal` da JWT autenticada: Owner requer `aal2` para qualquer chamada; para
   outro papel, exige `aal2` se e somente se a capacidade ativa tiver
   `requires_mfa = true`;
7. devolve somente o registro de contexto acima, ainda sem instituição
   selecionada.

Nenhum comando reutiliza resultado anterior: ele invoca esse helper no começo da
própria transação e antes de ler, assinar, escrever, retornar dado ou registrar
sucesso. Um comando que muda membership, papel ou capacidade trava as linhas
necessárias, recalcula o contexto e verifica a proteção do último Owner dentro
da mesma transação.

### RPCs públicas mínimas de contexto

```sql
public.superadmin_auth_bootstrap_context()
returns jsonb
```

É a interface de entrada permitida ao cliente nesta fase. Ela chama o helper com
`platform.read` e retorna somente: `internal_identity_id`,
`internal_membership_id`, `platform_role_code`, `scope_kind`,
`scope_institution_id`, `permission_codes` e `aal`. Não retorna `auth_user_id`,
e-mail, dados de outras identidades, `session_id`, detalhes de Auth ou qualquer
segredo.

Owner em AAL1 não recebe um indicador de UX: o helper nega o bootstrap com
`SAI_MFA_REQUIRED`. O mesmo vale para qualquer capacidade ativa com
`requires_mfa` em AAL1. A RPC tem `EXECUTE` apenas para `authenticated`; seu
corpo continua usando a checagem privada e retorna erro estável, não linhas
vazias que permitam enumeração.

```sql
public.superadmin_auth_resolve_institution_context(
  p_institution_id uuid
) returns jsonb
```

É a única interface pública adicional: revalida a sessão, o `auth_link`, a
membership, a capacidade existente `platform.read` no escopo institucional e a
instituição selecionada na mesma chamada. Membership `platform` pode resolver
somente instituição existente para a qual `platform.read` foi autorizada;
membership `institution` só resolve
`scope_institution_id`. A RPC devolve apenas o contexto mínimo e
`resolved_institution_id`; não grava seleção, `tenant_id`, sessão lógica ou
cache. Cada comando de domínio continua recebendo o recurso alvo e repete essa
resolução dentro de sua própria transação; o `p_institution_id` do cliente nunca
é autorização. `EXECUTE` é somente para `authenticated` e o erro usa o envelope
estável abaixo.

Não criar RPC pública de login, recuperação, reset, convite, suspensão ou
revogação nesta fatia. Os futuros comandos administrativos usam o helper, a
resolução institucional quando aplicável, sua capacidade específica, `request_id`,
versão esperada, motivo de auditoria e a mesma revalidação; seus contratos
pertencem às specs dos domínios.

## Grants, RLS e autorização

- `app_private` não é schema exposto pela Data API. Revogar `USAGE` e todos os
  privilégios das tabelas, sequências, tipos e funções internas de `PUBLIC`,
  `anon` e `authenticated`, salvo o wrapper público explicitamente listado.
- Ativar e forçar RLS nas três tabelas privadas. Não criar policy permissiva
  para o cliente; acesso interno ocorre somente pelo helper privilegiado.
- O helper consulta catálogos públicos por código/ID, mas não consulta nem cria
  `platform_memberships`. O catálogo não é uma prova de principal.
- Novas políticas/RPCs de domínio trocam, de modo incremental,
  `has_platform_permission(...)` pelo helper interno antes de retirar o caminho
  legado. Durante a coexistência, cada domínio escolhe **um** caminho por
  comando; nunca combina grants de pessoa e principal interno em um `OR`.
- Funções privilegiadas fixam `search_path = ''`, qualificam objetos, revogam
  `EXECUTE` de `PUBLIC` e expõem apenas wrappers necessários. `service_role` não
  é cliente, alternativa de login ou bypass de regra de negócio.

## Estados, erros estáveis e transporte

Os detalhes internos ficam nos logs privados. Para um resultado de negócio, a
API devolve envelope com `code`, mensagem curta localizada e `correlation_id`,
sem SQLSTATE, IDs internos, e-mail ou existência de outra conta.

| Código | Status HTTP semântico sugerido | Condição |
| --- | ---: | --- |
| `SAI_AUTH_REQUIRED` | 401 | Não há `auth.uid()` ou token autenticável. |
| `SAI_SESSION_INVALID` | 401 | JWT sem `session_id` válido ou sem correspondência atual em `auth.sessions`. |
| `SAI_INTERNAL_CONTEXT_DENIED` | 403 | Auth user sem identidade/membership interna ativa; não enumera o motivo a terceiros. |
| `SAI_MEMBERSHIP_SUSPENDED` | 403 | Própria membership interna está suspensa. |
| `SAI_MEMBERSHIP_REVOKED` | 403 | Própria membership interna está revogada. |
| `SAI_PERMISSION_DENIED` | 403 | Papel ativo não tem a capacidade pedida. |
| `SAI_MFA_REQUIRED` | 403 | Owner em AAL1 no bootstrap, na resolução institucional ou em qualquer comando; para outro papel, capacidade com `requires_mfa` em AAL1. |
| `SAI_LAST_OWNER_PROTECTED` | 409 | Comando tentaria deixar a plataforma sem Owner global ativo, cujo contexto sempre exige AAL2. |
| `SAI_CONCURRENT_CHANGE` | 409 | `expected_version` não corresponde ao estado bloqueado atual. |
| `SAI_INTERNAL_ERROR` | 500 | Falha interna não classificável; não expõe detalhe técnico. |

O valor da tabela é semântico, não uma promessa do status HTTP da chamada RPC.
Quando o wrapper captura a falha de negócio para reverter a subtransação e
commitar o audit negativo, uma chamada direta via PostgREST conclui a RPC e
responde HTTP 200 com o envelope. Para tornar a sugestão disponível sem inferir
pela mensagem ou SQLSTATE, o envelope de erro pode incluir
`error.http_status` com o valor da tabela; ele não altera o HTTP da resposta
direta. O cliente direto decide por `ok` e `error.code` (e pode usar
`error.http_status` somente como metadado de apresentação), nunca pelo status
HTTP. Uma Edge Function futura pode converter esse mapeamento semântico em HTTP
real, mas isso não é obrigatório nesta fatia.

Falhas de transporte ou infraestrutura que impedem a execução ou a resposta do
wrapper — por exemplo, gateway, PostgREST, banco indisponível ou timeout —
podem responder HTTP não-200. Elas não são resultado de negócio e não carregam
a garantia de envelope, `correlation_id` ou audit de negócio; não se fabrica
uma auditoria negativa quando o wrapper não pôde executá-la.

Para evitar enumeração, `SAI_INTERNAL_CONTEXT_DENIED` é a resposta externa para
quem não é interno; `SAI_MEMBERSHIP_SUSPENDED` e `SAI_MEMBERSHIP_REVOKED` só
podem ser apresentados após comprovação de posse da sessão do próprio Auth user.

Todo wrapper público gera um `correlation_id` antes de chamar helper ou comando.
Ele executa a autorização e a mutação em uma subtransação: em falha, captura o
erro estável, desfaz integralmente a subtransação, grava o evento de audit da
negação na transação externa e retorna, sem relançar,
`{"ok": false, "data": null, "error": {"code": "<stable_code>", "message": "<localized_message>", "correlation_id": "<uuid>", "http_status": <suggested_status>}}`.
Em sucesso, grava o audit e retorna
`{"ok": true, "data": "<sanitized_result>", "error": null}`.
Os comandos de domínio seguem o mesmo wrapper, para que a mutação falha reverta
e o audit negativo seja commitado; não podem capturar a falha depois de escrever
ou retornar dado. Para esse envelope de negócio, PostgREST direto retorna HTTP
200; o cliente interpreta `ok` e `error.code`. Se houver uma Edge Function
futura, ela poderá mapear `SAI_AUTH_REQUIRED`/`SAI_SESSION_INVALID` para 401,
as negações `SAI_*_DENIED`, lifecycle e MFA para 403, e
`SAI_LAST_OWNER_PROTECTED`/`SAI_CONCURRENT_CHANGE` para 409. Nenhuma camada
reconstrói esse mapeamento a partir de SQLSTATE ou de mensagem técnica.

## Auditoria e observabilidade

Cada bootstrap, resolução institucional e comando de domínio registra em `audit` um evento append-only
com: `actor_kind = 'superadmin_internal'`, `actor_internal_identity_id`,
`actor_internal_auth_link_id`, `actor_internal_membership_id`, `session_id_hash`, `action_code`,
`permission_code`, `aal`, `outcome`, `reason_code`, `correlation_id`,
`object_type`, `object_id` opaco e `occurred_at`.

O audit existente deve receber campos internos explícitos ou um ator tipado antes
de qualquer domínio migrar. Não preencher `actor_person_id` com pessoa sintética
e não sobrecarregar `actor_membership_id` legado. Tentativas negadas são
auditadas depois de validar a sessão, com minimização equivalente. Rotação de
segredo, refresh token, JWT, e-mail, nome, CPF, payload completo, cabeçalho e
endereço de rede não entram em logs, analytics, erro ou evidência de teste.

## Bootstrap e contextos mínimos

O primeiro Owner é criado apenas por operação administrativa server-side
autorizada, fora do cliente e sem segredo no repositório. A sequência é:

1. provisionar no mesmo projeto uma conta Auth nova, com e-mail profissional
   distinto e sem vínculo global;
2. criar uma `superadmin_internal_identities` e um
   `superadmin_internal_auth_links` `active` para seu `auth_user_id`;
3. criar uma membership `active`, de `scope_kind = 'platform'`, com o papel
   catálogo `owner`;
4. confirmar MFA e AAL2 no primeiro bootstrap; sem AAL2, retornar
   `SAI_MFA_REQUIRED`;
5. registrar apenas IDs opacos e resultado no audit.

O primeiro Owner usa escopo de plataforma global. Uma membership institucional
tem instituição explícita, e a seleção institucional é somente uma resolução
efêmera; não criar seleção persistida de tenant, unidade, grupo, criança ou
contexto familiar para o Superadmin interno. Domínios que operam sobre
instituições recebem o recurso alvo, mas validam capacidade, membership e escopo
server-side no comando; nunca recebem um `tenant_id` confiável da UI.

## Estratégia incremental por domínio

1. **Fundação privada.** Após desbloquear o ledger, criar tipos, identidade,
   `auth_link`, memberships com escopo, gatilhos de exclusão, helper, wrappers
   públicos de bootstrap/resolução e extensão de audit em migration forward-only;
   manter todos os consumidores legados inalterados neste passo.
2. **Bootstrap/Auth.** Provar Owner AAL2, sessão inválida, conta global negada,
   membership suspensa/revogada e ausência de dados antes do contexto. Não criar
   pessoa sintética nem backfill de `platform_memberships`.
3. **Catálogos e governança.** Migrar os comandos de perfis/capacidades para o
   helper interno, um domínio por vez, com versão, último Owner, motivo e
   auditoria. Manter legado e novo caminho separados.
4. **Demais domínios Superadmin.** Migrar cada RPC/RLS por capability, começando
   por leitura e depois mutações. Só retirar o caminho legado após testes
   positivos, negativos, cross-app e regressão do domínio.
5. **Encerramento.** Quando nenhum consumidor usar `platform_memberships` como
   principal interno, desativar sua autorização para Superadmin em migration
   separada e preservar somente o histórico auditável. Não apagar nem renomear
   migrations aplicadas.

## Critérios de aceite e testes exigidos

- uma conta Admin/Principal, mesmo autenticada, não obtém bootstrap nem chama
  comando interno; uma conta interna não pode ser ligada a `people`;
- dois Auth users distintos com e-mails distintos coexistem no mesmo projeto,
  sem compartilhar sessão, perfil, membership, cache ou autorização;
- `auth.uid()`, `auth.jwt().session_id` e `auth.sessions` divergentes negam
  antes de qualquer leitura/escrita; logout, sessão expirada ou revogada também;
- Owner em AAL1 recebe envelope `SAI_MFA_REQUIRED` no bootstrap, na resolução
  institucional e em toda ação; Owner AAL2 passa quando autorizado; não-Owner em
  AAL1 só executa capacidade sem `requires_mfa`;
- `auth_link` e membership `active` autorizam apenas papel/capacidade ativos;
  qualquer `auth_link` ou membership `suspended`/`revoked` nega imediatamente,
  inclusive em token/cache anterior;
- membership `platform` só resolve instituição autorizada pela capacidade e
  membership `institution` só resolve sua FK; trocar `p_institution_id` não
  persiste contexto nem amplia escopo;
- ausência de capacidade, role inativo, ID adulterado, contexto/tentativa de
  tenant cruzado, `request_id` repetido e versão obsoleta retornam envelope
  estável sem dado prévio, com status semântico sugerido; via PostgREST direto,
  o HTTP é 200 e o cliente decide por `ok`/`error.code`. Cada negativa reverte
  sua subtransação e deixa audit append-only com o mesmo `correlation_id`;
- última membership Owner global ativa não pode ser suspensa, revogada,
  rebaixada ou receber escopo incompatível; seu contexto continua exigindo AAL2
  em toda chamada e a prova inclui concorrência;
- pgTAP cobre schemas, FKs, índices, constraints, RLS/grants, `search_path`,
  `PUBLIC`, catálogo, AAL, sessão, transições permitidas, auditoria e
  cross-app/cross-tenant; teste de integração cobre login → AAL → bootstrap →
  comando → revogação → nova tentativa;
- `EXPLAIN` confirma índices usados nos lookups de Auth/membership; Advisors são
  reexecutados e qualquer achado classificado; logs/evidências passam scan sem
  segredo ou PII;
- somente após ledger reconciliado, reset realmente isolado, tests locais,
  ambiente remoto autorizado, Advisors e E2E sem mock o recorte pode ser
  `remote-green`; `done` exige também regressão e atualização do rastreador.

## Bloqueios de ledger e decisões remanescentes

Esta spec decide OQ-034 e OQ-035, mas não autoriza criar migration agora. A
implementação para no primeiro bloqueio abaixo:

1. o replay do HEAD não é reproduzível devido à cronologia de
   `20260811220646_institution_import_export`; antes de nova migration, recuperar
   a proveniência ou aprovar reparo de compatibilidade forward-only;
2. canônico/mirror/ledger local/remoto ainda exigem reconciliação e o banco local
   compartilhado não é prova de reset limpo;
3. a extensão de `audit.audit_logs` para ator interno tipado deve ser desenhada
   na mesma migration da fundação, sem falsificar `actor_person_id`;
4. OQ-006 continua aberta para a política de MFA de demais perfis: esta spec só
   aplica o catálogo `requires_mfa` já aprovado e não inventa novos requisitos;
5. recuperação/reset, convite e transições de provisionamento continuam fora de
   escopo e requerem spec própria antes de habilitação produtiva.

Nenhum desses bloqueios permite degradar para `platform_memberships`, pessoa
sintética, claim mutável, e-mail como autorização ou `service_role` no cliente.
