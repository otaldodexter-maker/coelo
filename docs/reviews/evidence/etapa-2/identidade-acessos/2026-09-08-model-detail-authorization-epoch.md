---
title: "Modelos — continuidade da autorização na leitura composta"
source: "reserva nominal do Coordenador; adapter e composição normal Superadmin"
status: "local-green; e2e-pending"
generated_at: "2026-09-08"
---

# Recorte

Somente `AccessProfileModelRepositoryAdapter.fetchDetail`, teste e um hunk de
injeção no router. A composição normal fornece a revisão autoritativa da
sessão. O adapter captura essa revisão, verifica após cada await e só grava o
snapshot auxiliar depois de modelo e catálogo válidos no mesmo contexto.
Consumidores sem callback preservam compatibilidade. Writes permanecem intactos.

## RED e GREEN

Teste unitário usa `SuperadminSession` real e source sintético; autorização da
resposta é capturada antes dos gates, sem alegar HTTP/backend real:

- Modelo capturado em A, troca para B antes da entrega: não pode consultar
  catálogo B nem devolver modelo A.
- Catálogo capturado em A, troca antes da entrega: não pode devolver A.
- Contexto equivalente: revisão invariável e detalhe permitido.

Antes do patch: 1 PASS / 2 FAIL, ambos os negativos devolviam AccessProfile.
Depois: 3/3 PASS, incluindo ausência da segunda chamada após invalidação na
primeira. Junto aos cinco testes legados do adapter: 8/8 PASS. Regressão
funcional conjunta com detalhe: 161/161 PASS; novo assert focal repetido 3/3.
Analyzer adapter/router/teste: PASS. Review realm_audit: sem bloqueantes,
um hunk no router e writes intactos. Format/diff check PASS.

## Limites

`_details` não é cache de leitura: é snapshot auxiliar usado por save. O patch
impede gravação parcial desta leitura, não limpa snapshots anteriores nem muda
writes. Multipágina, fetchTemplate, redução de contexto em telas já carregadas
e contrato do catálogo para ator domain-only continuam abertos. Não há fallback
de permissões vazias, grant novo ou ampliação de capacidades.

Sem SQL, produção, deploy ou mídia. Não comprova verified-e2e. Memória: restaura
contrato existente, sem decisão nova. Handoff ao Coordenador mantém rastreadores
sob autoria exclusiva dele e preserva hunks Media/Session da E2E 3.
