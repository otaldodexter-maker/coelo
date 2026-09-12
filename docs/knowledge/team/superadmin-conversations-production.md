---
title: "Conversas produtivas do Superadmin"
knowledge_id: superadmin-conversations-production
source: specs/028-superadmin-conversations-production.md
status: validated
generated_at: 2026-08-11
updated_at: 2026-09-12
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

A opção Chat de `Coelo (Principal)` dentro do Superadmin usa UI própria com
retorno contextual, conforme a revisão aprovada na spec 050 e refletida na
spec 028. Compartilha o `ChatRepository` de Comunicação > Conversas sem importar
widgets `SuperadminChat*`. Não cria domínio, cache ou backend paralelo nem depende dos
aplicativos `apps/principal`, `apps/admin` ou `apps/site`. No `/dev`, as duas
entradas compartilham a mesma instância determinística da sessão; em produção,
as duas usam o mesmo adapter RPC autorizado.

O launcher é fixo na safe area, anuncia a contagem real de não lidas e abre o
estado compacto apenas com conteúdo autorizado. Em larguras reduzidas usa um
círculo; em larguras maiores, uma cápsula laranja estável. Não há arraste livre
nem expansão que mude o layout do composer.

Eventos em tempo real são apenas sinais mínimos em canal privado; cada evento
faz refetch autorizado. Anexos usam R2 privado, com metadados e autorização no
Supabase. Sem Media Gateway validado, upload e download permanecem
indisponíveis de modo seguro. Stream não é requisito do Chat no MVP.

A visualização de imagem parte de ação explícita e `assetId` canônico, nunca
do ID do binding ou de URL legada. `MediaReader` pede acesso temporário;
`MediaSession` delimita o contexto e descarta resultados de sessões invalidadas.
Retry reautoriza, sem polling. Eviction Flutter não revoga acesso no servidor
nem comprova limpeza HTTP; a existência desses contratos não habilita por si
o transporte real de produção.
