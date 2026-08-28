---
title: "Detalhe e reload v2 de Pessoas para o Superadmin interno"
source: "specs/019-superadmin-people-directory.md; specs/039-superadmin-internal-auth-session-context.md; specs/040-superadmin-internal-institution-read-v2.md; decisions/0019-superadmin-internal-identity.md; apps/superadmin/lib/core/config/superadmin_auth_scope.dart; apps/superadmin/lib/features/people/domain/person_directory.dart; apps/superadmin/lib/features/people/data/supabase_person_directory_repository.dart"
status: "approved-for-implementation"
approval: "Coordenação Coelo em 2026-08-28; recorte técnico derivado das specs 019, 039 e 040"
generated_at: "2026-08-28"
---

# Detalhe e reload v2 de Pessoas para o Superadmin interno

## Objetivo e problema

Migrar somente o detalhe e o reload de Pessoas para a identidade interna
exclusiva da spec 039. O contrato precisa entregar a identidade global e os
vínculos contextuais estritamente necessários ao formulário atual sem usar
`people`, `person_auth_links`, `platform_memberships` ou overrides legados como
autoridade do ator.

O pacote é aditivo. As RPCs e policies antigas permanecem separadas até o
cutover Flutter, mas não podem ser chamadas, incorporadas ou combinadas por
`OR` no caminho v2. A existência do legado não constitui evidência de
autorização, integração ou conclusão desta spec.

## Escopo

- detalhe de adulto, criança ou pessoa de serviço existente;
- reload por uma nova chamada com o mesmo `person_id`;
- `people.read`, papel `owner`, AAL2 e escopo interno `platform` ou
  `institution` revalidados em cada chamada;
- visibilidade da pessoa derivada dos vínculos persistidos no servidor;
- memberships adultas e contextos infantis ativos, válidos, coerentes e
  filtrados pelo escopo efetivo;
- resumo coarse do vínculo Auth somente para compatibilidade com o parser e a
  apresentação atuais, sem ID de Auth, e-mail ou estado detalhado;
- envelope estável, auditoria v2/v3, ACL mínima, não enumeração e saída
  minimizada.

## Fora de escopo

- listagem, busca, filtros, paginação e opções de filtros;
- criar ou editar pessoa, membership, papel, contexto infantil ou link;
- status, convite, login, recuperação, MFA, identidade exata por contato ou
  criação de `auth.users`/`person_auth_links`;
- contatos, endereço, CPF, nascimento, foto, perfil, dados profissionais,
  escolaridade, documentos e arquivos;
- nomes ou IDs de responsáveis e de crianças vinculadas;
- resumo de membership de plataforma e resumo de vínculos de responsável;
- importação, exportação, Storage, Edge Function, Realtime ou notificação;
- alteração Flutter, ativação do repository Supabase ou E2E;
- revogação de RPCs, views, grants ou policies legadas;
- migration, deploy, fixture ou validação no projeto remoto nesta etapa.

## Superfícies e entidades

- `public.people`: identidade global e versão de reload por `updated_at`;
- `public.institution_memberships` e
  `public.institution_role_assignments`: vínculos adultos;
- `public.child_contexts`, `public.child_unit_links` e
  `public.child_group_links`: vínculos infantis;
- `public.institutions`, `public.units`, `public.groups` e
  `public.institution_roles`: hierarquia e rótulos validados;
- `public.person_auth_links`: somente classificação coarse do vínculo da
  pessoa retornada, nunca autorização do ator;
- objetos privados da spec 039: principal, auth link, membership, contexto e
  auditoria interna;
- `apps/superadmin`: consumidor produtivo atual do contrato legado e
  consumidor futuro do envelope v2, fora da implementação desta etapa.

As tabelas pessoais auxiliares continuam self-only. Nenhum grant direto novo
em `people` ou nas tabelas contextuais é necessário para esta leitura.

## Permissão, papel e escopo

A capability física é `people.read`. Ela precisa estar ativa, com
`requires_mfa=true`, e possuir grant `allow` ativo, não revogado, somente para
`owner`. A migration recusa matriz diferente; não cria capability, papel ou
grant.

O wrapper chama
`app_private.require_superadmin_internal_context('people.read')`. Além dos
gates da spec 039, aplica allowlist explícita de papel `owner`. Owner exige
AAL2 em toda chamada. `operations`, `auditor`, `support`, `content`, perfil
personalizado e conta Auth sem principal interno permanecem `fail-closed`.

