---
title: "Momentos — troca de contexto e retornos tardios"
source: "diagnóstico/review independente; page/route/controller locais; testes Flutter"
status: "local-green; not-e2e"
generated_at: "2026-09-07"
---

# Causa e resultado

A rota recriava seu controller ao trocar repository/contexto, mas a página
mantinha `late final` inicializado somente em initState. Isso conservava o
rascunho anterior e impedia carregar B. Uma publicação externa ainda em voo
podia acionar callbacks da página nova.

A página agora troca listeners/controller em didUpdateWidget, limpa legenda,
etapa e seleção, e descarta somente controllers que ela própria criou no demo.
Load/save/publish/retry conferem identidade e geração antes de qualquer efeito
de UI tardio. Não houve mudança no arquivo da rota, shell, gateway ou backend.

## Evidência

- RED: B teve 0 loads em vez de 1; load A deixava spinner antigo; publicação
  tardia acionava 2 callbacks indevidos na página substituta.
- GREEN página 35/35, com cinco casos novos: troca A/B, load tardio,
  publish tardio, demo → controller fornecido e save tardio.
- GREEN ampliado **86/86**: testes não-golden principal_moments e
  principal_moments_publication + teste da rota real de desenvolvimento.
- GREEN golden publisher **14/14**, claro/escuro, 375/768/1024/1440,
  texto 200%, hover, mídia persistida sintética, vazio e falha.
- Analyzer dois arquivos sem apontamentos; formatter e validador visual exit 0.
- Review independente review_media_session: sem achado acionável no recorte.

Nenhuma referência PNG alterada, nenhum segredo ou recurso remoto acessado.
As fixtures não provam tenant/RLS/R2/Stream produtivos; nenhum action_id vira
verified-e2e. Próximos gates: gateway real, persistência e revogação reais.
Memória no-op: preservação de isolamento já obrigatório, sem política nova.
