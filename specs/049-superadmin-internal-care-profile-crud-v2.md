---
title: "CRUD v2 de Perfis de cuidado para o Superadmin interno"
source: "decisions/0017-access-profile-governance.md; decisions/0019-superadmin-internal-identity.md; specs/020-superadmin-health-care.md; specs/039-superadmin-internal-auth-session-context.md; decisão do Owner Coelo em 2026-08-28 pelas opções B+C e recorte exclusivamente Superadmin"
status: "draft-for-review"
generated_at: "2026-08-28"
---

# CRUD v2 de Perfis de cuidado para o Superadmin interno

## Objetivo e decisão de produto

Criar um contrato Supabase aditivo para o diretório, detalhe, criação, edição,
reload e arquivamento de **Perfis de cuidado no Superadmin**. Esta spec não
cria nenhuma autoridade, tela ou integração para os aplicativos Admin ou
Principal.

O Owner Coelo escolheu a combinação B+C:

- o Owner interno global pode acessar todos os Perfis de cuidado;
- o mesmo diretório pode ser restringido por instituição e por unidade;
- os demais usuários internos recebem ações pelo catálogo de Perfis de Acesso,
  nunca por bypass implícito do nome do papel;
- o backend precisa suportar um gestor interno restrito a uma ou mais unidades,
  sem ampliar o escopo global da membership da spec 039.

O Owner global recebe grants e assignment explícitos. O acesso não nasce do
texto `owner`: cada chamada continua exigindo papel, capacidade, grant,
membership e assignment ativos. A proteção do último Owner global impede que o
último administrador funcional perca simultaneamente esses grants ou seu
assignment `platform`.

## Escopo

- catálogo mínimo de capacidades `care_profiles.read`,
  `care_profiles.manage` e `care_profiles.archive`;
- grants iniciais explícitos e proteção do último Owner global funcional;
- assignments privados do domínio com alcance `platform`, `institution` ou
  `unit`, sempre subordinados ao teto da membership interna;
- diretório paginado com filtros limitados, detalhe e reload;
- criação, edição versionada e arquivamento terminal;
- catálogo server-side dos itens já aprovados na experiência demonstrativa;
- idempotência, concorrência, auditoria v2/v3 e envelopes estáveis;
- schema deny-by-default e testes locais com dados exclusivamente sintéticos.

## Fora de escopo

- qualquer tela, repository, papel, membership ou gateway do Admin ou do
  Principal;
- responsáveis, profissionais institucionais, suporte clínico ou familiares;
- medicamentos, doses, alergias estruturadas, arquivos, anexos, contatos,
  importação, exportação, notificações e recibos de ciência;
- taxonomia editável, aprovação de novos termos e orientação institucional;
- listagem de crianças sem contexto institucional ativo;
- alteração do enum ou da tabela de memberships internas da spec 039;
- comando produtivo para criar/editar Perfis de Acesso ou assignments Care;
- backfill de ator `people`, pessoa sintética ou ponte com memberships legadas;
- definição de base legal ou prazo de retenção;
- alteração Flutter, E2E, deploy, migration ou fixture no projeto remoto.

## Autoridade exclusiva e separação entre aplicativos

Toda RPC começa por
`app_private.require_superadmin_internal_context(<capability>)`. O helper
revalida `auth.uid()`, `session_id`, `auth.sessions`, Auth user, auth link,
membership, papel, capacidade, grant, AAL e lifecycle conforme a spec 039.

Nenhuma decisão de autorização consulta ou aceita como autoridade:

- `people`, `person_auth_links` ou `platform_memberships`;
- `institution_memberships`, responsável, profissional ou vínculo familiar;
- papel, instituição, unidade, criança ou tenant informados pelo cliente;
- claims mutáveis, rota, filtro, e-mail ou metadados do usuário;
- `service_role` ou o nome textual `owner` como bypass.

`child_person_id` continua sendo a identidade do recurso protegido. Ele não
transforma a pessoa da criança em ator do comando.

## Capacidades e Perfil de Acesso

As três capacidades pertencem a `public.platform_permissions`:

| code | ação | risco | MFA |
| --- | --- | --- | --- |
| `care_profiles.read` | diretório, detalhe e reload | `critical` | obrigatório |
| `care_profiles.manage` | criar e editar | `critical` | obrigatório |
| `care_profiles.archive` | arquivar terminalmente | `critical` | obrigatório |