O ator interno possui apenas estes escopos:

- `platform`: pode detalhar qualquer pessoa global não excluída e recebe todos
  os seus contextos ativos e coerentes;
- `institution`: só pode detalhar uma pessoa que possua ao menos um vínculo
  adulto ou infantil ativo e coerente com `scope_institution_id`; recebe
  somente os contextos dessa instituição.

Pessoa de serviço ou pessoa sem contexto institucional é visível somente ao
escopo `platform`. Unidade e grupo não são escopos do principal interno nesta
spec. Seus IDs nunca são recebidos como autoridade: aparecem apenas após a
hierarquia ser derivada e validada pelo servidor.

## Hierarquia e validade contextual

Um vínculo adulto é visível somente quando:

- a membership está `active`, com `revoked_at is null`;
- a atribuição de papel está `active`, já iniciou e ainda não expirou;
- o papel institucional está `active`;
- a instituição existe e não está excluída;
- escopo `institution` não possui unidade nem grupo;
- escopo `unit` aponta para unidade da mesma instituição e não possui grupo;
- escopo `group` aponta para unidade da mesma instituição e para grupo da
  mesma unidade e instituição.

Um contexto infantil é visível somente quando:

- `child_contexts.status='active'` e a instituição não está excluída;
- cada link de unidade retornado está em `pending`, `awaiting_allocation` ou
  `active`, não está revogado e aponta para unidade da mesma instituição;
- cada link de grupo retornado está `active`, já iniciou e ainda não terminou,
  e aponta para grupo da mesma unidade e instituição.

FK simples, status isolado ou ID enviado pelo cliente não prova hierarquia. O
reader v2 repete as igualdades de instituição, unidade e grupo nos joins. Linha
incoerente não torna a pessoa visível e nunca é projetada no payload.

## Interface pública

```sql
public.superadmin_person_detail_v2(
  p_person_id uuid
) returns jsonb
```

A função é `VOLATILE SECURITY DEFINER`, owner `postgres`, com
`SET search_path=''`. `EXECUTE` é revogado de `PUBLIC`, `anon` e
`service_role` e concedido somente a `authenticated`. Readers e helpers
privados não possuem `EXECUTE` para `PUBLIC`, `anon`, `authenticated` ou
`service_role`.

Sessão e contexto são validados antes do alvo. O reader privado aplica o
predicado de escopo e materializa o payload na mesma instrução e no mesmo
snapshot, bloqueando `people` com `FOR SHARE` somente depois de a linha passar
pelo predicado. Assim, uma revogação ou movimentação concorrente do vínculo não
separa autorização e projeção. `NULL`, UUID inexistente, adulterado ou fora do
escopo retorna a mesma negativa `SAI_PERMISSION_DENIED`, sem confirmar se a
pessoa existe. Reload é outra
chamada da mesma RPC; nenhum alvo, seleção ou autorização é persistido no
cliente ou no banco.

## Envelope e output exato

O transporte segue as specs 039 e 040. O PostgREST responde semanticamente
HTTP 200; sucesso usa `{ "ok": true, "data": {...}, "error": null }` e
negativa usa `{ "ok": false, "data": null, "error": {...} }`. As chaves de
erro são somente `code`, `message`, `correlation_id` e `http_status` semântico.
SQLSTATE, detalhe interno, sessão e IDs de autorização não entram na resposta.

Em sucesso, `data` possui exatamente:

```json
{
  "id": "uuid",
  "first_name": "text",
  "last_name": "text",
  "display_name": "text",
  "legal_name": null,
  "type": "adult|child|service",
  "status": "record_status",
  "auth_link": "linked|pending|unlinked",
  "memberships": [],
  "child_contexts": [],
  "updated_at": "timestamptz"
}
```

`legal_name` pode ser texto ou `null`. Os nomes globais são PII necessária ao
formulário aprovado e só aparecem depois da autorização do recurso. Data de
nascimento, contato, endereço, documento, foto e demais dados pessoais não
entram no payload.

`auth_link` é uma classificação de compatibilidade, não um lifecycle nem uma
fonte de autorização:

- `linked`: existe link `active` e não revogado;
- `pending`: não existe link ativo, mas existe algum link não revogado;
- `unlinked`: nenhum link não revogado existe.

Nenhum `auth_user_id`, e-mail, telefone, hash, timestamp ou quantidade de
links é retornado.

### Memberships

Cada item de `memberships` possui exatamente:

