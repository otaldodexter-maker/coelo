---
title: Etapa de conclusão visual do Coelo
knowledge_id: coelo-visual-completion-stage
source: docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md
status: validated
generated_at: 2026-08-28
updated_at: 2026-08-28
audience: team
surfaces: [superadmin, principal-preview, flutter, design-system]
visibility: internal
review_owner: Coelo Product
---

# Etapa de conclusão visual do Coelo

A primeira entrega da retomada Flutter é o programa de conclusão visual de 31
entregáveis, dividido em cinco ondas. Ele precede revisão arquitetural profunda,
componentização ampla, integração Supabase e prova ponta a ponta.

O recorte permite navegação e comportamento local com fixtures seguras, mas não
autoriza persistência, publicação, arquivo, mídia ou autorização remotos. Ações
de importar, exportar e baixar permanecem visíveis quando pertencem à tarefa do
usuário; sem backend, comunicam indisponibilidade e nunca simulam sucesso.

Entradas genéricas `Criar ...` saem do menu lateral. Assiduidade mantém `Nova
chamada`, e Acontece, Momentos e Agora mantêm suas entradas próprias de
publicação. O dashboard de Assiduidade não repete esse CTA.

Instituições continua sendo a baseline de diretórios e Cards/Tabela.
Criar/Editar Instituição e `SuperadminFormActionFooter` são a baseline de todo
wizard ou formulário administrativo de criação/edição. Referências externas de
stories e reels orientam apenas anatomia, proporção e imersão; o resultado usa
identidade, tokens, acessibilidade e privacidade Coelo.

Os quatro padrões ainda ausentes no índice `coelo-ui` devem ser promovidos antes
do código que os consome: construtor de perguntas, seletor Coelo de hora, viewer
social fullscreen e perfil rico do Principal.

Relatórios de progresso separam programa visual, Flutter local, Flutter
`verified`, Supabase, integração E2E e projeto estrito. `0/207 E2E` nunca deve ser
apresentado como progresso Flutter.
