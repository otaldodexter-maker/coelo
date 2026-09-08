---
title: "AG-READ01 — crosswalk e proposta de fixture interna de leitura"
source: "ADR0029; specs006/050/039; migrations20260901183836/20260901193717; política20260901200206; reserva Coordenador 2026-09-07"
status: "proposta local; sem corretiva SQL nem execução"
generated_at: "2026-09-07"
---

# Recorte autorizado

Superadmin: `agenda.view`, parcela de leitura de `agenda.detail` e contexto de
`agenda.permissions`. Somente list/get/contexts; não requests, responses,
save/commands, notificações, mídia, reservas de Locais ou apps Admin/Principal.
O contrato de produto aprovado exige ator interno e isolamento; este documento
não atribui papéis nem amplia permissões. Root writer; Eng1 único operador SQL.

Ordem: inventário/crosswalk → fixture RED nominal → base fechada Eng1 → RED real
→ corretiva revisada → GREEN → adapter/rota e runtime autorizado. Parada de cada
fatia não promove tela a E2E. Preparação: 20–40 min; replay/runtime sem ETA antes
de fechar dependências e autorização. Evidências: hashes, TAP, estados Dart,
negativas cross-ID, correlação/auditoria e reload real posterior.

## Fontes lidas e divergências efetivas

| Camada | Estado verificado | Consequência para AG-READ01 |
| --- | --- | --- |
| ADR0029 / spec050 | Backend autorizado; toda leitura/escrita revalida ator interno e tenant | Não existe bloqueio Owner equivalente à OQ040 para autoria de reader |
| `20260901183836` | Tabelas Agenda, catálogo agenda.*, list/get e comandos; RLS forçada sem grants cliente | Fonte física existente; não restaurar migrations removidas |
| `assert_agenda_permission` | Retorna `current_person_id`, exige `has_platform_permission` | Não serve para039; não alterar helper, pois comandos escrevem esse UUID em colunas person |
| List legado | Escopo só pelo filtro opcional do cliente; busca ILIKE; projeção to_jsonb menos dois campos | Novo reader deve intersectar contexto real e allowlist, não trocar apenas ator |
| Get legado | Busca por ID, agrega history e responses sem predicado institucional nesses vínculos | Cross-ID/tenant precisa retornar not-found sem existência; responses fora desta fatia |
| `20260901193717` | Contexts consulta platform_memberships/People e anuncia sete mutações | Reader interno separado; nenhum acesso a comandos People habilitado por este pacote |
| Auth039 vigente | Scope enum contém apenas platform/institution; sessão/link/membership e role permission efetivos | Unidade é hierarquia do recurso, não novo scope interno. Não inventar membership unit |
| Política MVP20260901200206 | require_superadmin_internal_context não impõe AAL2 nesta fase; mantém sessão e capability | AG-READ01 preserva essa política, sem copiar AAL2 adicional de Activities |

Os dois arquivos de Agenda **não são um manifest de replay fechado**. Eng1 deve
validar Auth/context/audit, instituições/unidades/grupos/activities e dependências
físicas antes de selecionar base/alvo. Não assumir número de migrations nem
declarar disponível uma tabela somente por existir na worktree.

### Matriz de capacidades: fato e gate

`agenda.read` existe no catálogo com requires_mfa=false. Busca em todas as
migrations encontrou referências agenda.* apenas nos dois arquivos de Agenda;
não foi localizado seed nominal de platform_role_permissions para agenda.read.
O helper039 exige grant allow ativo e não revogado: nem Owner ignora esse teste.
Código em disco não prova atribuições efetivas do banco. É necessário inventário
nominal read-only dos grants na base escolhida, sem nomes/PII de usuários.

Não inserir grants de produto para owner/operations/content por analogia com
Activities. Fixtures positivas deverão usar apenas atribuição existente comprovada
ou papel estritamente sintético com concessão isolada em rollback **aprovada para
teste**; a ausência da matriz produtiva continua gate de liberação real.

## Contrato proposto dos readers independentes

Nomes propostos, ainda não criados:

| RPC | Entrada | data de sucesso | Audit action |
| --- | --- | --- | --- |
| `superadmin_agenda_list_v2` | p_from/p_to timestamptz, p_institution_id uuid nullable, p_search text, p_limit int, p_offset int | items, total_items, limit, offset, correlation_id | agenda.list |
| `superadmin_agenda_get_v2` | p_event_id uuid | item, correlation_id | agenda.get |
| `superadmin_agenda_contexts_v2` | nenhuma | contexts, mutation_actions_available=false, correlation_id | agenda.contexts |

Envelope: `{ok:true,data:...,error:null}`. Negativas: data=null, código/mensagem/
http_status/correlation_id minimizados; erros039 preservados. Erro de input e
not-found usam códigos nominais de Agenda, sem modificar allowlist de helper
compartilhado. Append obrigatório fora do catch de leitura; falha de append
propaga erro sem sucesso/data. Audit after_json somente row_count; sem busca,
títulos, perguntas, reason, IDs de pessoas ou sessão bruta.

List: período válido até400dias, limit1–200, offset>=0, todos não-null quando
obrigatórios; search proposto até120caracteres, literal (%, _ e barra não são
padrões). Ordem starts_at/id antes de paginação; total independente da página.
Período inicial mantém semântica de armazenamento existente; expansão completa
de recorrências anteriores à janela continua gate distinto, não fica concluída
por esse reader. Filtro institucional só restringe o scope autorizado.