Labels: módulo `health`/`Saúde`, tela `care_profiles`/`Perfis de cuidado` e
ações `read`/`Consultar`, `manage`/`Criar e editar`,
`archive`/`Arquivar`.

O estado inicial concede `allow` ativo das três capacidades somente ao perfil
Owner. Operations, Auditor, Support e Content começam sem grants. Perfis
personalizados futuros poderão receber qualquer combinação pelo contrato de
governança de Perfis de Acesso; esta spec materializa e consulta o catálogo,
mas não implementa o comando de gestão desses grants.

Não há equivalência implícita entre ações:

- `read` não cria, edita nem arquiva;
- `manage` não concede leitura nem arquivamento;
- `archive` não concede leitura nem edição;
- `deny`, grant inativo ou revogado prevalece sobre `allow`.

Owner não possui bypass. A garantia de autoridade global é física: grant ativo
para as três capacidades, membership interna Owner ativa com escopo `platform`
e assignment Care `platform` ativo. Um guard impede a remoção da última cadeia
Owner global funcional, preservando a ADR 0019.

## Escopo efetivo e assignments privados

A spec 039 continua com membership apenas `platform|institution`. Esta spec não
altera `app_private.superadmin_internal_scope_kind`, o contexto de Auth, o
bootstrap, a proteção do último Owner nem consumidores já implantados.

O domínio cria
`app_private.superadmin_internal_care_scope_assignments` com:

- `id uuid` PK;
- `internal_membership_id uuid` FK;
- `scope_kind` em enum privado Care `platform|institution|unit`;
- `institution_id uuid` nullable;
- `unit_id uuid` nullable;
- `status` em `active|suspended|revoked`;
- `created_at`, `suspended_at`, `revoked_at`;
- `changed_by_internal_identity_id uuid` FK;
- `provisioning_kind` em `migration_bootstrap|command`;
- `version bigint > 0`.

Checks exatos:

- `platform`: instituição e unidade nulas;
- `institution`: instituição obrigatória e unidade nula;
- `unit`: instituição e unidade obrigatórias;
- `(unit_id, institution_id)` referencia
  `public.units(id, institution_id)`;
- revogação é terminal e a linha histórica não pode trocar membership, escopo
  ou recurso;
- `changed_by_internal_identity_id` pode ser nulo somente quando
  `provisioning_kind='migration_bootstrap'`; comandos futuros exigem ator
  interno validado.

O conjunto efetivo é a interseção entre o teto da membership interna e a união
dos assignments Care ativos:

- membership `platform` aceita assignments `platform`, `institution` e `unit`;
- membership `institution` aceita apenas a mesma instituição ou unidades dessa
  instituição;
- assignment `platform` é inválido sob membership `institution`;
- múltiplos assignments de unidade formam união explícita;
- assignments sobrepostos não duplicam perfis;
- ausência, suspensão ou revogação de todos os assignments nega acesso; nunca
  existe fallback para o escopo mais amplo da membership.

Filtros de instituição ou unidade enviados pelo cliente somente estreitam o
conjunto já autorizado.

### Bootstrap e proteção do Owner global

A migration faz bootstrap determinístico somente para memberships internas
que, no mesmo snapshot, estejam ativas, tenham escopo `platform`, papel ativo
com código `owner` e auth link ativo. Para cada membership elegível nasce
exatamente um assignment Care `platform`, com
`provisioning_kind='migration_bootstrap'` e ator de mudança nulo. Isso registra
proveniência de migration sem atribuir falsamente a ação a uma pessoa.

Nenhum assignment é criado para outro papel, escopo ou lifecycle. Se não houver
Owner elegível, não se inventa identidade e o domínio permanece deny-by-default.
Depois da migration, novos Owners só recebem Care quando o futuro comando
server-side de provisionamento criar o assignment explicitamente; até lá, a
ausência continua negando acesso. Esse comando permanece fora desta spec e é
gate de cutover, não fallback de autorização.

Guards transacionais compartilham advisory lock de governança e impedem que a
última cadeia Owner global funcional seja quebrada por:

- remoção, inativação, revogação ou troca para `deny` de qualquer uma das três
  relações Owner-capacidade;
