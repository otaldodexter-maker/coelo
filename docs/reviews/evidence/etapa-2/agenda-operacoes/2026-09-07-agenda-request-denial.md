---
title: "Agenda — prioridade de negação nas duas leituras de solicitações"
source: "apps/superadmin/lib/features/agenda/data/supabase_agenda_repository.dart"
status: "local-partial; sem promoção E2E"
generated_at: "2026-09-07"
---

# Solicitações e Aprovações — fatia local

Quatro REDs iniciais: negação ficava aguardando sibling pendente ou era ocultada
por erro PostgREST anterior. Review encontrou transporte como segundo caminho;
mais dois REDs confirmaram estado loading/cache preservado após ClientException.

As duas leituras agora capturam Exception não autorizativa como resultado;
negação de autorização encerra imediatamente e aciona invalidação existente.
Sem negação, erro é propagado ao tratamento controlado de leitura. O catch
genérico vem após PostgREST/FormatException; Error de programação não é capturado.
Coleções continuam aplicadas atomicamente, sob guards de geração/dispose/epoch.

53/53 testes repository passaram, incluindo seis cenários de ordenação e falha
de rede isolada; 26/26 testes de páginas Solicitações/Aprovações e estados HTTP
passaram após o fix final. Analyzer focado limpo. Review independente final sem achados.
Nenhuma UI, regra de produto, RPC/SQL ou backend remoto alterado. Memória no-op.
HTTP é simulado: não comprova persistência, autorização real ou E2E.
