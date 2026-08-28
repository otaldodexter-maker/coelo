---
title: "Detalhe e reload v2 de Turma para o Superadmin interno"
source: "specs/039-superadmin-internal-auth-session-context.md; docs/superpowers/specs/2026-07-29-superadmin-group-directory-design.md; docs/open-questions.md#oq-031; packages/coelo_database/migrations/20260811151254_group_management_security.sql; inventario remoto read-only de 2026-08-28"
status: "approved-for-implementation"
approval: "Coordenacao Coelo em 2026-08-28; autorizacao tecnica restrita ao detail/reload read-only desta spec"
generated_at: "2026-08-28"
---

# Detalhe e reload v2 de Turma para o Superadmin interno

## Objetivo e problema

Criar um contrato aditivo e somente leitura para detalhar e recarregar uma
Turma pelo principal interno exclusivo da spec 039. O contrato substitui apenas
a autoridade do gateway de leitura: nao reutiliza `people`,
`person_auth_links`, `platform_memberships`, `current_person_id()` ou os
helpers legados como fonte de autorizacao.

O inventario remoto somente leitura confirmou que a capability fisica
`groups.read` existe, esta ativa, nao exige MFA por si mesma e possui grants
`allow` ativos apenas para `owner` e `operations`. Esta spec preserva essa
matriz factual para a fatia de detalhe; nao amplia papeis nem resolve a
taxonomia geral de OQ-031.

## Escopo

- uma RPC publica de detalhe por `group_id`; reload e uma nova chamada a mesma
  RPC e nunca estado de selecao ou cache persistido;
- revalidacao de Auth, `session_id`, `auth.sessions.not_after`, auth link,
  membership, role, `groups.read`, MFA e escopo em cada chamada;
- leitura da raiz fisica da Turma e dos nomes minimizados de sua Instituicao e
  Unidade;
- envelope estavel, auditoria interna v2/v3, ACL minima, nao enumeracao e
  isolamento entre Instituicoes;
- coexistencia aditiva com RPCs, policies e grants legados ate cutover
  integrado posterior.

## Fora de escopo

- listagem, busca, filtros, opcoes de filtro ou paginacao de Turmas;
- criar, editar, alterar status, arquivar, excluir ou mover Turma entre
  Instituicao/Unidade;
- definir transicoes entre `draft`, `active`, `inactive`, `suspended` e
  `archived`;
- membros, Pessoas da turma, profissionais, administradores, perfis efetivos,
  convites ou delivery de convite;
- atividades vinculadas, branding/aparencia efetiva, solicitacao de tipo ou
  qualquer contador/agregado;
- arquivos, importacao, exportacao, jobs, Storage ou Edge Functions;
- Flutter, repository, cutover, deploy ou validacao remota;
- restaurar as migrations historicas ausentes do HEAD, criar
  `groups.export`, alterar `group_type` textual ou fechar OQ-031;
- revogar, substituir ou reinterpretar tabelas, policies, helpers, RPCs ou
  grants legados.

## Autoridade aprovada e limite da decisao

Esta leitura v2 usa a capability fisica `groups.read`, combinada com a allowlist
explicita de papeis `owner` e `operations` e com o escopo derivado da membership
interna da spec 039.

- `owner` exige AAL2 em toda chamada;
- `operations` segue `platform_permissions.requires_mfa` de `groups.read`,
  atualmente `false`;
- `auditor`, `support` e `content` permanecem fail-closed nesta RPC;
- membership interna `platform` autorizada pode detalhar Turma de qualquer
  Instituicao existente dentro do alcance aprovado;
- membership interna `institution` autorizada so pode detalhar Turma cuja
  `institution_id` seja exatamente sua `scope_institution_id`;
- `group_id`, claims, filtros e qualquer contexto enviado pelo cliente sao
  dados nao confiaveis e nunca concedem escopo;
- a ligacao entre Turma, Unidade e Instituicao deriva apenas das FKs e da linha
  alvo no servidor.

