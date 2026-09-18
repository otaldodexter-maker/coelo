---
title: "CHILD-READSTATE01 — invalidação local de leitura"
source: "autorização delimitada da coordenação em 2026-09-08; CHILD-READADAPTER01"
status: "approved-local-state-only"
generated_at: "2026-09-08"
---

# Recorte e sequência

Controller sem UI para uma página/cursor de leitura. Sessão disponível é gate
de render/transporte, nunca autorização. Contexto explícito por instituição
nullable, revision e função de leitura. Mudar qualquer um invalida página e
cursor; reload começa do início. Próxima página só sob estado atual ready e
cursor retornado. Não acumular dados nem fazer retry/fetch automático.

TDD: ausência de sessão, primeira/próxima página, dupla chamada, invalidação
durante espera, erro tardio, reentrância de listeners e dispose. Preparar tipo
seguro e estado loading/ready/empty/denied/unavailable. Negativa ou falha não
preserva dados anteriores. Uma geração por operação impede conclusão obsoleta.

Fora: widget/rota/DI/SQL, filtro de busca, novas capabilities, hierarquia,
comandos e E2E. Critério de parada: testes/analyzer/revisão e commit nominal.
Estimativa30–45min; entregar ponto seguro no checkpoint03:20.