Get: recurso B e UUID válido inexistente têm mesma resposta404 para membro A.
NULL recebe negativa validada dentro da RPC. UUID textual malformado pode falhar
no cast/PostgREST antes de entrar no wrapper; nesse caso não se exige envelope
ou auditoria de uma RPC que não executou. Nenhuma negativa revela existência;
nenhuma leitura de história/resposta antes de validar
ator, capability, recurso e instituição. Histórico somente da mesma instituição.

Contextos: instituições ativas/não apagadas; unidades/grupos ativos com vínculos
institucionais reais; activities ativas e origin_unit válida quando presente.
IDs/client claims não ampliam o alcance. Unidade/grupo de B nunca aparecem sob A;
unidade A2 irmã não é tratada como filha de A1. Escopo039 institucional permite
as unidades dessa instituição, não introduz restrição artificial a uma unidade.

### Projeção mínima e compatibilidade

Item allowlist candidata: id/institution_id/context_kind/context_id/title/
item_type/priority/status/origin/starts_at/ends_at/all_day/time_zone_id/location/
description/response_mode/guardian_response_policy/recurrence/audience/reminders/
questions/revision. Sem created_by_person_id/updated_by_person_id, rows inteiras,
dados de nascimento, anexos ou responses. Get acrescenta histórico allowlisted
(ação/instante/revisões/justificativa minimizada), nunca ator Pessoa/receipt inteiro.
Audience, recurrence e questions precisam allowlists internas e validação de
vínculo institucional; `to_jsonb` do agregado não basta. Auditoria não replica
esses valores. A matriz de fixture deverá incluir campo sentinela não permitido.

O adapter atual espera payloads crus e `_item` consome esses campos. A migração
Flutter deve ser explícita: reader dedicado desembrulha envelopes; sem fallback
para os três readers legados. Comandos/request readers não fazem parte desse
adapter de leitura. UI não deve anunciar sete mutações disponíveis só porque
recebeu contextos. Disponibilidade de integração e capability efetiva são dados
distintos: não falsificar grants/deny da plataforma para ocultar integração ausente.

Shape proposto de cada contexto preserva id/name/institution_id/parent_id/level
e as listas `granted_capabilities`/`restricted_capabilities` consumidas hoje.
As sete capabilities devem refletir o grant efetivo039 para o mesmo ator/escopo
autorizado, não valores constantes e não membership People. O campo separado
`mutation_actions_available=false` indica integração de escrita indisponível,
mesmo quando existe capability efetiva. O adapter nominal futuro mantém comandos
indisponíveis; não infere autorização de escrita apenas por receber a lista.

Inventário deve conferir também a assinatura de auditoria: a variante que recebe
after_json está em20260831211945 (Activities), não se presume presente só por
Auth039 existir. A seleção nominal deve provar sua disponibilidade sem importar
automaticamente toda a cadeia Activities nem editar helper compartilhado.

## Proposta de fixture RED — casos obrigatórios

Tudo sintético e rollback; RPCs sob SET LOCAL ROLE authenticated, resultados
capturados em TEMP. RESET ROLE antes de TAP e inspeção audit. Sem grant de TAP,
helper substituído, People bridge, chamadas remotas ou retry de migração.

| Grupo | Provas planejadas |
| --- | --- |
| Pré-condições | Três RPCs nominais/signaturas; catálogo agenda.read; base exata e helper039; nenhum grant novo por produto |
| Identidade | Interno sem person_auth_link positivo; People-only negativo; sem Auth, sessão errada/expirada, membership revogada/suspensa e capability negada |
| Isolamento | Membro A lista só A; filtroB não amplia; getB e inexistente iguais; platform permite A/B somente com grant efetivo |
| Hierarquia | A1/A2 reais; grupo A2 não vincula A1; IDs de B e vínculos inconsistentes não projetados como A; contexts sem inativos/arquivados |
| DTO | Allowlist top-level/nested; sem autoresPessoa/responses; dados minimizados e sem campo sentinela; envelope/correlação válidos |
| List | Ordem e empate ID, paginação antes de aggregate, página além do total, limite/período/offset/null inválidos, busca literal e bound120 |
| Privilégios | authenticated somente wrappers; anon/direct-table negados; helpers privados sem grant; reader não modifica event/receipt e não chama commands |
| Auditoria | Sucesso correlacionado ator/link/membership/instituição/session hash; counts exatos página/contextos/detail; after_json exclusivamente count |
| Falha audit | Trigger temporário nominal falha somente success desses3actions; cadaRPC deve lançar P0001/AG_READ01_AUDIT_FAILURE sem data, não erroACL substituto |
| Continuidade cliente | HTTP200denial, malformed-envelope, errotransport, contextoA→B, cachelimpo/reload, nenhuma chamada a readers/commandsPeople |

Esta é **proposta de fixture, não pgTAP executado**. Antes da tradução para SQL
fechado, revisar nomes/projeção, confirmar inventário e método dos grants sintéticos.
Não contabilizar nenhuma linha desta matriz como teste passado.

## Próximo gate

Coordenador/Eng1: inventário da base/grants e aceite do contrato proposto; depois
fixture fechada e RED. Nenhuma corretiva ou composição compartilhada foi alterada.
Gate de memória no-op: desenho ainda proposto, sem conhecimento aprovado novo.
