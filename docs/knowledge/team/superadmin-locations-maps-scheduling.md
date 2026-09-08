---
title: Locais, mapas e agendamentos no Superadmin
knowledge_id: superadmin-locations-maps-scheduling
source: docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md
status: validated
generated_at: 2026-09-02
updated_at: 2026-09-07
audience: team
surfaces: [superadmin, institutions, units, groups, activities, agenda, forms]
visibility: internal
review_owner: Coelo Product
---

# Locais, mapas e agendamentos no Superadmin

Instituições e unidades mantêm catálogos independentes de locais. Ao repassar um
local institucional para uma unidade, o sistema cria uma cópia independente e
auditável; edições posteriores não são sincronizadas.

Locais podem ser internos ou externos. Endereço é obrigatório somente para o
externo; nome, andar e complementos são livres dentro dos limites server-side.
Cada local define visibilidade para equipe, responsáveis, alunos ou todos os
públicos autenticados do contexto.

A seção Mapa e locais está sempre disponível no cadastro de instituição e
unidade. Imagem/planta geral, marcadores clicáveis e foto por local são
opcionais e usam Cloudflare R2 privado pelo Media Gateway; Postgres/Supabase
mantém metadados, autorização e auditoria. O desenho não depende de mapa
cartográfico ou geocodificação. O domínio R2 canônico é `locations`: mapa geral
usa a finalidade `map-general` e foto do local usa `photo`, dentro da
hierarquia única da ADR 0032. O mapa aceita limite maior e variantes de zoom;
a foto do local segue o limite de foto comum.

Turmas, Atividades e Eventos aceitam local catalogado ou texto pontual. Um local
pontual pode ser salvo posteriormente no catálogo; somente locais catalogados
participam do mapa, dos vínculos reversos e da agenda. Turmas e Atividades podem
criar reservas recorrentes quando a opção de reserva estiver marcada.

A política de conflitos é configurada por instituição ou unidade: bloquear, ou
alertar e permitir confirmação por ator com capability específica, justificativa
e auditoria. Formulários podem usar pergunta Local interno, de escolha única ou
múltipla, mostrando apenas locais catalogados visíveis ao respondente.

`/dev` usa fixtures determinísticas separadas. Produção usa exclusivamente
repositories Supabase autorizados e nunca recorre a dados fake como fallback.
O desenho está aprovado. A fundação local de seleção está disponível em
`package:coelo_domain/locations.dart`; isso não implementa catálogo, UI, banco,
reservas ou mídia e não comprova E2E.

## Contrato de seleção para consumidores

Fonte complementar: `docs/superpowers/specs/2026-09-07-location-selection-contract-design.md`.

`LocationScope` identifica o proprietário do catálogo: instituição ou unidade
com ambos os IDs explícitos. `LocationReferenceSnapshot` preserva ID do local,
escopo, tipo e rótulo recebidos; é histórico, não prova de estado atual,
visibilidade ou autorização. O backend deve reautorizar cada uso.

`LocationSelection` separa referência catalogada de texto pontual. Ausência é
nullable no consumidor; salvar texto no catálogo continua uma ação explícita
separada. Versão do formulário e contexto do cadastro de origem permanecem no
consumidor. Não inferir interno/externo a partir de opções legadas que não
informem o tipo e não converter seleção pontual em reserva automaticamente.
