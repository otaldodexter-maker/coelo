---
title: Diretório de unidades do Superadmin
knowledge_id: superadmin-unit-directory
source: decisions/0016-unit-type-and-plan-inheritance.md
status: validated
generated_at: 2026-07-29
updated_at: 2026-08-05
audience: team
surfaces: [superadmin, units]
visibility: internal
review_owner: Coelo Product
---

# Diretório de unidades do Superadmin

O diretório de unidades replica os padrões de Instituições para cards, tabela
redimensionável, filtros, paginação, estados e formulário responsivo. A
hierarquia apresentada é Instituição → Unidade → Turma → Atividade → Pessoa,
sem criar um novo item de Pessoas no menu Estrutura nesta entrega.
Identificadores técnicos existentes, como `group*`, permanecem inalterados.

Toda unidade pertence obrigatoriamente a uma instituição e possui tipo próprio,
classificado pelo mesmo catálogo usado pelas instituições. Seu plano efetivo é
o override local quando definido; caso contrário, acompanha ao vivo o plano da
instituição. A instituição-mãe fica bloqueada durante a edição.

Os filtros incluem instituição, tipo, plano efetivo e localização. O status é
apresentado em tabs: Todos, Ativos, Em Implantação e Inativos. `draft` aparece
em Em Implantação; `inactive`, `suspended` e `archived` aparecem em Inativos,
sem alterar os valores persistidos.

Criar/Editar Unidade possui etapas independentes de Administradores, Pessoas,
Convites, Turmas e Atividades. Administradores herdados da instituição são
somente leitura; os incluídos manualmente podem ser editados ou removidos e têm
acesso contextual `Owner` do Admin na Unidade. Pessoas permite demonstrar busca,
convite, cadastro familiar e profissional hierarquizado e Perfil de Acesso.
Turmas e Atividades reutilizam seus fluxos existentes com o contexto da unidade
preenchido.

O schema agora possui `units.institution_type_id` obrigatório e
`units.plan_override_id` opcional. O tipo usa `institution_types`; o override
usa `plans`, e `NULL` mantém a herança do plano institucional. As duas colunas
são filtráveis e não importáveis no catálogo atual.

A tela ainda usa repositórios fake e estado em memória. Busca, convite, vínculos
de pessoas e os botões de importação/exportação CSV/XLSX são demonstrativos;
nenhum arquivo físico é lido ou gerado. Não há integração de Auth ou backend
nesta entrega. A ADR 0031 adia persistência, mutações auditadas e contratos
físicos de importação/exportação para depois do MVP.
