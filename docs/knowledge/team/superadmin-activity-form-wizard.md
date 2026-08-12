---
title: Wizard de atividade do Superadmin
knowledge_id: superadmin-activity-form-wizard
source: docs/superpowers/specs/2026-08-04-superadmin-activity-form-wizard-design.md
status: validated
generated_at: 2026-08-11
audience: team
surfaces: [superadmin, activities]
visibility: internal
review_owner: Coelo Product
---

# Wizard de atividade do Superadmin

Criar e Editar Atividade usam um wizard responsivo e produtivo de quatro
etapas. Salvar rascunho e concluir chamam comandos
idempotentes, autorizados e auditados; nenhum callback habilitado pode ser no-op.
Salvar rascunho exige nome, instituição e ao menos uma unidade; concluir também
exige ao menos uma turma.

Locais pertencem a uma unidade e a aplicação para várias unidades cria registros
irmãos em uma transação. Vínculo Aluno e Vínculos Profissionais são separados.

Categoria, subtipo e modelos usam catálogo versionado. A governança aceita
Opcional ou Obrigatória; o valor legado Fixa é preservado somente para leitura.
Profissionais são pessoas globais vinculadas por turma, com permissões
normalizadas para Chat, Now, Happens, Moments e Chamada. Notas permanece
indisponível até existir contrato backend real.

A busca produtiva de profissionais aceita nome e `@` e permanece limitada a
adultos com membership ativa na instituição selecionada. Ela exige
`activities.assign_people` e MFA. Busca por CPF, e-mail ou celular não está
disponível: os identificadores protegidos ainda não possuem comando canônico de
lookup com digest server-side. Esses formatos falham fechados com SQLSTATE
`0A000` até a decisão OQ-038; a UI não deve anunciá-los como opção.

O catálogo versionado contém categorias, subtipos e 40 modelos iniciais. Aos
21 modelos originais somam-se Coral, Fotografia, Cerâmica, Futebol, Basquete,
Vôlei, Handebol, Atletismo, Ginástica, Francês, Libras, Matemática, Física,
Química, Biologia, Astronomia, Cultura maker, Alfabetização e Educação
financeira. Assim, os filtros cobrem esportes, artes, idiomas, ciências exatas
e naturais, tecnologia, apoio pedagógico, bem-estar, sustentabilidade, vida
prática e desenvolvimento socioemocional.

Começar a partir de um modelo usa uma única chamada idempotente de upsert. O
servidor valida o modelo e a instituição, aplica defaults, mescla os dados
editados, persiste a origem imutável e audita na mesma transação; não existe
draft órfão entre duas RPCs. Duplicar MODELO é um comando separado que cria uma
cópia institucional.

Loading, opções vazias, validação, conflito, falha e sem permissão são estados
honestos. O formulário não injeta catálogo local, fixture, callback sem efeito
ou sucesso antes da persistência.
