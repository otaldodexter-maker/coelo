---
title: Diretório de unidades do Superadmin
knowledge_id: superadmin-unit-directory
source: decisions/0016-unit-type-and-plan-inheritance.md
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [superadmin, units]
visibility: internal
review_owner: Coelo Product
---

# Diretório de unidades do Superadmin

O diretório de unidades replica os padrões de Instituições para cards, tabela
redimensionável, filtros, paginação, estados e formulário responsivo. A
hierarquia apresentada é Instituição → Unidade → Grupo → Atividade → Pessoa,
sem criar um novo item de Pessoas no menu Estrutura nesta entrega.

Toda unidade pertence obrigatoriamente a uma instituição e possui tipo próprio,
classificado pelo mesmo catálogo usado pelas instituições. Seu plano efetivo é
o override local quando definido; caso contrário, acompanha ao vivo o plano da
instituição. A instituição-mãe fica bloqueada durante a edição.

Os filtros incluem instituição, tipo, status, plano efetivo e a cascata
UF → Município → Bairro. Alterar um nível geográfico limpa seleções
descendentes incompatíveis. Grupos e atividades são métricas somente leitura.

O schema agora possui `units.institution_type_id` obrigatório e
`units.plan_override_id` opcional. O tipo usa `institution_types`; o override
usa `plans`, e `NULL` mantém a herança do plano institucional. As duas colunas
são filtráveis e não importáveis no catálogo atual.

A tela ainda usa repositório fake. O Supabase conserva RLS de leitura, mas não
possui RPC, grant ou policy para criar e editar unidades pelo cliente.
Diretório agregado, mutações auditadas, importação e exportação permanecem para
spec posterior.
