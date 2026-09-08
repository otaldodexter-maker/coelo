---
title: "Modelos de Acesso — autorização antes de lookup"
source: "Reserva local do Coordenador; spec 039 e aditivo MFA MVP; migrations 171731/193000; revisão realm_audit"
status: "local-green-38-tap; production-and-e2e-pending"
generated_at: "2026-09-07"
updated_at: "2026-09-08"
---

## Recorte

Registro cronológico: os checkpoints abaixo preservam seu estado de coleta.
Resultado vigente: Engenheiro 1 registrou **38/38 pgTAP PASS, exit 0**, no
commit `5ef2fc4e`, evidência
`docs/reviews/evidence/etapa-2/engenheiro-1/models-read-green-2026-09-08.md`, lida
integralmente pela E2E 1 na worktree do executor. A base RED49 emitiu 24 PASS /
4 FAIL nas fixtures 11+17 (os dois gaps repetidos); GREEN50 acrescentou somente
a corretiva `20260908021821`, repetiu 11+17 intactos e adicionou ACL10.

Os dez asserts extras confirmaram helper, owner postgres, SECURITY DEFINER,
STABLE, search_path vazio e EXECUTE efetivo negado a PUBLIC/anon/authenticated/
service_role. As seis contraprovas domain-only passaram antes e depois.
38 é contagem TAP, não 38 cenários distintos: a fixture 17 repete a 11.

GREEN iniciou `2026-09-08T03:13:46.9549294Z`, identidade
`coelo_safe_dfcbcbafabb74cb38dd3d1a5f196d`; cleanup independente
`2026-09-08T03:15:13.8697189Z`: zero recursos próprios e staging ausente,
recursos históricos preservados. Nenhuma execução SQL/Docker nesta frente,
remoto ou promoção E2E. Não comprova matriz completa de tenants/roles ou UI.

### Contrato preservado

Somente leituras list/detail/catalog de Modelos no Superadmin e o helper de
detalhe. Preservar autorização `${domain}.role_models.read`, Owner/escopo
platform, envelopes/argumentos PostgREST e auditoria interna. Não alterar
mutações/import/export, `require_profile_authority`, histórico de migrations,
Perfis legados ou aplicativos Admin/Principal/Site. Remoto sem lease: read-only.

## Reprodução preparada

`packages/coelo_database/supabase/tests/access_profile_models_read_authorization_test.sql`
tem 11 asserts e fixture transacional descartável. Owner interno AAL1 sem
pessoa, conta global com pessoa e sessão válida, três modelos por domínio.
As chamadas usam `authenticated`; TAP e inspeção de audit após `RESET ROLE`.

Os asserts 5/7 comparam detalhe de ID existente e inexistente sob sessão
inválida/realm global: o código atual consulta antes de autorizar e retorna
`SAI_PERMISSION_DENIED` para ID desconhecido, em vez do erro de sessão/realm.
RED esperado por inspeção, ainda não executado. Positivos list/detail/catalog,
negação por capability institucional, contraprova de plataforma e audit
identificável impedem confundir erro de ambiente com a correção.

SHA-256 UTF-8/LF do teste:
`fa1b23feb4089ae597b6cc4592ff66d51bb6d6f7ae11d3a7b6ad32e8e8d2b81b`.
Review independente `realm_audit`: sem bloqueante estático, plano 11 coerente.

## Dependências e próximo gate

Core de templates `20260811215451`, fundação interna/audit reconciliada,
default EXECUTE privado, Models `20260901170731`, wrappers `20260901193000`
e exceção AAL1 `20260901200206`. A ordem/bridges nominais pertencem ao Engenheiro
1 e ao Coordenador; não aplicar cauda histórica nem improvisar bridge.

Engenheiro 1 é o único operador de replay. Primeiro obter RED comportamental;
depois preparar migration forward-only nominal e repetir positivos/negativos.
Estimativa da fatia de código/teste: 45–90 minutos após baseline executável;
produção/E2E dependem do pacote coordenado, sem ETA confirmada neste registro.
Nenhuma SQL executada ou migration corretiva escrita nesta evidência.

Knowledge: sem decisão nova de produto; o gate conserva fontes existentes.

## Corretiva nominal — 2026-09-08

O Coordenador confirmou replay real do plano 11: 9 PASS, 2 FAIL (5/7), sem
erro de ACL ou abort, cleanup sem resíduo. O par conhecido/desconhecido retornou
SESSION_INVALID/PERMISSION_DENIED para sessão inválida e
INTERNAL_CONTEXT_DENIED/PERMISSION_DENIED para realm global. A execução foi
do Engenheiro 1; esta frente não executou SQL ou Docker.

A migration nova `20260908021821_access_profile_models_read_prelookup_authorization.sql`
foi criada pelo CLI 2.116.0 e movida para `migrations/` sem mudar timestamp.
SHA-256 UTF-8/LF: `6258f28e19237d2141746291d33afc3e6e54a6b81d4060cd0ec5f876a6c0ea34`.

Acrescenta um pré-validador privado exclusivo de Models, sem argumentos do
cliente, que tenta as três capabilities de leitura pelo helper vigente.
Somente `42501` com detalhe `SAI_PERMISSION_DENIED` permite tentar o próximo
domínio; sessão, realm e demais falhas propagam imediatamente. Sem leitura
permitida, nega. O novo helper tem EXECUTE revogado de todos os papéis de API.
Não exige `platform.read`: isso restringiria o contrato específico vigente.

Duas chamadas condicionais antecedem lookup: dispatcher somente para
list/detail/catalog e detalhe somente com `p_authorize=true`. A autorização do
domínio exato permanece após lookup, assim como Owner/escopo plataforma,
AAL1 para READ, auditoria/envelopes e ACLs das funções substituídas. Os corpos
de escrita/import/export e os caminhos `p_authorize=false` não mudam.

Teste novo separado `access_profile_models_read_prelookup_regression_test.sql`
preserva os 11 casos e acrescenta seis controles: ator authenticated, list/detail
permitidos com leitura exclusivamente institution ou Principal e negação de
detalhe plataforma/catalog, sempre sem `platform.read`. Plano 17 ainda não
executado; teste 11 original e seu hash permanecem intactos.
SHA-256 UTF-8/LF do plano 17:
`084d70c291552ff779192f96c4821b9d9b1a98dc4efaa0bec9d3435874de8e73`.

Review independente `realm_audit` sem bloqueante estático: comparação mecânica
confirmou corpos de detalhe/dispatcher idênticos à histórica, retirados apenas
os guards. Plano 17 corresponde a 16 `is` e um `ok`; controles 13/16 recusam a
restrição extra `platform.read`, e 14/17 mantêm a negação cross-domain/catalog.
O assert de auditoria comprova existência agregada, não cada negação individual.

`git diff --check` passou; inspeção de segredos encontrou somente o nome do
papel `service_role` na revogação, nenhuma credencial. Próximo gate: replay
nominal serializado do Engenheiro 1, incluindo ownership/ACL do helper novo.
Nenhuma promoção local-green, remota ou E2E neste checkpoint.
