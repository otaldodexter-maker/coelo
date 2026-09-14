---
title: "Addendum de Atividade Contextual"
source: "conversa com usuario em 2026-07-23 e 2026-07-24; docs/architecture/domain-map.md; docs/data/data-model.md; docs/product/prd-master.md; decisions/0015-contextual-people-authorizations-attendance.md; packages/coelo_database/migrations/20260910180110_superadmin_activity_save_v2.sql"
status: "implemented-database-addendum"
generated_at: "2026-07-24"
lifecycle: "current"
updated_at: "2026-09-14"
reconciled_with: "AGENTS.md; decisions/0015; decisions/0016; decisions/0034; current Supabase inventory"
---

> **Overlay vigente — 14/09/2026.** O addendum descreve regras de domínio e
> não autoriza migration nova por si só. Validar o nome físico e o estado real
> no inventário/migrations atuais; aplicar mudanças somente forward-only e pelo
> gate de backend autorizado.

# Addendum De Atividade Contextual

`Atividade` e um dominio proprio do Coelo para recortes funcionais dentro do grupo/turma.

## Regras Oficiais

- A atividade pertence sempre a instituicao e pode ser criada pela instituicao ou por unidade autorizada.
- Quando criada pela unidade, herda automaticamente a instituicao-mae, registra a unidade de origem e nasce vinculada a ela.
- A instituicao mantem autoridade para ajustar, ampliar, restringir, arquivar ou desativar a atividade criada pela unidade.
- A unidade ou usuario da unidade so cria atividade quando a capacidade especifica estiver habilitada na gestao do perfil.
- A mesma atividade pode ser reutilizada em varias turmas da mesma instituicao.
- A turma continua sendo o centro de operacao; a atividade especializa o contexto.
- Professores e coordenadores podem ser vinculados por turma, com permissoes contextuais.
- Instituicao e unidade podem sugerir atividades padrao na criacao.
- A implementacao deve começar pelo Supabase, depois menu e, por fim, tela.

## Fundacao Fisica

O dominio foi implementado em `public` com `activity_definitions`, `activity_unit_links`, `activity_group_links`, `activity_group_assignments`, `activity_permission_profiles`, `activity_permission_profile_capabilities`, `activity_assignment_permission_overrides`, `activity_capabilities` e `activity_suggestions`. Funcoes de autorizacao, criacao transacional, validacao e auditoria ficam em `app_private`; somente wrappers `security invoker` de criacao sao expostos em `public`.

Perfis definem capacidades por instituicao ou unidade. Overrides por atribuicao podem permitir ou negar uma capacidade, mas nunca criam contexto: sem atribuicao ativa da pessoa naquela atividade e turma, nao ha acesso. Conversa, presenca, eventos e Now apenas consomem esse contexto futuramente.

## Governanca Implementada

O modelo fisico separa:

- origem: instituicao ou unidade;
- disponibilidade: padrao institucional ou especifica de unidade;
- politica: opcional, obrigatoria ou fixa.

Atividade criada por unidade nasce local e visivel a instituicao. A instituicao
pode promover a mesma definicao a padrao, preservando ID, origem, historico,
professores e vinculos. Atividade fixa bloqueia configuracoes determinadas pela
instituicao.

Antes de criar, a interface deve procurar definicoes semelhantes no tenant e
priorizar reutilizacao.

## Participacao E Capacidades

O vinculo atividade-grupo deve declarar:

- toda a turma; ou
- criancas selecionadas.

Profissional exclusivo da atividade ve somente participantes. Presenca,
rotina, agenda, midia, Now e chat usam politicas institucionais:

- obrigatoria;
- ativada por padrao e editavel;
- desativada por padrao e editavel;
- proibida.

A fundacao aplicada em 2026-07-24 materializa promocao sem duplicacao,
politica institucional por capacidade, configuracao efetiva por
atividade-grupo e participacao individual de crianca. A RPC de promocao
preserva o ID e registra ator, momento e motivo em auditoria.

## Relacionamento Com O Mapa

- Tenancy continua sendo a hierarquia institucional.
- Atividade contextual fica como dominio complementar entre Tenancy e Contexto/Autorizacao.
- O dominio deve aparecer no banco, nas permissoes, no menu e nas futuras telas.
