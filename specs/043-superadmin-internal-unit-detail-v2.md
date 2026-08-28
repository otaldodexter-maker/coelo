---
title: "Detalhe e reload v2 de Unidade para o Superadmin interno"
source: "specs/011-superadmin-database-rls.md; specs/017-superadmin-unit-schema-foundation.md; specs/039-superadmin-internal-auth-session-context.md; specs/040-superadmin-internal-institution-read-v2.md; decisions/0016-unit-type-and-plan-inheritance.md; inventário físico de packages/coelo_database/migrations em 2026-08-28"
status: "approved-for-implementation"
approval: "Coordenação Coelo em 2026-08-28; autorização técnica restrita ao detail/reload read-only desta spec"
generated_at: "2026-08-28"
---

# Detalhe e reload v2 de Unidade para o Superadmin interno

## Objetivo e problema

Criar um contrato aditivo e somente leitura para detalhar e recarregar uma
Unidade pelo principal interno exclusivo da spec 039. O contrato deve refletir
somente dados físicos já existentes e a herança de plano aprovada pela ADR 0016
e pela spec 017, sem usar contratos legados como autoridade e sem antecipar
listagem, escrita, Flutter ou implantação remota.

## Escopo

- uma RPC pública de detalhe por `unit_id`; reload é uma nova chamada à mesma
  RPC e nunca estado de seleção ou cache persistido;
- revalidação de Auth, `session_id`, `auth.sessions.not_after`, auth link,
  membership, role, capability, MFA e escopo em cada chamada;
- leitura aditiva da Unidade, instituição/tipos, endereço e contato, com cálculo
  interno do plano efetivo determinístico;
- envelope estável com HTTP PostgREST 200 e `error.http_status` semântico;
- auditoria interna v2/v3, ACL mínima, não enumeração e isolamento entre
  instituições e Unidades.

## Fora de escopo

- listagem, busca, filtros e opções de filtro de Unidades;
- criar, editar, alterar status ou mover Unidade de instituição;
- arquivos, importação, exportação, mídia ou notificações;
- Flutter, repository, cutover, deploy ou validação remota;
- branding institucional ou de Unidade;
- `groups_count`, `activities_count` ou qualquer outro contador/agregado;
- Administradores, Pessoas, Convites, Turmas ou Atividades contextuais;
- revogar, substituir ou reinterpretar views, policies, tabelas, RPCs ou grants
  legados antes de cutover integrado aprovado.

## Autoridade aprovada e limite da decisão

Esta aprovação autoriza **somente esta leitura v2** a reutilizar a capability
física `platform.read`, sempre combinada com a allowlist de papéis
`owner`, `operations` e `auditor` e com o escopo resolvido pela identidade
interna da spec 039.

- `owner` exige AAL2;
- `operations` e `auditor` seguem `platform_permissions.requires_mfa`;
- `support` e `content` permanecem fail-closed para esta RPC;
- membership `platform` autorizado pode detalhar Unidade de qualquer
  instituição existente dentro do alcance aprovado;
- membership `institution` autorizado só pode detalhar Unidade cuja
  `institution_id` seja exatamente sua `scope_institution_id`;
- o `unit_id`, claims e qualquer contexto enviado pelo cliente são não
  confiáveis e nunca concedem escopo.

A aprovação desta spec **não cria, aprova, restaura, substitui nem implica** as
capabilities `units.read`, `units.create` ou `units.update`. `units.read` está
ausente e não pode ser inventada por migration, seed, helper, teste ou fallback.
A OQ-032 permanece aberta para a taxonomia ampla de capabilities de Unidades;
esta exceção focal com `platform.read` não decide listagem nem qualquer mutação.

## Interface pública

```sql
public.superadmin_unit_detail_v2(
  p_unit_id uuid
) returns jsonb
```

