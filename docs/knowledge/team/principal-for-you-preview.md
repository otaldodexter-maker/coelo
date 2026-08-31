---
title: "Para você do Principal"
knowledge_id: "principal-for-you-preview"
source: "docs/superpowers/specs/2026-08-20-coelo-principal-for-you-preview-design.md"
status: "validated"
generated_at: "2026-08-20"
updated_at: "2026-08-31"
audience: "team"
surfaces: [principal, para-voce, superadmin-preview, context]
visibility: "internal"
review_owner: "Coelo Product e Design"
---

# Para você do Principal

`Para você` é o hub editorial-contextual do responsável: combina prioridade,
orientação, resumo do dia e contexto sem assumir um aluno ativo. Não substitui
Aviso, não abre como popup e não funciona como feed.

O preview atual vive em `/dev/principal-for-you` no Superadmin, conectado a
Acontece. Ele recebe destaques ordenados, escolhe o primeiro elegível e demonstra
troca local entre visão geral e aprofundamento por criança. A seleção local não
implementa autorização, persistência ou a troca produtiva de experiência da ADR
0012.

O conteúdo produtivo usa o contrato compartilhado de Comunicações. Itens
`highlight`, `content_card` e `for_you` podem ser projetados no hub conforme
status, vigência, prioridade e elegibilidade; `popup` permanece Aviso e é
excluído antes da apresentação. Comportamento obrigatório, tamanho e inset de
popup não fazem parte do modelo de leitura de `Para você`.

A composição visual aprovada segue a ordem saudação/contexto, destaque
protagonista, atalhos, conteúdo editorial, resumo do dia e contexto atual. O web
deve preservar literalmente shell, contêiner direito, largura útil, insets,
raios e gaps canônicos. Mobile, tablet e web usam o dock flutuante global do
Principal; a ação laranja central de publicar no Agora é entre 10% e 25% maior
que a proposta e cruza exatamente em 50/50 o limite superior do dock.

O container de rota consulta `NoticeRepository` pelos tipos produtivos e status
ativo, aplica a projeção e trata carregamento, ausência de comunicações e falha
com retry. A ausência de conteúdo editorial não remove os atalhos e o contexto
útil do hub.

Ao trocar repository, dados de apoio ou relógio, a rota limpa o resultado
anterior e só aceita a geração nova. O seletor mantém um contexto apenas quando
seu ID ainda existe nos dados recebidos, fecha sheets pertencentes ao contexto
anterior e nunca aplica uma seleção tardia em outro contexto. Acesso negado é
fail-closed, sem conteúdo anterior e sem ação de retry.

Agora e Momentos são abertos por navegação empilhada a partir do hub. Fechar o
viewer devolve à mesma origem e restaura o foco do gatilho. O conteúdo e o CTA
do protagonista permanecem alcançáveis acima do dock em texto a 200% por scroll
seguro, sem reduzir artificialmente a escala tipográfica.
