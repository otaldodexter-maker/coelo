---
title: "E2E5 — contexto e continuações do formulário de Agenda"
source: "agenda_event_form_page.dart; testes de Agenda; review agenda_ui_contract"
status: "correção local verificada; integração real pendente"
generated_at: "2026-09-07"
---

# Contrato da fatia

Objetivo: descartar campos e operações UI do contexto anterior ao trocar store,
evento ou disponibilidade/capacidade no formulário. Inclui formulário, helper
feature-local de conflito e testes. Não muda router, capacidade server-side,
reservas/Locais, SQL, protocolo de persistência nem publicação real. Ordem:
RED → reset completo → guards por await → regressão/review. Critério de parada
local: campos B e operações sem efeitos tardios de A; não é conclusão E2E.
Tempo observado: aproximadamente 10 minutos.

## Evidência

- Dois RED reais: mudar eventId não carregava Ballet; trocar store após edição
  mantinha campos/etapa antigos em vez de Evento B.
- Wrapper público preserva API e delega a corpo stateful com chave por identidade
  do store, eventId, canPublish e actionsAvailable. Todos os controllers, perguntas,
  contadores locais, etapa e feedback reiniciam juntos.
- Save é single-flight, captura store/capacidade/escopo e verifica descarte após
  cada await: save, override, ocorrência e solicitação de publicação. Exception
  é feedback genérico, sem imprimir detalhe interno.
- Diálogo de conflito é rota capturada; dispose remove somente essa rota.
  Teste com outra rota sentinela sobreposta comprova que a sentinela permanece e
  que retornar dela não revela o diálogo antigo.
- Review detectou regressão intermediária de tema ao substituir showDialog:
  RED dark→light reproduzido. A fábrica agora captura InheritedTheme, respeita
  barrierColor local e mantém traversal fechado; fallback usa scrim semântico.
- Três testes de await provam a etapa realmente iniciada, comando duplicado
  suprimido e nenhuma continuação/callback após troca para B.

## Verificação e limites

- Sete casos novos no formulário, total19. Regressão form/detail/management/router:
  **35/35 PASS**. Depois, sentinela acrescentada ao teste de conflito: **1/1 PASS**.
- Analyzer dos três arquivos: sem issues. Visual validator: exit0. Nenhum master
  visual alterado. Guards produtivos continuam fechados quando indisponíveis.
- Testes utilizam protótipo/repository fake: não comprovam BD, persistência,
  reload real ou auditoria remota. Resultados parciais do protocolo de múltiplas
  mutações não foram redesenhados nesta fatia.
- Gate de memória: no-op, invariantes de isolamento já aprovadas; nenhuma nova
  regra de produto. Rastreadores centrais permanecem sob writer Coordenador.
