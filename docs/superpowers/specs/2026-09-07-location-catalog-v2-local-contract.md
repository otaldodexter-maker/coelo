---
title: "LOC-CATALOG01 — ficha candidata mínima local"
source: "docs/superpowers/specs/2026-09-07-location-catalog-sql-proposal.md"
status: "candidate-local-only-review-required"
generated_at: "2026-09-07"
---

# Reserva e limite

Reserva da coordenação: tabela única `public.activity_locations`, três RPCs
nominais directory/detail/create v2 e migration candidata
`20260908031000_superadmin_location_catalog_v2.sql`. SQL local somente após
review desta ficha; sem execução autônoma, Docker, lease remota, backfill,
delete, matriz de produção aprovada ou grant de capability em produção.
Engenheiro 1 seleciona replay; E2E 5 revisa o fechamento legado.

## Dados e validação candidata

- Preservar tabela, UUIDs, FK instituição e FK composta unidade/instituição.
  `scope_kind` obrigatório `institution` ou `unit`: instituição exige unit_id
  nulo; unidade exige unit_id não nulo. Não é escopo de audiência.
- `kind` obrigatório `internal`/`external`; `visibility` obrigatório
  `team`/`guardians`/`students`/`all`, sem defaults de classificação.
- Nome trim não vazio, até 120 caracteres; descrição opcional trim, vazio
  normaliza null, até 500 caracteres. Controles ASCII são recusados.
- Andar opcional livre (`floor`), trim, vazio null; limite candidato explícito
  **120 caracteres**, controles ASCII recusados. Sem enum ordinal inferido.
- `address` JSON próprio, sem cópia/herança automática. Interno aceita null;
  externo exige objeto válido. Vocabulário idêntico ao normalizador vigente
  de edição interna de Instituição: country/state/city/district/street/number/
  complement/postal_code. Country obrigatório `Brasil` ao criar endereço.
  Demais campos opcionais/null; CEP presente exige oito dígitos, sem máscara.
  Limites em bytes: country80; state/city/district/street/complement240;
  number/postal_code64. Trim/null e recusa de controles como a fonte vigente.
  Não inventar rua/UF obrigatória nesta fatia; country-only segue o mínimo
  canônico de criação de endereço, e não garante geocodificação.
- Manter status default ativo e management_version positivo existentes;
  cliente não informa status, versão, ID, timestamps ou autoria na criação.
- Preservar índice único existente `(unit_id,lower(name)) WHERE
  status<>'archived'`; adicionar índice institucional
  `(institution_id,lower(name)) WHERE unit_id IS NULL AND status<>'archived'`.
  Assim nomes iguais em proprietários diferentes são permitidos; case variante
  no mesmo proprietário não é. Não usar NULL como atalho para colisão global.
- Acrescentar `created_by_internal_identity_id` com FK real para
  `app_private.superadmin_internal_identities(id) ON DELETE RESTRICT` e índice.
  Retirar NOT NULL da autoria people e impor XOR de autores; v2 sempre escreve
  somente identidade interna obtida no servidor. Legado fechado não ganha
  entrada alternativa; não criar People fake. Não migra autoria existente.

## Gestão, audiência e autorização

Capabilities **candidatas** `locations.read` e `locations.create`, ativas e
Owner-only nas fixtures locais. O pacote NÃO provisiona matriz remotamente:
preflight exige que a matriz nominal tenha sido provisionada separadamente
e seja exatamente Owner-only. Fixture faz isso transacionalmente para replay.
Nenhum fallback para activities.read/platform.read/current_person_id.

Gestão interna: requer contexto interno revalidado a cada chamada, papel Owner,
capability específica e escopo platform/institution real; escopo instituição
só alcança o próprio institution_id. Unidade sempre é conferida na instituição
proprietária. Instituição deve existir e não estar excluída; unidade não pode
estar arquivada. IDs ausentes/alheios usam a mesma negação não enumerante.
MFA segue o helper interno vigente (ADR0019set1); não reintroduzir gate AAL2.

Visibilidade é audiência **respondente** de consumo futuro, não condição para
Owner consultar/gerir no próprio escopo. `all` nunca é público anônimo.
Esta fatia não concede leituras a equipe/responsáveis/alunos, não implanta
políticas de respondente nem permite que cliente se declare numa audiência.

