---
title: "Busca de pessoa autorizada no wizard de Segurança da criança (B5)"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md (B5, owner.r12-17; regra durável de busca); docs/reviews/etapa-2-operacao/next-round/R15-pendencias.md (owner.r12-17); docs/reviews/evidence/etapa-2/r12-coordenacao/child-safety-wizard-gates-r12.md; specs/030-superadmin-child-safety-production.md; docs/security/auth-multitenant-permissions.md §8; docs/security/lgpd-security-media.md; dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.people, public.person_handles, public.person_contacts, app_private.person_identity_identifiers, public.guardian_links, public.child_contexts, public.child_unit_links, public.authorized_people, app_private.assert_child_safety_platform, app_private.has_platform_permission(text,uuid), public.superadmin_people_identity_lookup_v1"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Busca de pessoa autorizada (B5, `owner.r12-17`)

## Objetivo e decisão de produto

O wizard de Segurança da criança (`child-safety.create`/`child-safety.edit`)
deixa de pedir o UUID técnico da pessoa global. Um **campo único** busca a
pessoa autorizada conforme o operador digita e o resultado permite escolher a
pessoa e, quando ela é responsável, a criança vinculada — um clique preenche
criança + pessoa autorizada. Contrato aprovado pelo Owner na ADR 0041 B5.

Regra durável (ADR 0041, "Regra durável de segurança"): toda busca por
prefixo sobre dado pessoal exige mínimo de caracteres, escopo do ator,
auditoria, limite de taxa e resultado minimizado; CPF nunca aparece.

## Contrato backend

`public.superadmin_person_search_v1(p_query text) returns jsonb`, wrapper
`security definer` de `app_private.superadmin_person_search_v1`, execute só
para `authenticated`/`service_role`.

Ator: `app_private.assert_child_safety_platform('child_safety.read')` (ator
do realm de pessoas, com capacidade de plataforma; mesma guarda do diretório
e da busca de crianças). Escopo: instituições em que
`has_platform_permission('child_safety.read', institution_id)` é verdadeiro —
membership de plataforma vê todas; membership escopada vê só a sua.

Detecção automática do tipo (backend normaliza; máscara é ignorada):

| Entrada | Tipo | Mínimo | Correspondência |
|---|---|---|---|
| começa com `@` | `handle` | 3 caracteres após o `@` | prefixo de `person_handles.normalized_handle` ativo |
| contém `@` | `email` | 3 caracteres | igualdade pelo hash SHA-256 do e-mail normalizado (`person_contacts`) — e-mail é guardado só como hash, então só o endereço completo encontra |
| só dígitos, espaços e `().+-` | `digits` | 4 dígitos | celular: contém os dígitos em `people.mobile_phone`, ou hash exato em `person_contacts` (≥ 8 dígitos); CPF: com 11 dígitos válidos, igualdade pelo HMAC de `person_identity_identifiers` |
| qualquer outra | `name` | 3 caracteres | `display_name`, `legal_name` ou `first_name last_name` contendo o texto |

Abaixo do mínimo → `22023` (`PERSON_SEARCH_MIN_LENGTH`); acima de 120
caracteres → `22023` (`PERSON_SEARCH_INVALID`). CPF parcial (6–10 dígitos)
**não** encontra por CPF: o CPF só existe como HMAC (nunca em claro), logo a
correspondência exige o número completo; o trecho parcial é tratado como
celular. Isso preserva a regra "CPF nunca em claro" e fica registrado aqui
como limite consciente da decisão B5.

Pessoa candidata: adulto ativo com presença no escopo do ator — vínculo de
responsável (`guardian_links`) com criança que tem `child_contexts` ativo na
instituição, ou `authorized_people` ativo na instituição, ou membership
institucional ativa. Pessoas fora do escopo não aparecem (cross-tenant vazio).

Resultado minimizado (máximo 10, por nome):

```json
{"ok":true,"kind":"name","results":[{"person_id":"…","display_name":"…",
 "initials":"AM","handle":"@ana.maria","phone_last4":"1234","matched_by":"name",
 "has_account":true,"children":[{"child_id":"…","child_name":"…",
 "child_context_id":"…","institution_id":"…","institution_name":"…",
 "unit_id":"…","unit_name":"…"}]}]}
```

Nunca no payload: CPF (nem mascarado), e-mail, celular inteiro, UUID de
contato. `children` lista só crianças **com vínculo** ativo ao responsável e
contexto/unidade ativos dentro do escopo do ator.

Limite de taxa: 30 chamadas por minuto por ator (tabela privada
`app_private.person_search_hits`, RLS forçada, sem grants); a 31ª responde
SQLSTATE `PT422` (HTTP 422, sem retentativa) com `detail
PERSON_SEARCH_RATE_LIMIT`. Auditoria: cada busca bem-sucedida grava
`audit.audit_logs` com `action_code child_safety.person_search`, ator, AAL,
tipo detectado e contagem de resultados — nunca o texto buscado.

## Frontend (Superadmin)

- Etapa "Pessoa autorizada" do wizard: campo único "Buscar pessoa autorizada"
  (nome, @, e-mail, celular ou CPF), com debounce de 300 ms e busca só quando
  o mínimo do tipo detectado é atingido (mesma tabela acima, em Dart puro,
  testada); abaixo do mínimo a tela orienta sem chamar o servidor.
- Resultado: card por pessoa com iniciais, nome, `@handle` e `•••• 1234`;
  clicar seleciona a pessoa (UUID fica só no comando). Se a pessoa tem
  crianças no escopo, cada criança aparece como ação "Selecionar <criança>"
  que preenche a etapa "Criança" (contexto/unidade) e a pessoa de uma vez.
- Edição (`authorizationId` presente) mantém a pessoa da autorização como
  texto somente leitura; a busca fica disponível só na criação.
- Revisão mostra o nome da pessoa selecionada, não o UUID.
- Erros: `PT422` → "Muitas buscas em sequência. Aguarde um minuto."; `42501`
  → contexto negado (padrão do wizard); demais → "Não foi possível buscar
  pessoas."
- Adapter: `SupabaseChildSafetyRepository` implementa
  `ChildSafetyPersonSearchSupport.searchPeople` chamando a RPC; o repositório
  de desenvolvimento devolve massa sintética; `Unavailable` não implementa e
  o controlador falha fechado.

## Critérios de aceite e testes

- pgTAP (`child_safety_person_search_v1_test.sql`, espelho restaurado do dump
  de 17/09): estrutura e grants; mínimo por tipo; nome/@/e-mail/celular/CPF
  encontram; CPF ausente do payload; cross-tenant vazio; crianças só do
  escopo; 31ª chamada → `PT422`; auditoria gravada sem o texto; ator sem
  `child_safety.read` → `42501`.
- Flutter: detecção de tipo/mínimo em Dart; wizard busca conforme digita,
  seleção preenche criança + pessoa, revisão mostra o nome, rate limit exibe a
  mensagem; suítes de Segurança da criança verdes.
- Rota real (`qa-r06-acessos`, massa `QA R15` do Bloco B): buscar o
  responsável sintético por nome, @, últimos dígitos do celular e CPF
  completo; selecionar a criança pelo resultado; enviar para aprovação;
  reload; negativa por PostgREST (31 chamadas → 422) → `owner.r12-17` done.
