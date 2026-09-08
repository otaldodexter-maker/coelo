---
title: "Para Você — projeção nas fronteiras de validade"
source: "rota e adapter existentes; testes Flutter; revisão independente crosswalk_media"
status: "local-green; not-e2e"
generated_at: "2026-09-07"
---

# Causa e correção

A elegibilidade era calculada somente ao carregar o repository. Um destaque
continuava visível depois de endsAt; resultados compostos só de itens inelegíveis
também não recebiam o estado vazio. A rota agora reprojeta o snapshot recebido
no próximo startsAt/endsAt de uma comunicação active não-popup. Não promove
status scheduled, não faz polling e não substitui autorização do servidor.

Reload, troca de repository/dados/relógio e dispose cancelam o timer. Respostas
e callbacks antigos conferem mounted e geração antes de alterar a UI. O estado
vazio considera elegibilidade e preserva os atalhos existentes.

## Evidências locais

- RED anterior: card vencido ainda visível; estado vazio ausente; início de
  validade não observado sem reabrir a rota.
- Cinco testes novos: expiração, início, timer A durante load B, resultado já
  vencido e dispose com timer armado. O último deixa o framework verificar
  ausência de timers pendentes, sem avançar o tempo para mascarar vazamento.
- Suite completa Para Você: **49/49**, incluindo 13 goldens existentes,
  responsividade, texto 200%, teclado/contexto e adapter. Nenhum PNG alterado.
- Analyzer dos dois arquivos sem apontamentos; formatter sem alterações;
  validador visual e git diff --check exit 0.
- Review read-only: nenhum bloqueante nominal; acrescentado teste de dispose
  solicitado. Cobertura de múltiplas fronteiras e saltos de relógio é melhoria
  residual; não representa sincronização temporal ou revogação em tempo real.
- Uma tentativa de teste usou getter inexistente pendingTimerCount; analyzer
  rejeitou, removido antes da execução final. Não houve falha de produção.

Limite: mudança abrupta de relógio não provoca atualização imediata; a projeção
ocorre no próximo timer/reload. Backend, revogação remota e fluxo produtivo
continuam abertos. Nenhum action_id promovido a verified-e2e, nenhum acesso
remoto ou mudança de regra de produto. Gate de memória: no-op.