O wrapper é `VOLATILE SECURITY DEFINER`, owner `postgres`,
`search_path = ''` e tem `EXECUTE` somente para `authenticated`. `PUBLIC`,
`anon` e `service_role` permanecem sem `EXECUTE`. Helpers novos ficam em
`app_private`, sem grants de cliente, com owner e configuração equivalentes.

O wrapper chama o contexto interno da spec 039 com `platform.read`, aplica a
allowlist adicional desta spec e valida o escopo antes de materializar qualquer
dado do alvo. Nenhuma função, view ou policy legada é fonte de autorização.

## Envelope e erros

O retorno segue o envelope interno da spec 039. O transporte PostgREST retorna
HTTP 200; `ok=false` carrega `error.code`, mensagem minimizada e
`error.http_status` semântico.

Unidade inexistente e Unidade fora do escopo retornam exatamente o mesmo erro
`SAI_PERMISSION_DENIED`, com `error.http_status=403`, sem confirmar instituição,
tipo, status, slug, endereço, contato ou plano. O comportamento deve ser
indistinguível também em auditoria exposta ao chamador e em tempo razoavelmente
equivalente; não existe lookup público prévio que forme oracle.

## Output físico mínimo

Em sucesso, `data` possui exatamente esta forma lógica, sem chaves adicionais:

```json
{
  "id": "uuid",
  "institution": {
    "id": "uuid",
    "name": "text",
    "type": {
      "id": "uuid",
      "name": "text"
    }
  },
  "name": "text",
  "slug": "text",
  "status": "record_status",
  "unit_type": {
    "id": "uuid",
    "name": "text"
  },
  "address": {
    "country": "text",
    "state": "text|null",
    "city": "text|null",
    "district": "text|null",
    "street": "text|null",
    "number": "text|null",
    "complement": "text|null",
    "postal_code": "text|null"
  },
  "contact": {
    "email": "text|null",
    "phone": "text|null",
    "mobile_phone": "text|null"
  },
  "effective_plan": {
    "id": "uuid",
    "code": "text",
    "name": "text",
    "inherited": true
  }
}
```

Regras de nullability:

- `address` é `null` quando não existe linha não arquivada em
  `unit_addresses`; linha com `status='archived'` é tratada como ausente.
  Quando existe linha não arquivada, contém somente as oito chaves
  documentadas;
- `contact` é `null` quando não existe linha não arquivada em `unit_contacts`;
  linha com `status='archived'` é tratada como ausente. Quando existe linha não
  arquivada, contém somente `email`, `phone` e `mobile_phone`;
- `effective_plan` é `null` somente quando não há override e a assinatura
  institucional selecionada não fornece plano físico; quando existe, expõe
  exatamente `id`, `code`, `name` e `inherited`;
- nenhuma URL, pessoa, documento, timestamp, dado de sessão, branding ou
  contador entra no payload.

`institution.name` deriva de `institutions.public_name`.
`institution.type` deriva do tipo físico da instituição.
`unit_type` deriva de `units.institution_type_id` no mesmo catálogo
`institution_types`; o nome do campo de output não cria um novo catálogo.

## Plano efetivo determinístico

O cálculo preserva a ADR 0016 e a spec 017:

1. se `units.plan_override_id` não é nulo, `effective_plan` é exatamente o
   plano físico do override e `inherited=false`;
2. sem override, selecionar a assinatura física da instituição por
   `institution_id`, com a assinatura vigente do schema atual e desempate
   determinístico `created_at DESC, id DESC`, `LIMIT 1`;
3. `effective_plan` é o plano dessa assinatura e `inherited=true`;
4. remover ou alterar override, assinatura ou plano está fora desta spec.

`plan_override` nunca é uma chave de output. A existência ou ausência do FK
físico é apenas insumo server-side para produzir o único campo
`effective_plan`.

O detail não persiste o resultado efetivo, não copia o plano institucional para
a Unidade e não inventa regra nova de status de assinatura.

## Auditoria e atomicidade