- suspensão, revogação, exclusão ou redução de escopo do último assignment
  Care `platform` elegível;
- alterações concorrentes que, avaliadas separadamente, removeriam dois
  Owners/assignments e deixariam zero cadeia funcional.

O guard conta somente role, permission, grant, membership, auth link e
assignment todos ativos, com Owner em escopo `platform`. Ele não concede acesso
e não substitui a revalidação normal das RPCs.

## Visibilidade da criança e hierarquia

Um perfil fica visível somente se a criança possuir contexto infantil ativo e
coerente com ao menos um assignment Care ativo:

- assignment `platform`: qualquer contexto infantil ativo;
- assignment `institution`: `child_contexts.institution_id` igual ao
  assignment;
- assignment `unit`: `child_unit_links` ativo, não revogado e ligado a uma
  unidade da mesma instituição do contexto e do assignment.

Instituição, unidade e criança são derivadas por joins e FKs do servidor. A
consulta aplica o predicado de escopo no mesmo statement/snapshot que lê ou
trava o perfil. UUID inexistente, arquivado ou fora do escopo produz a mesma
negação, sem confirmar a existência do recurso.

O DTO institucional ou de unidade continua sendo o mesmo DTO global
minimizado. O escopo muda quais perfis podem ser vistos, não revela uma versão
mais ampla nem mais clínica do registro.

## Modelo físico mínimo

O pacote será forward-only e reconstruído; não restaura as migrations
históricas people-based `20260812123500`, `20260812124000`,
`20260813182000` ou `20260813184051`.

### `public.care_profiles`

- `id uuid` PK;
- `child_person_id uuid` FK e único entre perfis não arquivados;
- `operational_status` em `active|implementation|inactive`;
- `current_version bigint > 0`;
- `created_by_internal_identity_id uuid` FK;
- `updated_by_internal_identity_id uuid` FK;
- `created_at`, `updated_at`, `archived_at`;
- `archived_by_internal_identity_id uuid` FK nullable.

Arquivamento é terminal. Não há DELETE, restore implícito nem reutilização da
linha arquivada como perfil ativo.

### `public.care_profile_catalog_items`

- código textual estável, grupo, label, ordem, status e timestamps;
- seed exato do catálogo aprovado em
  `apps/superadmin/lib/features/health_care/domain/health_care.dart`;
- `other` exige texto complementar; os demais códigos não aceitam texto livre;
- esta spec não expõe RPC de gestão do catálogo.

### `public.care_profile_revisions` e `public.care_profile_revision_items`

Cada versão imutável registra perfil, versão, ator interno, timestamp e
justificativa minimizada. Os itens normalizados registram código do catálogo,
posição e `other_text` quando permitido. Uma versão publicada nunca é
reescrita; edição cria exatamente uma nova revisão e avança
`care_profiles.current_version`.

### Recibos privados

`app_private.superadmin_internal_care_command_receipts` guarda apenas:

- `request_id` PK;
- `actor_internal_identity_id` e `internal_membership_id`;
- comando, perfil/criança, versão esperada e versão resultante;
- hash canônico de 32 bytes;
- correlação original e timestamp.

O hash cobre comando, recurso, versão esperada e payload já validado e
normalizado; não armazena conteúdo clínico nem PII. O replay reautoriza sessão,
capacidade e escopo antes de consultar ou devolver o recibo.

## Interfaces públicas

Todas as RPCs são `SECURITY DEFINER`, `SET search_path=''`, `VOLATILE` quando
auditam e executáveis somente por `authenticated`. PUBLIC, `anon` e
`service_role` ficam explicitamente revogados. Helpers privados e tabelas não
possuem grants de cliente.

- `public.superadmin_care_profile_directory_v2(...)`
  exige `care_profiles.read`;
- `public.superadmin_care_profile_detail_v2(p_profile_id uuid)`
  exige `care_profiles.read` e também serve ao reload;
- `public.superadmin_create_care_profile_v2(p_request_id uuid,
  p_child_person_id uuid, p_expected_version bigint, p_payload jsonb)`
  exige `care_profiles.manage` e `expected_version=0`;
- `public.superadmin_edit_care_profile_v2(p_request_id uuid,
  p_profile_id uuid, p_expected_version bigint, p_payload jsonb)`
  exige `care_profiles.manage`;
