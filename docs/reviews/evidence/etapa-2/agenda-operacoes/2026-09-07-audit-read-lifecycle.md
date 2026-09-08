---
title: Auditoria — busca, paginação e invalidação de leituras
source: Seis RED locais; revisão independente do controller
status: Pacote cliente local verificado; sem promoção E2E
generated: 2026-09-07
---

Cinco testes novos reproduziram antes da correção: segunda busca após conclusão
causava Future already completed; negativa de detalhe preservava lista sensível;
negativa da lista permitia detalhe tardio; negativa do detalhe permitia página
tardia; controller disposed ainda iniciava requests.

A revisão identificou um sexto RED: next durante debounce combinava busca B com
cursor de A e produzia duas consultas/página errada. Busca passa imediatamente a
loading e limpa página corrente. Cancelamento/conclusão de debounce é idempotente
e limpa o completer apenas se ainda pertence àquela busca.

Negativa corrente invalida as duas gerações, debounce, cursores e conteúdo. O
painel de detalhe fica unauthorized somente quando havia detalhe aberto/pendente;
o estado idle permanece fechado. A primeira regressão ampla detectou abertura
indevida desse painel na negativa inicial da lista, corrigida antes do pacote.

Oito testes novos, incluindo recuperação por retry explícito e negativa obsoleta
que não apaga leitura mais recente. Regressores finais42/42 PASS em controller,
adapter, página e widgets. Analyzer dos dois Dart e diff check PASS. Review
independente final sem blocker. Nenhuma imagem de referência ou UI estrutural
alterada; suite de goldens históricos divergentes não foi incluída nessa seleção.

Exportações continuam informativas na UI conforme pacote anterior; código legado
de exportação não foi expandido ou ativado. Sem SQL, RPC real, deploy, mudança de
permissões, backend ou shared. A prova cliente não substitui sessão/tenant/audit
real. Skills Coelo integrada e TDD/revisão orientaram negativas concorrentes e
retry explícito. Gate de conhecimento sem projeção: invariantes existentes.
