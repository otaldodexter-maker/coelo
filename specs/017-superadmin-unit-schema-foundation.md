---
title: "Fundação de tipo e herança de plano por unidade"
source: "decisions/0016-unit-type-and-plan-inheritance.md; specs/011-superadmin-database-rls.md; docs/data/data-model.md"
status: "implemented-database-foundation"
generated_at: "2026-07-29"
---

# Fundação de tipo e herança de plano por unidade

## Objetivo e problema

Materializar no schema a decisão de que toda unidade possui tipo próprio e
herda o plano da instituição quando não existe override local. O registro
persistido ainda não representava essas duas dimensões aprovadas pela ADR 0016.

## Escopo

Esta fundação:

- adiciona `units.institution_type_id` obrigatório, usando
  `institution_types`;
- adiciona `units.plan_override_id` opcional, usando `plans`;
- preenche o tipo das unidades existentes a partir da instituição-mãe antes de
  torná-lo obrigatório;
- indexa os filtros por instituição, tipo, status e override de plano;
- cataloga as duas colunas como ativas, filtráveis e não importáveis.

Ficam fora de escopo: diretório agregado, cálculo persistido do plano efetivo,
RPCs de criação/edição, grants ou policies de escrita, auditoria, eventos,
importação/exportação e alterações nas telas Flutter.

## Entidades, dados e integridade

- `institution_type_id` referencia `institution_types(id)`. A unidade pode ter
  tipo diferente da instituição, mas usa o mesmo catálogo.
- `plan_override_id` referencia `plans(id)`. `NULL` significa herdar ao vivo o
  plano institucional.
- A migração interrompe com erro explícito se existir unidade cuja
  instituição-mãe ainda não tenha tipo; ela não inventa um valor de catálogo.
- A instituição-mãe continua imutável na operação de edição prevista pela ADR.
- Os status permanecem os de `record_status`: `draft`, `active`, `inactive`,
  `suspended` e `archived`.

## Permissões e regras de tenant

A fundação preserva a RLS e a policy de leitura existentes em `units`.
Nenhuma mutação direta é concedida a `authenticated`. Criação e edição
produtivas continuam bloqueadas até uma spec posterior definir caminho
server-side, capacidades, MFA quando aplicável, auditoria e testes
cross-tenant.

As FKs existentes por `institution_id` permanecem responsáveis pela hierarquia
da unidade. O tipo e o plano são catálogos globais; não concedem acesso e não
substituem membership ou autorização contextual.

## Superfícies e estados de UX

A mudança prepara o diretório, Criar unidade e Editar unidade do Superadmin,
sem alterar a UI nesta fatia. Loading, vazio, sem resultados, erro, sem
permissão, inexistente e confirmação de saída continuam contratos da camada de
apresentação. Nenhum campo deve indicar persistência enquanto o app usar o
repositório fake.

## Eventos, logs e notificações

Esta migração não emite evento de produto, log de auditoria ou notificação. A
futura mutação produtiva deverá registrar ator, instituição, unidade, tipo,
mudança de override e resultado sem copiar dados pessoais desnecessários.

## Critérios de aceite

- `units.institution_type_id` existe, é `NOT NULL` e referencia
  `institution_types`.
- `units.plan_override_id` existe, é anulável e referencia `plans`; remover o
  override do registro restaura a herança por `NULL`.
- Unidades existentes recebem o tipo da instituição-mãe, ou a migração falha
  explicitamente quando isso não é possível.
- Os índices de filtro existem sem substituir os índices de tenant atuais.
- Ambas as colunas aparecem em `schema_columns` como filtráveis e não
  importáveis.
- Nenhuma policy, grant ou RPC de escrita é adicionada.

## Testes exigidos

- validação de colunas, nullability, FKs, índices e catálogo;
- preservação da unicidade de slug por instituição;
- cálculo do plano efetivo por
  `coalesce(plan_override_id, plano da assinatura institucional)`;
- preservação da RLS e da única policy `units_platform_read`, sem policies de
  escrita;
- rejeição de unidade sem tipo ou com tipo inexistente;
- reset/dry-run completo das migrations antes de aplicação remota;
- advisors de segurança e performance após o dry-run.

## Riscos e perguntas abertas

- A aplicação remota depende de todas as instituições com unidades terem tipo
  definido.
- O filtro por plano efetivo combina override local com assinatura
  institucional e exigirá query/view própria no diretório agregado.
- Permissões de escrita, auditoria, importação e exportação permanecem abertas
  em `docs/open-questions.md`.