- `public.superadmin_archive_care_profile_v2(p_request_id uuid,
  p_profile_id uuid, p_expected_version bigint, p_reason text)`
  exige `care_profiles.archive`.

## Diretório e saída minimizada

O diretório aceita somente:

- busca literal normalizada, no máximo 120 caracteres;
- `institution_ids` e `unit_ids`, no máximo 20 UUIDs por filtro;
- status operacionais, no máximo os três valores físicos;
- cursor opaco derivado de `(display_name, profile_id)`;
- `limit` entre 1 e 100, default 20 quando omitido.

`NULL` explícito em parâmetros obrigatórios ou filtros inválidos gera
`SAI_INVALID_ARGUMENT`. `%`, `_` e barra na busca são literais. O servidor
limita quantidade e bytes totais dos filtros.

Cada item retorna somente:

- `profile_id`, `child_person_id`, `display_name`;
- `operational_status`, `current_version`, `updated_at`;
- contextos visíveis minimizados com IDs e labels de instituição/unidade;
- `care_item_count`.

O detalhe acrescenta `items[{catalog_item_id,label,other_text,position}]`.
Não retorna nascimento, CPF, e-mail, contato, endereço, responsável, Auth ID,
medicamento, dose, alergia estruturada, arquivo, sessão, receipt, hash ou audit.

## Escrita, idempotência e concorrência

O servidor valida shape JSON exato, tipos, limites por campo, cardinalidade do
array, duplicidade de código, catálogo ativo e texto `other`. Chaves extras,
escalares coercíveis e caracteres de controle são recusados.

Ordem de comando:

1. revalidar contexto, capacidade, AAL2 e assignment;
2. adquirir advisory lock por `request_id`;
3. verificar recibo e reautorizar seu recurso;
4. travar perfil e contexto infantil autorizado;
5. comparar `expected_version`;
6. aplicar perfil/revisão/itens e recibo na subtransação;
7. append de auditoria fora do bloco capturador;
8. retornar acknowledgment mínimo e exigir reload para o agregado atual.

Mesmo request e mesmo hash retorna replay sem nova revisão. Mesmo request com
hash diferente falha. Duas edições da mesma versão resultam em um sucesso e um
`SAI_CONCURRENT_CHANGE`.

## Envelope, erros e não enumeração

As RPCs retornam `{ok,data,error}` em resposta PostgREST semanticamente 200.
`error` contém somente `code`, mensagem segura, `correlation_id` e
`http_status` semântico. Códigos mínimos:

- `SAI_AUTH_REQUIRED`/401;
- `SAI_SESSION_INVALID`/401;
- `SAI_PERMISSION_DENIED`/403;
- `SAI_MFA_REQUIRED`/403;
- `SAI_INVALID_ARGUMENT`/400;
- `SAI_CONCURRENT_CHANGE`/409;
- `SAI_REQUEST_REUSED`/409;
- `SAI_INTERNAL_ERROR`/500.

Missing, arquivado e cross-scope convergem em `SAI_PERMISSION_DENIED`. Falha
interna desconhecida nunca vira 403 e nenhum SQLSTATE, nome de tabela, ID
interno ou detalhe de constraint chega ao cliente.

## Auditoria

Após sessão Auth válida:

- ator interno completo usa audit v2;
- sessão válida sem link/membership usa audit v3;
- cada resultado gera exatamente um evento com a mesma correlação;
- falha do append aborta a RPC e qualquer mutação/recibo;
- negativas que ainda não validaram sessão não fabricam ator.

O evento guarda capacidade, ação, resultado, reason code, perfil/criança opacos,
instituição/unidade somente após validação e versão. Não guarda nome, itens do
perfil, justificativa clínica, reason bruto, JWT, session hash em readers,
receipt ou payload antes/depois.

## RLS, ACL e owner

Todas as tabelas novas usam `ENABLE ROW LEVEL SECURITY` e
`FORCE ROW LEVEL SECURITY`, zero policy permissiva e zero grants a PUBLIC,
`anon`, `authenticated` ou `service_role`. O acesso ocorre somente pelos
gateways públicos nominais. Todas as FKs e filtros de autorização têm índices.

