---
title: "Activities cross-app backend v2"
source: "AGENTS.md; decisions/0014-contextual-activities-and-delegated-unit-creation.md; decisions/0019-superadmin-internal-identity.md; decisions/0022-superadmin-activities-and-identity-storage.md; specs/014-atividade-contextual.md; specs/039-superadmin-internal-auth-session-context.md; docs/superpowers/specs/2026-07-29-superadmin-activity-inspection-design.md; docs/superpowers/specs/2026-08-04-superadmin-activity-form-wizard-design.md; contrato aprovado pelo Owner Coelo em 2026-08-31"
status: "approved-for-implementation"
generated_at: "2026-08-31"
---

# Activities cross-app backend v2

## Decisao

Adotar uma arquitetura em camadas:

1. entidades, invariantes e helpers de dominio privados compartilhados;
2. gateways nominais separados por aplicativo e tipo de ator;
3. contratos de resposta estaveis que possam ser consumidos por Flutter sem
   transformar o cliente em autoridade.

O primeiro gateway executavel desta fatia e o Superadmin interno. O modelo
preserva as entidades necessarias ao futuro Admin e Principal, mas nao cria
endpoints, grants ou capacidades para esses aplicativos agora.

A aprovacao Owner de 2026-08-31 substitui somente estes contratos anteriores:

- o trecho da spec 014 que limitava o Superadmin a leitura;
- o transporte atomico unico do wizard de 2026-08-04, substituido por comandos
  pequenos que sempre deixam um draft valido e encadeiam versao;
- a classificacao historica de publicacao como fora de escopo.

Ela nao remove o requisito do wizard de ao menos uma turma para publicacao e
nao altera locations, templates, arquivos ou midia. Esses campos permanecem
inalterados e nao sao gravados pelos comandos desta fatia. O adapter Flutter
atual continua pendente porque ainda chama o aggregate legado unico.

Reutilizacao cross-app nao significa compartilhar uma RPC privilegiada. O
Superadmin usa identidade interna; Admin e Principal continuarao usando pessoa
global, membership e contexto institucional ou familiar. Cada gateway resolve
seu proprio ator e chama apenas helpers privados que recebem um contexto ja
validado e tipado.

## Motivo

O aggregate legado de Activities resolve autoria e autorizacao por
`current_person_id()`. Isso e valido para o realm people-based, mas nao para a
identidade interna aprovada na ADR 0019 e spec 039. Misturar os dois realms na
mesma condicao de autorizacao, criar uma pessoa sintetica ou confiar em IDs do
payload produziria autoria ambigua e risco de acesso cruzado.

A separacao de gateways permite reutilizar as mesmas regras de tenant,
estrutura, participants e professionals sem conceder ao Admin ou Principal as
permissoes globais do Superadmin.

## Alternativas consideradas

### A. Dominio privado compartilhado e gateways segmentados

Escolhida. Mantem capabilities independentes, contratos pequenos e fronteiras
de ator explicitas.

### B. Um unico aggregate publico para todo o formulario

Foi rejeitado para o gateway v2. Embora atomico, exige autorizacao dinamica
complexa, acopla secoes independentes e torna mais dificil provar que uma
capability nao implica outra.

### C. Adaptar a RPC people-based existente para os dois realms

Rejeitada. Misturaria `current_person_id()` com identidade interna, aumentaria
o risco de bypass e produziria auditoria incorreta ou duplicada.

## Escopo desta fatia

Incluido:

- listar, detalhar, criar, editar e publicar Activities;
- ligar e desligar unidades e turmas;
- participantes por vinculo infantil canonico;
- profissionais nos papeis `instructor` e `activity_admin`;
- permissoes granulares de `chat`, `now`, `happens`, `moments` e
  `attendance`;
- RLS, grants minimos, autoria tipada, auditoria, idempotencia e concorrencia;
- provas tenant A/B, sibling unit, cross-app, membership e IDs adulterados;
- compatibilidade estrutural para futuros gateways Admin e Principal.

Fora de escopo:

- qualquer alteracao em `apps/**`, Flutter ou UI/UX;
- gateways publicos novos para Admin ou Principal;
- importacao, exportacao, arquivos, upload, download, Storage ou operacao de
  midia;