## RPCs, receipt e projeção

- Directory: proprietário explícito (institution_id + unit_id nullable coerente
  com scope_kind), search opcional até120 caracteres, limit1..100 default24,
  offset0..10000, ordem estável lower(name) COLLATE C + id. Sem SQL dinâmico.
  Retorna items mínimos e total_count apenas desse proprietário autorizado.
- Detail: UUID de local, proprietário derivado do registro e revalidado;
  status diferente de archived não é prova de autorização.
- Create: payload allowlist exata scope_kind/institution_id/unit_id/name/
  description/kind/floor/address/visibility e request_id UUID obrigatório.
  Receipt privado nominal por internal_identity_id/request_id, hash do payload
  normalizado e ID criado. Reautorizar antes do replay; mesmo request com payload
  diferente gera conflito, sem devolver receipt ou dados de outro ator.
  Concorrência serializada por ator/request; conflito de nome tratado sem dump.
- Projeção allowlist: id, scope_kind, institution_id, unit_id, name,
  description, kind, floor, address, visibility, status, management_version,
  created_at e updated_at. Não expõe autor ou receipt. Sem mídia/bindings.
- Auditoria interna existente: ator, capability, ação, resultado, correlação,
  instituição/recurso; sem nome/endereço/payload no log. Auditoria falha implica
  rollback da operação. Erros em envelope interno seguro, sem SQL/raw text.

## Fechamento legado no mesmo pacote

Preflight verifica postgres, dependências internas, dez colunas e constraints/
índices/ACL/RLS esperados e fingerprints dos helpers legados. Lock exclusivo
na tabela antes de revalidar vazio. Qualquer drift/linha prévia aborta; nenhuma
correção automática. Nenhum dado real é lido pelo teste de vazio.

| Caminho | Delta mínimo candidato |
| --- | --- |
| authenticated SELECT tabela | Revogar; remover policy people-based do catálogo. |
| writer público e privado `superadmin_create_activity_locations` | Revogar EXECUTE e substituir helper por recusa explícita; não deixar receipt legado retornar linhas novas. |
| `activity_management_payload` | `locations` e `location_names` tornam-se arrays vazios explícitos; remover consultas de catálogo, não só colunas. |
| `superadmin_activity_directory` privado | Remover join/aggregate `location_names`, conservar shape com array vazio. |
| options privado | Campo locations vazio explícito, sem consulta na tabela. |
| wrappers públicos de leitura | Preservar assinatura/ACL e demais payloads; nenhum bridge implícito. |
| helper v2/receipt | Sem privilégios de cliente, RLS deny-by-default. |

## REDs para seleção de replay

Ordem nominal: dependências existentes, bootstrap local
`packages/coelo_database/tests/fixtures/location_catalog_v2_capability_bootstrap.sql`,
candidato `20260908031000_superadmin_location_catalog_v2.sql` e somente então
as duas suítes `superadmin_location_catalog_v2_test.sql` e
`superadmin_location_catalog_v2_authorization_test.sql`. O bootstrap exige
conexão postgres e opt-in `SET coelo.local_replay='location-catalog-v2'` na
mesma conexão; não é migration de produção nem seed após reset. Engineer1
seleciona e serializa o replay. Nenhuma execução Docker ou remota é delegada
por esta ficha. A matriz de capabilities de produção permanece não aprovada.

A revisão independente identificou reautorização insuficiente do recurso
referenciado pelo receipt e classificação incorreta do payload divergente.
O candidato agora deriva o proprietário atual antes da projeção, filtra escopo
antes de adquirir lock e retorna `SAI_CONCURRENT_CHANGE` para divergência.
As suítes preparadas cobrem mudança de proprietário, revogação e rollback de
auditoria; sua execução ainda é necessária. Dezessete gates estáticos passaram,
sem comprovar sintaxe executável, preflight real ou concorrência entre sessões.

Preflight drift/vazio/matriz; proprietário A/B e unidade cruzada; ator externo,
revogado/semcapability; explícitos kind/visibility; limite120/500/floor120 e
endereço; XOR/FK; case uniqueness por proprietário; deny direto; todos os
caminhos legados sem descoberta; idempotência/reautorização/concorrência;
audit rollback; reload/persistência transacional e cleanup. Testes e candidato
não equivalem a replay executado, implantação ou fechamento dos sete IDs.
