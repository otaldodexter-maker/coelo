---
source: Owner e anexo de Conversas na conversa de 2026-09-13; docs/design/chat-media-composer-owner-reference-20260913.md
status: backlog R12; sem implementação
generated_at: 2026-09-13
---

# R12-43 — Contorno do contêiner de Conversas

Host apps/superadmin > Comunicação > Conversas > lista/conversa aberta;
action_id chat.open. Anexo visto na conversa, binário não exportado ao repositório.
Owner aponta contêiner sem linha de contorno. Inspecionar continuidade das bordas
entre lista de conversas, paginação, painel da conversa e compositor, incluindo
cantos e divisórias, sem presumir que toda bolha de mensagem deva receber borda.
Aplicar tokens de contorno e geometria da composição aprovada de chat. Reproduzir
em desktop/compacto, light/dark, vazios e scroll antes de diagnosticar clipping,
recorte ou ausência de border. Não criar contêineres redundantes para mascarar falha.

Direção de acabamento soma-se à referência de mídia/compositor já preservada;
não substitui o pedido de fotos/vídeos inline. FE pendente R12; BE sem mudança
prevista para o contorno; E2E sem nova prova. Não alterar certificações históricas.
Responsável C0 R12. Registro apenas, fora da R11; sem código/runtime/deploy.

Integrador central deve incorporar owner.r12-43 e nota por camada de chat.open
via apply-tracker-delta.cjs, rebaseando as notas vigentes e preservando certificado.
Atualização dos três rastreadores ainda pendente, pois R11 mantém escritor central.

## Destino das pendências R11 — decisão Owner 2026-09-13

As pendências remanescentes foram transferidas para [R12-pendencias-herdadas-R11.md](R12-pendencias-herdadas-R11.md), itens R12-46 a53, com responsável C0 R12, estados e primeiro gate preservados. R11 permanece encerrada parcialmente; esta atualização não inicia R12, não aplica SQL e não altera percentuais. O compositor de chat R12-52 deve ser coordenado com o contorno R12-43.

## Resultado da execução focal — 13/09/2026

R12-43: contorno entregue; mídia/compositor R12-52 continuam R13. Ver [fechamento](R12-fechamento.md), provas e limites de FE/BE/E2E. Nenhuma aprovação A do Owner ou certificação funcional inteira nova.
