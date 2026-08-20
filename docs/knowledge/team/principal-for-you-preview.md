---
title: "Para você do Principal"
knowledge_id: "principal-for-you-preview"
source: "docs/superpowers/specs/2026-08-20-coelo-principal-for-you-preview-design.md"
status: "validated"
generated_at: "2026-08-20"
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

O container de rota consulta `NoticeRepository` pelos tipos produtivos e status
ativo, aplica a projeção e trata carregamento, ausência de comunicações e falha
com retry. A ausência de conteúdo editorial não remove os atalhos e o contexto
útil do hub.
