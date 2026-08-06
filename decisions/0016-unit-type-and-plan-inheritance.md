---
title: "Tipo Próprio E Herança De Plano Por Unidade"
source: "aprovação do plano Tela de Unidades no Superadmin em 2026-07-28; schema Supabase consultado em 2026-07-28; specs/017-superadmin-unit-schema-foundation.md"
status: "Accepted"
generated_at: "2026-07-29"
updated_at: "2026-08-05"
---

# Tipo Próprio E Herança De Plano Por Unidade

## Contexto

Uma instituição pode operar unidades com especializações e condições
comerciais diferentes. O tipo e o plano da instituição, isoladamente, não
descrevem todos os seus filhos. Ao mesmo tempo, repetir o plano em cada unidade
eliminaria a herança e faria alterações institucionais deixarem de se propagar.

Antes da fundação da spec 017, `units` continha vínculo institucional, nome,
slug, status e timestamps, mas não possuía tipo nem override de plano. O schema
já continha `unit_addresses`, `unit_contacts`, `unit_branding`, `groups` e
`activity_unit_links`.

## Decisão

- Toda unidade pertence obrigatoriamente a uma instituição.
- A unidade possui tipo próprio e usa o mesmo catálogo taxonômico dos tipos de
  instituição; não existe um segundo catálogo de tipos.
- O plano efetivo da unidade é `override da unidade ?? plano da instituição`.
- Uma unidade nova herda o plano institucional por padrão.
- Enquanto não houver override, alterações no plano institucional são
  refletidas automaticamente na unidade.
- Remover o override restaura a herança.
- A instituição de uma unidade existente não pode ser trocada nesta operação.
- Os status persistíveis são `draft`, `active`, `inactive`, `suspended` e
  `archived`.
- A interface usa o termo `Turma`, preservando identificadores técnicos
  existentes como `group*`.
- Criar/Editar Unidade organiza a gestão contextual em etapas independentes de
  Administradores, Pessoas, Convites, Turmas e Atividades.
- Administradores herdados da instituição são somente leitura; administradores
  incluídos manualmente podem ser editados ou removidos e recebem acesso
  contextual `Owner` do Admin na Unidade.
- Turmas e Atividades reutilizam seus fluxos existentes com instituição e
  unidade preenchidas, sem transferir seu domínio para o cadastro da unidade.
- Branding institucional é herdado por padrão e pode receber override por
  unidade através do contrato de `unit_branding`.

## Consequências

A fundação da spec 017 adiciona `units.institution_type_id` obrigatório,
referenciando `institution_types`, e `units.plan_override_id` opcional,
referenciando `plans`. Remover o override do registro restaura a herança por
`NULL`. As duas colunas são filtráveis e permanecem não importáveis até existir
contrato técnico de importação.

A migração usa o tipo da instituição-mãe para unidades existentes e falha
explicitamente se alguma delas não puder ser tipada sem inventar catálogo.

A tela ainda usa repositórios fake e estado local para Administradores, Pessoas,
Convites, Turmas e Atividades. Busca e convite de pessoas, vínculos familiares e
profissionais, além da prévia de importação/exportação CSV/XLSX, são somente
demonstrativos e não leem nem geram arquivos físicos. Persistência, Auth,
permissões de escrita, RPCs, auditoria e testes cross-tenant de mutação exigem
decisão posterior. Esta fundação não amplia grants nem policies.
