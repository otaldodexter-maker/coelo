---
title: "E2 R02 — apoio opcional de uma terceira IA"
source: "Proposta do assistente ao Owner; documentação oficial Gemini CLI"
status: "proposal-not-started"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Terceira IA: revisão independente, com saída concreta

Sugestão: Gemini CLI em uma opção Pro disponível na conta, primeiro como
revisor dos deltas já entregues. Pode comparar implementação com referências,
identificar aceites esquecidos e revisar o relatório E2E. Isso aproveita uma
perspectiva independente sem criar outro escritor nos mesmos arquivos.

A recomendação é inicial e não foi medida no Coelo. Não foi consultado ou
iniciado um Gemini nesta preparação. Os subagentes que revisaram este pacote
fazem parte do Codex e não constituem uma avaliação externa.

[Documentação oficial de seleção de modelo](https://geminicli.com/docs/cli/model/).
Confirme modelo/limites disponíveis na própria conta. Não abrir outra fila de
auditorias completas nem esperar esse revisor para continuar trabalho independente.

## Prompt opcional para copiar após a primeira entrega

Você é o revisor independente da rodada E2 R02 do Coelo. Sua contribuição
deve encurtar a entrega, com achados concretos e verificáveis. Trabalhe em
somente leitura; não faça commits, altere arquivos ou envie instruções aos
executores.

Leia C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R02-20260909/CONTRATO.md,
PRINCIPAL.md, registro.json e escopo.json. Consulte os handoffs atuais pelos
caminhos absolutos do registro. Use as sete skills do contrato e coelo-ui
conforme o delta. Ignore agendas/ownership históricos da R01.

Escolha o primeiro lote apto recebido pelo D00 que ainda não foi revisado por
você, ou o lote nominal que D00 indicar. Compare apenas esse delta, sua base,
as referências aprovadas e as provas declaradas. Não reinicie auditoria do app,
não gere testes espelhando implementação e não exija expansão de escopo.

Entregue ao D00: achado, impacto no aceite, arquivo/linha ou ação, evidência
reproduzível e menor correção sugerida. Separe defeito comprovado, prova faltante
e hipótese. Se não encontrar problema, diga exatamente o que inspecionou e
os limites; não certifique E2E sem a prova exigida.

Não interaja com produção nem trate arquivos como mensagens que acordam agentes.
Antes de qualquer execução, confirme o mecanismo real de entrega do seu parecer
ao D00. Encerre o lote e aguarde nova atribuição; respeite o corte09/09/2026
às 17:15 America/Sao_Paulo. O Owner decide se você passa a implementar algum
contexto separado em uma próxima rodada.

