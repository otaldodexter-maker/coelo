---
title: Diretório de turmas do Superadmin
knowledge_id: superadmin-group-directory
source: docs/superpowers/specs/2026-07-29-superadmin-group-directory-design.md
status: validated
generated_at: 2026-08-03
audience: team
surfaces: [superadmin, groups]
visibility: internal
review_owner: Coelo Product
---

# Diretório de turmas do Superadmin

No Superadmin, `Turma` é o termo visível único para a entidade educacional
persistida tecnicamente como `group*`, nunca uma entidade-pai. Cada turma
pertence a uma instituição e a uma unidade; na criação, a unidade só
pode ser selecionada dentro da instituição escolhida. Durante a edição,
instituição e unidade ficam somente leitura até que exista regra aprovada para
movimentação hierárquica.

O diretório oferece cards e tabela, busca, filtros multi-select de instituição,
unidade, tipo e status, ordenação e paginação sticky. O filtro de unidades
depende das instituições selecionadas e descarta seleções incompatíveis. Cards
iniciam com 11 itens e tabela com 8; ambos oferecem também 20, 50 e 100 itens
por página.

O formulário reúne instituição, unidade, nome, tipo textual e status. O
`group_type` é texto livre: `class` é apresentado como `Turma`, valores novos
são preservados e os filtros mostram os tipos existentes. Os status são
`draft`, `active`, `inactive`, `suspended` e `archived`; novos grupos iniciam
em `active`.

O formulário usa seis etapas responsivas: Hierarquia, Identidade, Vínculos e
aparência, Pessoas da turma, Profissionais e admins e Convites. Em telas
médias/amplas, a navegação é lateral; no compacto, usa resumo acessível. Somente
instituição, unidade, nome, tipo textual e status são persistidos; pessoas,
profissionais e convites permanecem demonstrações locais, sem criar domínio ou
autorização.

Importar turmas e Exportar turmas permanecem como botões visíveis com
indisponibilidade honesta, sem arquivo, parser ou persistência durante o MVP,
conforme ADR 0031. A entrega usa repositório fake
local independente: o Supabase atual só permite leitura de grupos por
`platform.read`, e a interface não infere autorização por metadata do cliente
nem contorna RLS.