Os grants atuais de `groups.read` para Owner/Operations sao a unica base da
matriz desta fatia. Templates locais que mencionam Auditor, Support ou perfis
autorizados nao ampliam a RPC e permanecem sujeitos a reconciliacao futura em
OQ-031.

## Interface publica

```sql
public.superadmin_group_detail_v2(
  p_group_id uuid
) returns jsonb
```

O wrapper e `VOLATILE SECURITY DEFINER`, owner `postgres`,
`search_path = ''` e tem `EXECUTE` somente para `authenticated`. `PUBLIC`,
`anon` e `service_role` permanecem sem `EXECUTE`. Helpers novos ficam em
`app_private`, sem grants de cliente, com owner e configuracao equivalentes.

O wrapper chama `app_private.require_superadmin_internal_context(
'groups.read')`, aplica a allowlist adicional desta spec e valida o escopo antes
de materializar qualquer dado do alvo. `app_private.has_platform_permission`,
`app_private.has_scoped_platform_permission`,
`app_private.has_institution_permission` e as policies legadas nao sao fonte de
autorizacao da v2.

## Envelope e erros

O retorno segue o envelope interno da spec 039. O transporte PostgREST retorna
HTTP 200; `ok=false` carrega `error.code`, mensagem minimizada,
`correlation_id` e `error.http_status` semantico.

Turma inexistente e Turma fora do escopo retornam exatamente o mesmo erro
`SAI_PERMISSION_DENIED`, com `error.http_status=403`, sem confirmar
Instituicao, Unidade, nome, tipo ou status. O comportamento deve ser
indistinguivel tambem na auditoria exposta ao chamador e em tempo
razoavelmente equivalente; nao existe lookup publico previo que forme oracle.

## Output fisico minimo

Em sucesso, `data` possui exatamente esta forma logica, sem chaves adicionais:

```json
{
  "id": "uuid",
  "institution": {
    "id": "uuid",
    "name": "text"
  },
  "unit": {
    "id": "uuid",
    "name": "text"
  },
  "name": "text",
  "group_type": "text",
  "group_type_other_text": "text|null",
  "status": "record_status",
  "inherit_appearance": true,
  "inherit_access": true,
  "inherit_activities": true,
  "management_version": 1,
  "created_at": "timestamptz",
  "updated_at": "timestamptz"
}
```

- `institution.name` deriva de `institutions.public_name`;
- `unit.name` deriva da Unidade vinculada, cuja `institution_id` deve coincidir
  com a da Turma pela integridade fisica;
- `group_type` continua texto livre; o valor `class` nao e transformado no
  backend, pois `Turma` e apenas o rotulo de apresentacao do Flutter;
- `group_type_other_text` preserva a nullability fisica e a constraint vigente;
- `status` reflete o enum fisico atual sem criar regra de transicao ou ocultar
  registros por lifecycle;
- os tres flags de heranca e `management_version` sao valores fisicos, nao
  materializam branding, acesso efetivo ou atividades;
- nenhuma pessoa, perfil, convite, atividade, cor, permissao efetiva, documento,
  dado Auth, session hash, contador ou payload de auditoria entra na resposta.

## Auditoria e atomicidade

- action code: `group.detail` para detalhe e reload;
- capability registrada: `groups.read`;
- sucesso com ator interno completo usa audit v2 e outcome `success`;
- negativa com ator completo usa v2; apos sessao valida, mas antes de principal
  interno completo, usa v3 conforme a spec 039;
- sessao ausente, invalida, divergente ou expirada nao fabrica audit;
- ID solicitado, nomes, tipo, status e timestamps nao entram no metadata de
  negacao; metadata de sucesso permanece minimizado;
- cada chamada aceita gera exatamente um evento correlacionado;
- falha do append de auditoria aborta a RPC; nao existe sucesso ou negativa
  identificada sem audit obrigatorio.

## Compatibilidade e proveniencia

O pacote e aditivo. Nao altera o RPC legado `superadmin_group_get`, a listagem,
o comando de save, RLS ou Data API. O remoto registra as versions
`20260811151254`, `20260811180804`, `20260811190000`, `20260811193000`,
`20260811194500`, `20260811200000` e `20260811201500`; somente a primeira foi
reconciliada no HEAD atual. A ausencia dos seis hardenings seguintes na fonte
canonica e um bloqueio de proveniencia, nao autorizacao para restaura-los por
nome ou reconstruir seu SQL.