- assessment, avaliacao, cancelamento ou conclusao de atividade;
- taxonomias novas alem do fluxo ja aprovado;
- mutacao remota.

Nada existente nesses dominios fora de escopo sera removido.

## Modelo de ator e autoria

Identificadores de identidade interna nao serao adicionados a tabelas `public`.
Essas tabelas ja possuem grants e consumers people-based; uma nova coluna
publica poderia vazar um identificador interno estavel por `select *`.

As tabelas gravadas pelo v2 recebem `*_actor_kind` como coluna generated stored,
derivada exclusivamente do campo `*_person_id`: person presente gera `person`;
person ausente gera `superadmin_internal`. O cliente e os writers nao podem
fornecer `actor_kind`. O campo `*_person_id` correspondente torna-se nullable.
Isso preserva os upserts legados: quando um writer people-based define person,
o kind muda atomicamente sem depender de ele conhecer a coluna nova.

O resultado exige:

- `actor_kind = 'person'` com `person_id` presente; ou
- `actor_kind = 'superadmin_internal'` com `person_id` ausente.

Um guard trigger fail-closed acompanha cada par. Person presente precisa ser a
pessoa resolvida pelo contexto people-based autorizado; person ausente somente
e aceito quando o trigger revalida o marcador transacional interno, auth link,
sessao e identidade. Assim um cliente Admin com DML historico nao consegue
enviar NULL e fabricar autoria `superadmin_internal`.

A identidade interna exata fica apenas no receipt e audit privados. Esses
registros sao a fonte canonica de quem executou o comando. O row publico
preserva a origem do realm sem expor a identidade. Autoria historica permanece
`person` por default/backfill forward-only.

O primeiro delta cobre somente tabelas realmente gravadas pela fatia:

- `activity_definitions`;
- `activity_unit_links`;
- `activity_group_links`;
- `activity_group_participants`;
- `activity_group_assignments`;
- `activity_admin_assignments`;
- `activity_assignment_capability_actions`;
- `activity_admin_capability_actions`;
- `activity_capability_policies`;
- `activity_group_capability_settings`.

Campos de autoria original nunca sao sobrescritos em remocao ou revogacao.
Essas mudancas posteriores usam o audit privado v2 como fonte canonica do ator.
Nenhum `person_id`, identity ID interno ou ator e aceito do cliente. O caminho
de taxonomia `outros` e rejeitado nesta fatia; somente `taxonomy_id` ativo e
canonico e aceito. Nao existe DDL condicional em runtime.

## Contratos publicos do Superadmin v2

Todos os wrappers publicos sao `SECURITY DEFINER`, `search_path = ''`, owned
por `postgres`, revogados de `PUBLIC`, `anon` e `service_role` e concedidos
nominalmente apenas a `authenticated`. Helpers privados tambem sao revogados de
`authenticated`. O wrapper valida sessao, lifecycle, AAL, membership, role,
capability e escopo antes de resolver o recurso.

Leitura:

- `superadmin_activity_directory_v2` — `activities.read`;
- `superadmin_activity_detail_v2` — `activities.read`;
- `superadmin_activity_form_options_v2` — retorna apenas opcoes minimizadas
  necessarias ao formulario e exige as capabilities correspondentes aos dados
  solicitados.

Comandos:

- `superadmin_activity_create_v2` — `activities.create` e
  `activities.link_units`;
- `superadmin_activity_update_v2` — `activities.manage`, somente campos
  proprios da Activity;
- `superadmin_activity_publish_v2` — `activities.manage`;
- `superadmin_activity_set_units_v2` — `activities.link_units`;
- `superadmin_activity_set_groups_v2` — `activities.link_groups`;
- `superadmin_activity_set_participants_v2` — `activities.assign_people`;
- `superadmin_activity_set_professionals_v2` — `activities.assign_people`;
- `superadmin_activity_set_permissions_v2` —
  `activities.manage_permissions`.

Ter `activities.manage` nunca implica linkar estrutura ou pessoas. Ter
`activities.assign_people` nunca implica editar permissoes e vice-versa.