```json
{
  "id": "uuid",
  "membership_id": "uuid-or-null",
  "institution_id": "uuid",
  "institution_name": "text",
  "unit_id": null,
  "unit_name": null,
  "group_id": null,
  "group_name": null,
  "role": "text",
  "is_platform": false
}
```

Para adulto, `id` é a atribuição institucional e `membership_id` identifica
sua membership. Para criança, uma linha `role='student'` é derivada de cada
`child_context` visível: `id` é o contexto e `membership_id` é `null`;
unidade/grupo repetem somente o primeiro caminho válido. Essa duplicação é
necessária porque o parser atual usa `memberships` para a semântica contextual
comum. Campos de unidade/grupo são `null` quando o escopo não os utiliza.

Itens são ordenados por nome e ID de instituição, depois nome e ID de unidade,
nome e ID de grupo e, por fim, pelo próprio `id`. O primeiro caminho infantil
usa a mesma ordem determinística. No escopo `institution`, nenhuma linha de
outra instituição pode aparecer, mesmo quando a pessoa também possui vínculo
global em outro tenant.

### Contextos infantis

`child_contexts` fica vazio para adulto e serviço. Cada contexto infantil
possui exatamente:

```json
{
  "id": "uuid",
  "institution_id": "uuid",
  "institution_name": "text",
  "unit_id": null,
  "unit_name": null,
  "group_id": null,
  "group_name": null,
  "child_unit_link_id": null,
  "child_group_link_id": null
}
```

Os campos escalares de unidade/grupo e os IDs dos links representam somente o
primeiro caminho ativo na ordenação determinística por nome e ID, preservando a
compatibilidade do parser Flutter atual. Caminhos adicionais não são projetados
nesta primeira fatia e permanecem fora do contrato até decisão posterior.

No escopo `institution`, somente o contexto da instituição autorizada e seus
links coerentes aparecem. Não são retornados `local_identifier`, pessoa
responsável, permissões familiares, datas, aceite ou autoria.

## Autorização, erros e não enumeração

Claims, `p_person_id`, rota e payload do cliente são não confiáveis. Nenhum
campo do JWT além dos valores revalidados pela spec 039 concede papel ou
escopo. A leitura não usa policies legadas como autorização indireta; o wrapper
privilegiado valida contexto e alvo antes de chamar o reader privado.

Falhas de negócio revertem a subtransação e gravam exatamente um evento
negativo fora dela quando a sessão foi validada. Somente códigos seguros e
allowlisted são preservados; erro inesperado vira `SAI_INTERNAL_ERROR`. Falha
do append de auditoria aborta a RPC. Sessão ausente, inválida, divergente ou
expirada não fabrica audit.

Missing e cross-scope possuem o mesmo código, mensagem, status semântico,
shape e contexto de auditoria minimizado, variando apenas o UUID de correlação.
Essa negativa não guarda `institution_id` nem `object_id` para evitar oracle.

## Auditoria

- capability: `people.read`;
- action: `person.detail` para detalhe e reload;
- sucesso com ator completo usa audit v2 e `outcome='success'`;
- negativa com ator completo usa v2;
- negativa após sessão válida sem ator completo usa v3 `auth_session`;
- sucesso de escopo `institution` usa sua instituição validada;
- sucesso de escopo `platform` usa contexto institucional `null`;
- sucesso usa `object_type='person'` e `object_id=p_person_id` somente depois da
  visibilidade ser validada;
- negativa missing/cross-scope usa instituição e objeto nulos;
- nomes, tipo, status, Auth, vínculos, links, filtros e payload integral não
  entram em `before_json`, `after_json`, `reason` ou outro campo livre;
- `session_id_hash` permanece interno e nunca é projetado na resposta.

## Compatibilidade e dívida legada

As funções `superadmin_people_detail`, `superadmin_people_list`,
`superadmin_people_filter_options`, seus helpers e o repository Flutter atual
continuam inalterados. Elas usam autoridade baseada em pessoa/membership
legada e o detalhe antigo não limita todos os contextos ao escopo interno;
portanto permanecem P0 de cutover e não podem ser usadas como implementação v2.

O escopo autenticado produtivo injeta `SupabasePersonDirectoryRepository`; o
repository indisponível é somente fallback quando a configuração não permite
o Supabase. O adapter produtivo chama a RPC legada e espera payload cru,
enquanto esta RPC usa envelope. O handoff Flutter futuro precisa trocar a
assinatura chamada e mapear `data/error.code`. Revogação do legado exige
regressão Flutter + Supabase,
cross-app/cross-tenant e migration forward-only separada.