A migration recusa execução fora do owner esperado, overloads preexistentes,
capability/grant/label divergente, falta da spec 039, hierarquia física
incompatível ou default ACL inseguro. Funções privadas e públicas precisam de
owner `postgres`, `SECURITY DEFINER` quando privilegiadas e `search_path` vazio.

## Release local e remoto

A decisão de 2026-08-28 autoriza implementação e testes locais com dados
sintéticos, mas não aprova base legal, retenção, dados reais ou deploy. A
migration não altera nem aprova automaticamente os cinco
`health_domain_release_gates` existentes.

O pacote pode atingir no máximo `local-green`. Fixtures positivas podem abrir
o gate somente dentro de transação local e precisam terminar em rollback. Um
futuro deploy/ativação é pacote separado, com autorização explícita e revisão
dos gates vigentes.

## RED e testes exigidos

O pgTAP precisa provar, no mínimo:

- RED pré-migration dos objetos e wrappers;
- set exato das três capacidades, labels, risco, MFA e grants Owner-only;
- Owner negado quando capacidade, papel ou grant fica inactive, revoked ou
  deny, demonstrando ausência de bypass;
- bootstrap cria exatamente um assignment `platform` por membership Owner
  global elegível, nenhum para demais papéis/escopos, sem ator sintético;
- tentativa individual de remover, inativar, revogar ou tornar `deny` cada um
  dos três grants da última cadeia Owner é bloqueada;
- suspensão, revogação, exclusão ou redução do último assignment Owner
  `platform` é bloqueada, e duas remoções concorrentes preservam ao menos uma
  cadeia funcional;
- novo Owner sem assignment explicitamente provisionado permanece negado;
- Auth/session/link/membership, AAL1 e cross-app Admin/Principal negados;
- assignments platform, institution, unit, multiunit e sobrepostos positivos;
- ausência, suspensão, revogação, ceiling incompatível, instituição/unidade
  trocada, sibling unit e UUID adulterado negativos;
- revogar o último assignment de unidade não amplia acesso;
- Owner global filtrando uma instituição e gestor unitário sem enxergar a
  instituição inteira;
- `read`, `manage` e `archive` independentes;
- DTO exato, minimização, busca literal, paginação e no-oracle;
- create, detail, edit, reload e archive persistentes;
- request replay, reuse com payload diferente, versão obsoleta e concorrência;
- uma revisão por versão e arquivamento terminal;
- audit v2/v3 1:1 e falha adversarial do append revertendo mutação e recibo;
- owner, `prosecdef`, `search_path`, overloads, ACL, FORCE RLS, zero policies e
  negação a `service_role`;
- gate remoto inalterado, cleanup/rollback das fixtures, mirror, diff-check,
  secret scan e teardown sem recursos Docker residuais.

Regressões mínimas: Auth/contexto, Instituições detail/list, Unidades detail,
Grupos detail e Pessoas detail. Nenhuma delas promove Flutter ou E2E.

## Critérios de aceite

- somente um principal interno Superadmin autorizado alcança as RPCs;
- capability e assignment são obrigatórios e nenhuma role recebe bypass;
- Owner global, instituição e unidade respeitam a mesma saída minimizada;
- filtros do cliente apenas estreitam o conjunto autorizado;
- CRUD versionado persiste, recarrega, não duplica e falha fechado;
- tabelas e helpers permanecem inacessíveis diretamente;
- negativos, cross-app, cross-tenant, sibling unit, AAL e lifecycle são verdes;
- auditoria é minimizada, 1:1 e transacionalmente obrigatória;
- migration forward-only, pgTAP, regressões, mirror, cleanup e trackers ficam
  reconciliados no ambiente local efetivamente testado;
- o estado final é `local-green`, nunca `remote-green`, E2E ou `done`.

## Riscos e follow-ups

- o comando interno para gerir grants e assignments Care na tela Perfis de
  Acesso é follow-up obrigatório antes do cutover produtivo;
- eventual escopo `unit` global da membership interna exige ADR/spec Auth
  própria e não pode ser introduzido por esta migration;
- retenção, base legal, release gates e dados reais continuam separados;
- o repository Flutter atual é demonstrativo/indisponível para produção e seu
  cutover pertence ao rastreador integrado;
- medicamentos, alergias, arquivos e taxonomia editável exigem contratos
  independentes.