Os gateways remotos existentes derivam `current_person_id()` e o realm legado.
Sua existencia nao os torna compativeis com o principal interno. Qualquer
cutover ou revogacao posterior exige reconciliacao individual das migrations,
regressao Flutter + Supabase, testes cross-app/cross-tenant e migration
forward-only separada.

## Criterios de aceite

- Owner AAL2 e Operations autorizados recebem o payload exato; Owner AAL1,
  Auditor, Support e Content recebem negacao estavel;
- membership `platform` autorizada le Turmas A/B; membership `institution` le
  somente Turmas de sua propria Instituicao;
- ID de outra Instituicao, outra Unidade, inexistente ou adulterado nao forma
  oracle e retorna o mesmo 403 sem dados;
- sessao ausente/divergente/expirada, auth link revogado e membership
  suspensa/revogada falham antes do payload;
- role, permission ou grant inativo/revogado/deny falha fechado;
- hierarquia e nomes derivam das linhas do servidor, sem confiar em
  `institution_id` ou `unit_id` do cliente;
- reload apos alteracao transacional de fixture observa o novo valor
  persistido;
- output omite membros, convites, atividades, branding, acesso efetivo,
  contadores e dados Auth;
- audit v2/v3 e 1:1, correlacionado, minimizado e digest-valid; append
  adversarial falha fechado;
- ACL nega `PUBLIC`, `anon` e `service_role`; helper privado nao tem grant de
  cliente; owner, volatility e `search_path` sao verificados;
- nenhuma migration historica ausente, capability, policy ou grant legado e
  restaurado, reescrito ou promovido;
- sem deploy e E2E, o maximo declaravel e `local-green`.

## Testes exigidos

- estrutura, assinatura, owner, volatility, `SECURITY DEFINER`, `search_path`,
  ACL do wrapper e ausencia de grants nos helpers;
- sucesso Owner AAL2 e Operations; negativas Owner AAL1, Auditor, Support e
  Content;
- sessao ausente, divergente e expirada; auth link e membership nos estados
  `active`, `suspended` e `revoked`; permission/grant/role inativo, revogado ou
  `deny`;
- platform scope em duas Instituicoes e institution scope limitado a sua FK;
- cross-app, cross-tenant, cross-institution, ID inexistente e adulterado com
  resposta identica e sem vazamento;
- shape, tipos e chaves exatas; `group_type_other_text` nulo e preenchido;
  todos os cinco valores fisicos de `record_status` legiveis sem inferir
  transicoes;
- integridade Turma -> Unidade -> Instituicao derivada no servidor;
- persistencia e reload apos update transacional de fixture;
- audit positivo/negativo v2/v3, correlacao 1:1, minimizacao, digest e append
  fail-closed;
- regressao Auth 039 e contratos internos de Instituicao/Unidade existentes;
  fixtures transacionais e teardown sem residuos.

## Riscos e perguntas abertas

- OQ-031 permanece aberta para taxonomia de `group_type`, transicoes de status,
  lifecycle, escrita, eventos, membros e importacao/exportacao;
- a matriz geral de `groups.read` entre perfis internos e institucionais ainda
  precisa reconciliar grants remotos, templates locais e cutover por aplicativo;
- a leitura direta por RLS e os RPCs legados continuam no realm people-based;
  esta spec nao os declara seguros para o principal interno nem autoriza sua
  remocao;
- os seis hardenings remotos ausentes do HEAD exigem equivalencia individual
  antes de qualquer recuperacao; o pacote local-only
  `20260813090000_group_management_wave1_closure.sql` e o bridge de exportacao
  `20260813183644_group_export_worker_bridge.sql` nao pertencem ao ledger
  remoto e nao podem ser usados como substitutos;
- list/filter, create/edit, status, membros e arquivos exigem specs e
  autorizacoes independentes.
