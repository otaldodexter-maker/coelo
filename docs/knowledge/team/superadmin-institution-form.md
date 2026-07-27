---
title: Formulário de instituição do Superadmin
knowledge_id: superadmin-institution-form
source: docs/superpowers/specs/2026-07-27-superadmin-institution-form-visual-refactor-design.md
status: validated
generated_at: 2026-07-27
audience: team
surfaces: [superadmin, institutions]
visibility: internal
review_owner: Coelo Product
---

# Formulário de instituição do Superadmin

Criar e editar instituição usam o mesmo fluxo de seis etapas. `Identidade
visual` é a primeira etapa e reúne foto de perfil, nome de exibição,
identificador institucional e cores.

A foto de perfil deve ser PNG, JPG ou WebP, quadrada e ter no máximo 2 MB. A
prévia local usa recorte circular; a persistência definitiva depende do fluxo
server-side de mídia em Cloudflare R2.

Os campos seguem o tema Coelo com label persistente, ícone, hint contextual,
hover, foco e erro. Seleções simples seguem o contrato administrativo de
opções contínuas, superfície neutra e destaque semântico, sem menu cinza
paralelo.

Menus de seleção única acompanham exatamente a largura do campo e não exibem
check. Popups usam a superfície neutra do tema com tint transparente. O
formulário não usa faixas cinzas decorativas em cards, conteúdo ou rodapé.

O seletor de cor oferece área quadrada de saturação/valor, matiz contínua,
amostras atual e nova e edição HSV, RGB e hexadecimal. A localização oferece
busca contextual por CEP. O aviso de convite e ativação usa
`primaryContainer`; esta é uma ênfase informativa deliberada, não o fundo de um
popup. Plano não possui justificativa. A confirmação de saída reserva metade da
largura para cada uma das duas ações.

`CoeloFormTextField` é o campo-base compartilhado por autenticação, cadastro e
edição. `CoeloAdminSingleSelectField` é a seleção única de formulários
administrativos. O padrão usa 12 px entre colunas, 16 px entre linhas e 20 px
entre grupos, todos vindos da escala oficial de espaçamento.