### Assinaturas exatas

Todas as funcoes retornam `jsonb` no envelope `{ok,data,error}`.

| Funcao | Argumentos, na ordem |
| --- | --- |
| `superadmin_activity_directory_v2` | `(p_filters jsonb default '{}', p_limit integer default 24, p_offset integer default 0, p_sort text default 'name', p_sort_ascending boolean default true)` |
| `superadmin_activity_detail_v2` | `(p_activity_id uuid, p_sections text[] default '{}')` |
| `superadmin_activity_form_options_v2` | `(p_institution_id uuid, p_sections text[], p_search text default null, p_limit integer default 50)` |
| `superadmin_activity_create_v2` | `(p_request_id uuid, p_payload jsonb)` |
| `superadmin_activity_update_v2` | `(p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_payload jsonb)` |
| `superadmin_activity_publish_v2` | `(p_request_id uuid, p_activity_id uuid, p_expected_version bigint)` |
| `superadmin_activity_set_units_v2` | `(p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_unit_ids uuid[])` |
| `superadmin_activity_set_groups_v2` | `(p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_group_ids uuid[], p_group_participation jsonb)` |
| `superadmin_activity_set_participants_v2` | `(p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_participants jsonb)` |
| `superadmin_activity_set_professionals_v2` | `(p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_professional_assignments jsonb)` |
| `superadmin_activity_set_permissions_v2` | `(p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_capability_policies jsonb, p_group_capability_settings jsonb, p_professional_capability_actions jsonb)` |

Sucesso de comando retorna exatamente `activity_id`, `management_version`,
`status`, `correlation_id` e `replayed`. Cada comando nao-replay bloqueia
`activity_definitions FOR UPDATE`, compara a versao e a incrementa exatamente
uma vez. O cliente encadeia a versao retornada. Falha de uma secao posterior
preserva um draft valido, sem meia transacao do comando que falhou.

`create` aceita somente `institution_id`, `name`, `description`, `taxonomy_id`,
`icon_key`, `initials` e `unit_ids`. O gateway interno sempre deriva
`origin_scope_kind='institution'` e `origin_unit_id=null`; origem nunca vem do
cliente. Cria `draft` e pelo menos uma unidade ativa atomicamente. `update` aceita apenas
`name`, `description`, `taxonomy_id`, `icon_key` e `initials`; nao aceita status,
estrutura, pessoas ou permissoes. Strings, arrays e JSON rejeitam chaves extras,
duplicatas e limites acima dos definidos no plano TDD.

O directory aceita somente filtros `search`, `institution_id`, `status`,
`unit_id` e `group_id`; sorts `name`, `status`, `created_at` e `updated_at`;
`limit` entre 1 e 100, `offset >= 0` e busca de ate 120 caracteres. Retorna
`items`, `total`, `limit` e `offset`. Item permite exatamente `activity_id`,
`institution_id`, `institution_name`, `name`, `status`, `management_version`,
`icon_key`, `initials`, `unit_count`, `group_count`, `created_at`, `updated_at`.

`detail` sem sections retorna exatamente `activity`, `units`, `groups` e
`counts`. Activity permite `activity_id`, `institution_id`, `name`,
`description`, `taxonomy_id`, `taxonomy_name`, `status`, `management_version`,
`icon_key`, `initials`, `created_at`, `updated_at`; unit permite `unit_id`,
`name`, `status`; group permite `group_id`, `unit_id`, `name`, `status`,
`participation_mode`; counts permite `units`, `groups`, `participants`,
`instructors`, `activity_admins`. Sections
permitidas sao `participants`, `professionals` e `permissions`:

- `participants` e `professionals` exigem `activities.assign_people`;
- `permissions` exige `activities.manage_permissions`;
- todas tambem exigem `activities.read`.

Section desconhecida, duplicada ou nao autorizada falha a chamada inteira; nao
ha redacao silenciosa. Participant permite `child_group_link_id`, `group_id`,
`display_name`, `status`. Professional permite `membership_id`, `role`,
`group_id`, `display_name`, `status`. Permissions permite `policies`
(code/mode), `group_settings` (group/code/enabled) e `professional_actions`
(membership/role/group/actions). Nenhum actor/person ID, contato, DOB, genero,
audit ou campo fora dessas allowlists e retornado.