## Estados de UX preservados

Esta spec prepara somente os dados para loading, sucesso, indisponível, sem
permissão e não encontrado sem enumeração. Ela não altera tela, rota ou texto.
Pessoa de serviço continua somente leitura; a restrição de escrita não é
implementada por este contrato de leitura.

## Critérios de aceite

- Owner interno `platform` com AAL2 detalha adulto, criança e serviço;
- Owner interno `institution` detalha apenas pessoa com contexto ativo na sua
  instituição e recebe somente os vínculos desse tenant;
- pessoa sem contexto e qualquer pessoa `service`, mesmo com vínculo sintético,
  são invisíveis ao escopo `institution`;
- Owner AAL1, Operations, Auditor, Support, Content e perfil personalizado são
  negados;
- conta Admin/Principal, sessão ausente/divergente/expirada, link ou membership
  suspenso/revogado não recebe dados;
- role, capability ou grant inativo/revogado/`deny` falha fechado;
- ID nulo, inexistente, adulterado ou cross-scope é indistinguível;
- joins não projetam unidade ou grupo incoerente com a instituição;
- revogação ou movimentação concorrente do vínculo não permite que a leitura
  retorne PII raiz com evidência de escopo ausente ou vazia;
- contextos expirados, revogados ou inativos não aparecem;
- somente o primeiro caminho infantil válido e deterministicamente ordenado é
  projetado na bridge flat;
- output e tipos possuem somente as chaves contratadas, sem PII adicional;
- `auth_link` não revela credencial nem autoriza o ator;
- duas leituras sem mudança são estáveis; mudança sintética persistida entre
  chamadas aparece no reload;
- exatamente um audit v2/v3 correlacionado é gravado quando aplicável;
- falha do append aborta a RPC;
- ACL nega `PUBLIC`, `anon` e `service_role`; helpers privados não possuem
  grant de cliente;
- fixtures ficam em transação com rollback e o replay isolado termina sem
  container, volume, rede ou diretório temporário;
- estado máximo sem deploy e E2E é `local-green`.

## Testes exigidos

- RED estrutural antes da migration e GREEN focal depois dela;
- preflight de owner `postgres`, capability/MFA e matriz exata de grant Owner;
- assinatura pública e privada sem overload residual;
- envelopes e key allowlists exatos em sucesso e erro;
- Owner AAL2 `platform` sobre pessoas A/B e Owner `institution` somente A;
- adulto, criança e serviço, com campos nulos e múltiplos vínculos;
- hierarquia adulta e infantil válida e linhas sintéticas incoerentes;
- unit/group de outro tenant, ID inexistente e `NULL` sem oracle;
- Owner AAL1 e todos os papéis fora da allowlist;
- sessão ausente, divergente e expirada; Auth sem link interno;
- link e membership `active`, `suspended` e `revoked`;
- role, permission e grant inativo, grant revogado e efeito `deny`;
- shape e tipos de raiz, memberships e child contexts flat, incluindo ausência
  de `assignment_id`, `child_context_id`, `role_name`, `unit_links` e `group_links`;
- ausência de data de nascimento, contato, endereço, documento, Auth ID,
  plataforma, guardian, sessão e hash em payload e audit;
- classificação coarse `linked`, `pending` e `unlinked`;
- audit v2/v3 1:1, digest válido e append adversarial `fail-closed`;
- persistência e read-after-write/reload dentro da fixture transacional;
- ACL, owner, `SECURITY DEFINER`, volatilidade e `search_path=''`;
- regressões Auth e dos reads v2 já consolidados, mirror e `git diff --check`;
- teardown e secret scan sem PII ou credencial.

## Riscos, bloqueios e perguntas para integração

- `PersonChildContext` no Flutter atual consome um caminho flat. Esta bridge
  escolhe somente o primeiro caminho válido por ordenação determinística;
  representar e editar múltiplos caminhos precisa de decisão e contrato
  posteriores.
- O rótulo físico `pending` em `auth_link` é somente compatibilidade agregada e
  não deve ser reutilizado para transição, convite ou decisão de acesso.
- A proveniência e as definições do ambiente remoto precisam ser reconciliadas
  antes de deploy; esta aprovação documental não autoriza mutação remota.
- Listagem/filtros, escrita e cutover possuem contratos e gates próprios. O
  sucesso desta fatia não promove `people.list`, `people.create`,
  `people.edit`, `people.links`, Flutter ou E2E.
