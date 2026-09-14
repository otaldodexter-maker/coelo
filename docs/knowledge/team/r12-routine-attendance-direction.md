---
title: "Direção de modelos, rotina e chamada"
knowledge_id: r12-routine-attendance-direction
source: docs/reviews/etapa-2-operacao/next-round/R12-apontamentos-owner.md
status: validated
lifecycle: "historical"
generated_at: 2026-09-13
audience: team
surfaces: [superadmin, attendance, daily-routine]
visibility: internal
review_owner: Coelo Owner
---

Direção aprovada, com modelos e fluxo destinados à R13 e ainda não implementados: modelos de rotina e
atividade usam como referência visual o card de modelo de atividade, com ações
Duplicar e Arquivar padronizadas conforme capacidade e origem. Abas ficam abaixo
dos filtros: Modelos de atividade / Atividades e Modelos de rotina / Rotinas.

Chamadas lançadas pertencem a Histórico de chamadas em tabela com filtros simples,
fora do diretório de gestão da rotina. Isso não cancela o dashboard aprovado.

O fluxo pretendido é Contexto → Chamada. Contexto Turma/Atividade precede os campos
dependentes, respeitando hierarquia e autorização no servidor. Somente atividade
habilitada para chamada é elegível. A rotina vinculada aparece no próprio Contexto,
somente leitura, sem troca durante o lançamento; gestão de rotina permanece separada.
Funcionários veem somente contextos permitidos por seus vínculos reais.

Menus distinguem visualmente seus níveis; alertas mantêm respiro dentro do contêiner.
Arquivamento de modelos imutáveis, comportamento sem rotina e regras de sentimento
continuam sujeitos à reconciliação de fontes/decisão, sem ampliar permissões.
O respiro do alerta da chamada foi implementado e provado na execução focal R12-07. Os demais requisitos acima continuam futuros e não devem ser apresentados como recursos já disponíveis.