`form_options` exige `activities.read` e recebe sections fixas, nunca codigos de
capability arbitrarios: `taxonomy`; `structure` (`link_units` e `link_groups`);
`participants` e `professionals` (`assign_people`); `permissions`
(`manage_permissions`). Retorna somente as sections pedidas, busca limitada a
120 caracteres e no maximo 100 resultados por section. Criancas retornam link,
grupo e display name; professionals retornam membership, role code e display
name, sem DOB, genero, contato ou `person_id`. Taxonomy item permite somente
`taxonomy_id`, `code`, `name`; unit `unit_id`, `name`; group `group_id`,
`unit_id`, `name`; participant `child_group_link_id`, `group_id`,
`display_name`; professional `membership_id`, `display_name`, `role_code`;
capability `code`, `name`.

### Receipt, replay e lock order

`app_private.superadmin_internal_activity_command_receipts` usa
`request_id uuid` como PK global e guarda somente identidade interna,
institution/activity, `command_kind`, hash SHA-256 de 32 bytes,
`resulting_version`, status, correlation e contagens minimizadas. Payload,
nomes, pessoas, criancas e memberships nao sao armazenados.

O comando revalida sessao, lifecycle, capability e scope antes de devolver um
replay. Mesmo ator, kind, target e hash retornam o resultado armazenado com
`replayed=true`, sem nova mutacao, versao ou audit de dominio. Mesmo ator com
kind/target/hash diferente retorna `SAI_CONCURRENT_CHANGE`; outro ator recebe
`SAI_PERMISSION_DENIED`, evitando oracle de receipt.

A ordem e: reautorizacao, advisory lock derivado de request, receipt, lock da
Activity, comparacao de versao, locks de referencias, mutacao, audit e receipt.
O receipt so e persistido depois do audit aceito.

## Payloads e compatibilidade futura

Os contratos preservam, quando seguro, o formato ja conhecido pelo dominio
Flutter: `unit_ids`, `group_ids`, `participants` e
`professional_assignments`. IDs redundantes de pessoa, ator, assignment ou
activity-group link sao proibidos.

Cada `set_*` e um snapshot autoritativo completo de sua secao. `set_units` nao
pode remover a ultima unidade e falha com `ACTIVITY_DEPENDENCIES_ACTIVE` se uma
unidade removida ainda tiver turma ativa. `set_groups` exige que as chaves de
`group_participation` correspondam exatamente a `group_ids` e falha se uma
turma removida ainda tiver participant, instructor ou setting ativo. O cliente
limpa dependencias antes; nao existe cascade silencioso. Links removidos ficam
inativos e preservam historico.

Limites por comando: ate 100 units, 200 groups, 1.000 participants e 500
professionals/actions. Excesso, chave extra, tipo incorreto ou duplicata retorna
`ACTIVITY_INVALID_INPUT` antes de qualquer mutacao.

`p_group_participation` e um objeto cujas chaves sao exatamente os UUIDs de
`p_group_ids` em texto e os valores sao `all` ou `selected`. Mudar `selected`
para `all` enquanto houver participant explicito falha com
`ACTIVITY_DEPENDENCIES_ACTIVE`; o cliente limpa primeiro por
`set_participants`, preservando a independencia entre `link_groups` e
`assign_people`.

Participacao por turma usa `all` ou `selected`:

- `all` nao persiste selecao individual;
- `selected` recebe `child_group_link_id` e `belongs`;
- o servidor deriva crianca, pessoa, grupo, unidade e instituicao;
- um item invalido aborta o snapshot inteiro.

`p_participants` e array de objetos com exatamente `group_id uuid`,
`child_group_link_id uuid` e `belongs boolean`. Ele representa o estado completo
desejado de todos os groups atualmente `selected`: row ativo omitido ou com
`belongs=false` e desativado; `belongs=false` desconhecido e no-op sem
tombstone; `belongs=true` cria ou reativa. Groups `all` nao aceitam entradas.

Profissionais:

- `instructor` exige turma ativa vinculada;
- `activity_admin` pertence a Activity e nao recebe `group_id`;
- a pessoa e derivada exclusivamente da membership institucional;
- membership deve estar ativa, nao revogada, no mesmo tenant e representar
  pessoa adulta ativa;
- remocoes revogam logicamente e preservam historico.

`p_professional_assignments` e array com exatamente `membership_id uuid`,
`role instructor|activity_admin` e `group_id uuid|null`. `capabilities`,
`person_id` e assignment IDs sao rejeitados. `set_professionals` substitui,
numa unica transacao, o conjunto completo de
instructors e activity admins. O mesmo membership pode ser instructor em mais
de uma turma e activity admin ao mesmo tempo. Duplicata da mesma
role/membership/group e invalida. O papel `activity_admin` deixa de ser aceito
em novos `activity_group_assignments`; a migration faz preflight de legado e
restringe novos rows a `instructor` sem apagar dados historicos. Assignment
revogado nunca e reativado: um retorno cria novo assignment, sem actions, para
que permissoes antigas nao ressuscitem.

As permissoes profissionais usam exatamente cinco capabilities:
`chat`, `now`, `happens`, `moments` e `attendance`. Cada acao e `none`, `view`,
`edit` ou `both`. O mapa e explicito; ausencia nunca significa `both`.

O schema atual nao persiste permissoes granulares de `activity_admin`. A fatia
adiciona `activity_admin_capability_actions`, paralela as acoes de instructor,
com `id`, FK cascade para admin assignment, FK restrict para capability,
`can_view`, `can_edit`, timestamps, `changed_by_actor_kind`,
`changed_by_person_id`, unique por assignment/capability, constraints, indices,
FORCE RLS e nenhum grant de cliente. Isso corrige a perda silenciosa existente
sem implementar conteudo ou midia dessas capabilities.

`set_permissions` recebe tres snapshots completos e independentes:

- `p_capability_policies`: objeto com exatamente as cinco capability codes;
  valor `required|default_on|default_off|prohibited|null`, onde null remove a
  policy e restaura heranca;
- `p_group_capability_settings`: array `{group_id, capabilities}` sem extras;
  `capabilities` tem exatamente as cinco codes com valor `boolean|null`, onde
  null remove o setting daquela capability; group ativo omitido remove todos
  os seus settings, pois o array e snapshot completo;
- `p_professional_capability_actions`: array
  `{membership_id, role, group_id, actions}` sem extras; role e
  `instructor|activity_admin`, group e obrigatorio somente para instructor, e
  actions tem exatamente as cinco codes com `none|view|edit|both`.

O snapshot de actions aceita no maximo um item por assignment ativo. Assignment
omitido tem suas actions removidas e permissao efetiva `none`, impedindo
publish; item presente exige exatamente as cinco chaves. O servidor resolve o
assignment e nunca aceita person, actor ou assignment ID. Duplicatas e
referencias foreign/random usam os envelopes allowlisted sem enumeracao.

### Precedencia canonica de permissao operacional

Os codigos modernos `chat`, `now`, `happens`, `moments` e `attendance` ja foram
introduzidos pela migration de seguranca de 2026-08-11 e sao os unicos usados
pelo v2. Os codigos legados `conversation`, `events` e `media_now` permanecem
intactos e sem mapeamento implicito neste pacote.

Para instructor, a resolucao por capability e:

1. policy `prohibited` => `none`;
2. override legado `deny` => `none`;
3. action explicita v2 => `none`, `view`, `edit` ou `both`;
4. override legado `allow` => `both`;
5. policy `required` => `both`;
6. group setting presente => `both` ou `none`;
7. policy `default_on/default_off` => `both/none`;
8. profile allow/deny => `both/none`;
9. ausencia => `none`.

Para `activity_admin`, que nao tem profile/turma/override legado, policy
`prohibited` e limite absoluto; depois vale a action explicita e ausencia e
`none`. Quando a policy for `required`, actions v2 `none` sao invalidas para
instructor e activity admin; `view`, `edit` ou `both` explicitam a operacao
permitida sem transformar required em permissao irrestrita. O helper
people-based existente sera evoluido forward-only para aplicar
a mesma precedencia a instructor, preservando dados legados. Policy e settings
sao bloqueados e revalidados como conjunto para impedir contradicao criada pela
ordem das escritas.

