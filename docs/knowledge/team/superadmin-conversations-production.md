---
title: "Conversas produtivas do Superadmin"
knowledge_id: superadmin-conversations-production
source: specs/028-superadmin-conversations-production.md
status: validated
generated_at: 2026-08-11
audience: team
surfaces: [superadmin, conversations]
visibility: internal
review_owner: Coelo Product
---

# Conversas produtivas do Superadmin

Conversas não usa fixture nem autorização no cliente. A inbox, thread, envio,
recibos de leitura e refresh passam por RPCs que recalculam pessoa, membership,
capability e escopo efetivo. UUID, rota, cursor e filtro são sempre não
confiáveis.

A opção Chat de `Coelo (Principal)` dentro do Superadmin é somente uma segunda
entrada para a mesma página e o mesmo `ChatRepository` de Comunicação >
Conversas. Ela não cria domínio, cache ou backend paralelo e não depende dos
aplicativos `apps/principal`, `apps/admin` ou `apps/site`. No `/dev`, as duas
entradas compartilham a mesma instância determinística da sessão; em produção,
as duas usam o mesmo adapter RPC autorizado.

O launcher é fixo na safe area, anuncia a contagem real de não lidas e abre o
estado compacto apenas com conteúdo autorizado. Em larguras reduzidas usa um
círculo; em larguras maiores, uma cápsula laranja estável. Não há arraste livre
nem expansão que mude o layout do composer.

Eventos em tempo real são apenas sinais mínimos em canal privado; cada evento
faz refetch autorizado. Mídia usa metadados no banco e gateway R2 privado. Sem
gateway R2 validado, upload e download permanecem indisponíveis de modo seguro.
