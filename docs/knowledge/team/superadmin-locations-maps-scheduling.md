---
title: Locais, mapas e agendamentos no Superadmin
knowledge_id: superadmin-locations-maps-scheduling
source: docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md
status: validated
generated_at: 2026-09-02
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
opcionais e usam Supabase Storage privado. O desenho não depende de mapa
cartográfico ou geocodificação.

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
O desenho está aprovado, mas sua implementação ainda não foi iniciada.