## Invariantes de tenant e referencia

- contexto platform ativo pode operar instituicoes autorizadas globalmente;
  contexto institution recebe a instituicao do membership resolvido e nunca de
  um claim ou filtro do cliente;
- filtros do cliente apenas estreitam o conjunto autorizado;
- tenant B e UUID aleatorio produzem resposta indistinguivel;
- unidade deve estar ativa e pertencer a instituicao da Activity;
- turma deve estar ativa, pertencer a uma unidade ligada e ter FKs compostas
  coerentes;
- participant exige `child_group_link`, `child_unit_link` e `child_context`
  ativos no mesmo grupo, unidade e instituicao;
- professional exige membership e pessoa validas no mesmo tenant;
- nenhuma RPC confia em `person_id`, `tenant_id`, claims mutaveis ou
  `user_metadata` enviados pelo cliente;
- Principal futuro somente podera ver ou agir por vinculo familiar explicito;
  nenhuma permissao e criada nesta fatia.

## Publicacao

Publicacao e um comando dedicado `draft -> active`. Esta aprovacao substitui o
item historico que deixava publicacao fora da fatia de inspecao, somente para
essa transicao.

Pre-requisitos:

- nome e taxonomia validos;
- ao menos uma unidade ativa do mesmo tenant;
- ao menos uma turma ativa ligada, preservando o completion gate do wizard;
- se a origem for uma unidade, ela deve continuar ativa e ligada;
- nenhuma turma ativa pode apontar para unidade fora do conjunto;
- policies e settings nao podem estar em contradicao;
- participants ativos precisam manter todo o encadeamento infantil valido;
- professionals ativos precisam continuar com membership valida;
- cada instructor e activity admin ativo precisa ter as cinco actions
  persistidas; todas podem ser `none`, mas a intencao deve ser explicita.

Uma Activity pode ser publicada sem participant ou professional. Estados
diferentes de `draft` retornam `ACTIVITY_INVALID_STATE`, salvo replay do mesmo
`request_id`. O estado, `management_version` e audit sao o registro canonico da
publicacao; esta fatia nao inventa coluna `published_at`.

## RLS, grants e helpers

- tabelas expostas permanecem RLS deny-by-default;
- FORCE RLS e aplicado nas tabelas novas e nas tabelas gravadas pelo v2; uma
  excecao precisa ser nomeada, justificada e coberta por teste antes do GREEN;
- nenhum caminho interno e adicionado por `OR` as policies people-based;
- o gateway interno nunca usa DML direto; grants people-based historicos em
  policies/settings permanecem por compatibilidade ate existir gateway Admin
  nominal, e contas internas sem person link devem falhar nessas policies;
- helpers privados recebem contexto interno ja validado e nunca tratam UUID
  interno como autorizacao;
- default privileges permanecem seguros;
- toda nova FK e predicado real de autorizacao recebe indice adequado.

## Auditoria

O trigger legado `audit_activity_change()` atualmente resolve
`current_person_id()` em cinco tabelas tocadas pelo aggregate. O caminho v2
precisa impedir eventos legados com ator nulo e auditoria duplicada.

O wrapper v2 estabelece marcador transacional com identity, action, permission
e correlation somente depois de validar o contexto. O trigger somente suprime
o evento v1 quando revalida `auth.uid()`, auth link interno ativo, JWT
`session_id`, `auth.sessions` viva, lifecycle e a mesma identidade. Marcador
ausente, malformado ou forjado falha fechado. Em seguida, o comando grava
exatamente um evento interno tipado; falha no append aborta toda a transacao.

Auditoria registra apenas action code, IDs opacos necessarios, status, versao,
contagens e correlation/digest. Nomes, descricoes, criancas, pessoas,
memberships, JWT, session ID bruto e payload completo sao proibidos.

## Erros

O envelope permanece `{ok, data, error}`. Codigos de dominio:

