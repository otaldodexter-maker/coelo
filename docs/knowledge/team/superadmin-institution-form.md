---
title: Formulário de instituição do Superadmin
knowledge_id: superadmin-institution-form
source: docs/superpowers/specs/2026-07-28-superadmin-institution-form-feedback-design.md
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [superadmin, institutions]
visibility: internal
review_owner: Coelo Product
---

# Formulário de instituição do Superadmin

Criar e editar instituição usam o mesmo fluxo local de sete etapas. `Identidade
visual` é a primeira etapa: a prévia compacta antecede uploads e campos; ela
separa cores de superfície, marca e texto. Em desktop, marca e texto usam três
colunas, que colapsam responsivamente. A bio aceita emoji, respeita 220
grafemas e um ícone acessível abre a seleção compacta para inserir no cursor sem
substituir o teclado nativo.

A foto de perfil deve ser PNG, JPG ou WebP, quadrada e ter no máximo 2 MB. A
prévia local usa recorte circular. Esta entrega permanece um protótipo local:
não cria persistência, convite real ou ativação de identidade.

Os campos seguem o tema Coelo com label persistente, ícone, hint contextual,
hover, foco e erro. Seleções simples seguem o contrato administrativo de opções
contínuas, superfície neutra e destaque semântico, sem menu cinza paralelo.

Menus de seleção única acompanham exatamente a largura do campo, abrem 4 px
abaixo, mostram no máximo seis opções, mantêm a busca fixa e deixam apenas a
lista rolar. Não exibem check. Popups usam a superfície neutra do tema com tint
transparente. O formulário não usa faixas cinzas decorativas em cards, conteúdo
ou rodapé.

O seletor de cor oferece área quadrada de saturação/valor, matiz contínua,
amostras atual e nova e edição HSV, RGB e hexadecimal. A localização oferece
busca contextual por CEP. O aviso de convite e ativação usa
`primaryContainer`; esta é uma ênfase informativa deliberada, não o fundo de um
popup. Plano não possui justificativa.

Diálogos administrativos reutilizam `CoeloAdminDialogShell`: cabeçalho com
divisor, fechar acessível, corpo rolável e rodapé persistente. Uma ação ocupa a
largura útil; duas dividem-na igualmente com `CoeloSpacing.space3`. Fechar usa
ícone de erro, tooltip, semântica e alvo mínimo; quando permitido, `Esc` fecha
a superfície e devolve o foco à origem.

Representante legal e administrador são perfis contextuais distintos ligados à
mesma pessoa lógica. Criação e edição mantêm pelo menos um registro de cada
papel; o último de um papel só pode ser removido depois da inclusão de outro.
Os perfis podem iniciar com dados equivalentes, mas só voltam a coincidir por
sincronização explícita. Dados de contato e identificação são opcionais no
rascunho local e, se fornecidos, são validados; o requisito de ativação real não
é simulado por esta interface.

O avatar opcional já integra o cadastro e a edição de administrador. Ele usa o
recorte circular padrão de perfil, com `Cancelar` e `Aplicar` em 50/50 e reset
por ícone circular acessível. Os controles de sincronização expõem a direção:
`Copiar dados do representante` faz representante → administrador e `Copiar
dados para o representante` faz administrador → representante.

## Referência reutilizável

Instituições é a referência canônica para novos formulários de cadastro e
edição. O contrato completo está em
`.agents/skills/coelo-ui/references/form-layout-contracts.md` e no padrão
`pattern.form-controls` do índice e catálogo.

Além dos componentes, o contrato cobre superfície neutra, grid 12/16, grupos
20, ícones contextuais, ações como busca de CEP, conteúdo especializado, rodapé
responsivo, confirmação binária 50/50 e verificação em
375/768/1024/1440, light/dark, texto a 200%, teclado, foco e semântica.

`CoeloFormTextField` é o campo-base compartilhado por autenticação, cadastro e
edição. `CoeloAdminSingleSelectField` é a seleção única de formulários
administrativos. O padrão usa 12 px entre colunas, 16 px entre linhas e 20 px
entre grupos, todos vindos da escala oficial de espaçamento.