- action code: `unit.detail` para detalhe e reload;
- capability registrada: `platform.read`;
- sucesso com ator interno completo usa audit v2 e outcome `success`;
- negativa com ator completo usa v2; após sessão válida, mas antes de principal
  interno completo, usa v3 conforme a spec 039;
- sessão ausente, inválida, divergente ou expirada não fabrica audit;
- ID solicitado, endereço, contato, slug e plano não entram no metadata de
  negação; metadata de sucesso permanece minimizado;
- cada chamada aceita gera exatamente um evento correlacionado;
- falha do append de auditoria aborta a RPC; não existe sucesso sem audit.

## Compatibilidade

O pacote é aditivo. Não revoga, altera ou amplia grants de contracts legados,
RLS ou Data API. Não usa as policies legadas como autoridade e não transforma
acesso direto a tabelas em contrato suportado. Qualquer cutover ou revogação
posterior exige spec, migration forward-only e regressão Flutter + Supabase
separadas.

## Critérios de aceite

- Owner AAL2, Operations e Auditor autorizados recebem o payload exato; Owner
  AAL1, Support e Content recebem negação estável;
- membership `platform` autorizado lê Unidades A/B; membership `institution`
  lê somente Unidades de sua própria instituição;
- ID de outra instituição, de outra Unidade, inexistente ou adulterado não
  forma oracle e retorna o mesmo 403 sem dados;
- sessão ausente/divergente/expirada, auth link revogado ou membership
  suspensa/revogada falham antes do payload;
- instituição, tipo institucional, tipo da Unidade, endereço e contato refletem
  somente linhas físicas e nullability documentada;
- override prevalece; sem override, o plano institucional usa
  `created_at DESC, id DESC`; empate e ausência de plano são determinísticos;
- reload após alteração transacional de fixture observa o novo valor persistido;
- output omite branding, todos os contadores, activities, pessoas, documentos,
  timestamps e dados Auth;
- audit v2/v3 é 1:1, correlacionado e minimizado; append adversarial falha
  fechado;
- ACL nega `PUBLIC`, `anon` e `service_role`; helper privado não tem grant de
  cliente; owner e `search_path` são verificados;
- nenhuma `units.read`, `units.create` ou `units.update` é criada, restaurada,
  substituída ou usada; OQ-032 continua aberta;
- sem deploy e E2E, o máximo declarável é `local-green`.

## Testes exigidos

- estrutura, assinatura, owner, volatility, `SECURITY DEFINER`, `search_path`,
  ACL do wrapper e ausência de grants nos helpers;
- sucesso Owner AAL2, Operations e Auditor; negativas Owner AAL1, Support e
  Content;
- sessão ausente, divergente e expirada; auth link e membership nos estados
  `active`, `suspended` e `revoked`; capability/relação de role removida durante
  lifecycle;
- platform scope em duas instituições e institution scope limitado à sua FK;
- cross-tenant, cross-institution, cross-unit, ID inexistente e adulterado com
  resposta idêntica e sem vazamento;
- shape e tipos exatos de todas as chaves; ausência explícita de branding,
  `groups_count`, `activities_count` e extras;
- endereço e contato presentes/ausentes, campos anuláveis e linhas archived
  tratadas como ausentes simetricamente;
- plano com override, sem override, assinatura mais recente, empate por `id` e
  ausência de assinatura/plano;
- persistência e reload após update transacional de fixture;
- audit positivo/negativo v2/v3, correlação 1:1, minimização e append
  fail-closed;
- regressões Auth 039, detalhe de Instituição 040 e contratos de Unidade
  existentes; fixtures transacionais e teardown sem resíduos.

## Riscos e perguntas abertas

- OQ-032 permanece aberta; esta spec não generaliza `platform.read` para outras
  ações de Unidade.
- Semântica de contagem de Atividades não está aprovada; por isso nenhum
  `activities_count` é retornado. Todos os contadores ficam fora desta fatia.
- Branding físico existe, mas foi explicitamente excluído deste output.
- List/filter e toda mutação exigem specs e autorizações independentes.