- `ACTIVITY_INVALID_INPUT` (`http_status=422`) — shape, allowlist ou acao invalida;
- `ACTIVITY_INVALID_REFERENCE` (`http_status=422`) — referencia aninhada invalida, estrangeira,
  inativa ou aleatoria sem enumeracao;
- `ACTIVITY_NOT_FOUND` (`http_status=404`) — Activity ausente ou fora do escopo;
- `ACTIVITY_INVALID_STATE` (`http_status=409`) — transicao ou pre-requisito invalido;
- `ACTIVITY_DEPENDENCIES_ACTIVE` (`http_status=409`) — remocao estrutural que deixaria vinculos
  ativos.

Auth, sessao, lifecycle, capability, MFA e concorrencia reutilizam os codigos
`SAI_*` aprovados na spec 039. `error` permite somente `code`, `message`,
`http_status` e `correlation_id`; SQLSTATE, objeto interno e mensagem tecnica
nunca sao expostos. Tenant estrangeiro e UUID aleatorio comparam igualmente
code/status/message, desconsiderando correlation.

## Testes exigidos

O pgTAP deve provar, no minimo:

- assinaturas, owners, `search_path`, grants, RLS/FORCE RLS e constraints de
  ator;
- compatibilidade do aggregate Admin legado, ainda com autoria por pessoa e
  seu conjunto historico esperado de audits sem ator nulo; conta interna sem
  person link nao pode chama-lo;
- zero pessoa sintetica e zero evento de audit com ator nulo;
- sessao ausente, expirada, logout/revogada, auth link suspenso/revogado,
  role/capability inativa, deny explicito e membership interna
  suspensa/revogada;
- Owner AAL1 sempre negado; outro papel AAL1 permitido somente quando a
  capability ativa nao exigir MFA;
- independencia bidirecional de todas as capabilities;
- ator permitido, tenant A/B, sibling unit, cross-app e UUID adulterado;
- participant de grupo/unidade/tenant errado ou contexto infantil inativo;
- professional infantil, suspenso, revogado, estrangeiro ou em turma invalida;
- actions de instructor e `activity_admin`, inclusive `none/view/edit/both`;
- precedencia de policy `prohibited`, settings e acoes do assignment;
- snapshots atomicos, soft revocation, replay idempotente e conflito de versao;
- publicacao valida e todos os estados/pre-requisitos negativos;
- transicoes `selected/all`, dependencias de unidade/turma, limites,
  paginacao deterministica e duas transacoes concorrentes sem deadlock;
- exatamente um incremento de versao e um audit tipado por comando aceito;
- nenhum segredo, PII ou payload sensivel em receipt, audit ou evidencia.

Fixtures sao exclusivamente sinteticas e devem executar em transacao com
rollback ou cleanup comprovado.

## Implantacao e compatibilidade

As migrations sao forward-only. O delta deve ser dividido para reduzir locks:

1. autoria dual e indices;
2. tabela de permissoes de `activity_admin` e receipts privados;
3. helpers/gateways v2 e adaptacao segura de auditoria;
4. RLS/grants/default ACL e testes.

O remoto permanece somente leitura e `blocked-environment`. Nenhuma migration,
DDL, DML ou configuracao Auth remota e autorizada por este design.

O repository Flutter atual usa `superadmin_upsert_activity` numa unica chamada.
Este backend pode ficar `local-green`, mas a tela permanece fail-closed e
Flutter/E2E pendentes ate um adapter futuro encadear create/update, snapshots e
publish com recuperacao de draft. Este documento nao promove nenhum estado de
tela.

## Criterios de aceite

- Superadmin interno executa directory/detail/create/update/publish e os
  snapshots autorizados sem depender de pessoa global;
- tenant A/B e cross-app negativos passam;
- participantes e profissionais avancados persistem, recarregam e revogam com
  permissao granular correta;
- Admin legado continua funcional e isolado;
- o modelo permite gateways futuros Admin e Principal sem reutilizar a RPC
  privilegiada do Superadmin;
- replay local limpo, pgTAP, lint, mirror/hash, secret scan e regressao ficam
  verdes;
- nenhuma alteracao em Flutter, UI, importacao, exportacao, arquivo ou midia.
