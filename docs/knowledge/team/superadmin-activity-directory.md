---
title: Diretório de atividades do Superadmin
knowledge_id: superadmin-activity-directory
source: docs/superpowers/specs/2026-07-29-superadmin-activity-inspection-design.md
status: validated
generated_at: 2026-08-11
audience: team
surfaces: [superadmin, activities]
visibility: internal
review_owner: Coelo Product
---

# Diretório de atividades do Superadmin

O Superadmin consulta atividades em `/activities` e seus detalhes em
`/activities/:activityId`. O diretório, detalhe, criação, edição, vínculos,
importação e exportação são produtivos quando o ator possui a capability de
plataforma correspondente. A UI não concede acesso: RPCs e RLS recalculam
identidade, capability, MFA e escopo hierárquico em cada requisição.

A entidade canônica é `activity_definitions`, vinculada obrigatoriamente a uma
instituição e, quando a origem é `unit`, a uma unidade de origem. O diretório
oferece cards e tabela, busca por nome ou descrição e filtros multi-select de
instituição, status e origem. Cards iniciam com 11 itens e tabela com 8; ambos
oferecem também 20, 50 e 100 itens por página.

Os status confirmados são `draft`, `active`, `inactive`, `suspended` e
`archived`. A origem é `institution` ou `unit`; a distribuição é
`institution_standard` ou `unit_local`; a governança é `optional`,
`mandatory` ou `fixed`. Não há contrato para tipo, agenda, recorrência,
duração, anexos, publicação, cancelamento ou conclusão nessa superfície.

O detalhe mostra identidade, governança, unidades e grupos vinculados.
Profissionais e participantes são retornados somente dentro do escopo
hierárquico autorizado. Consultas usam a sessão autenticada e as policies RLS
existentes, sem segredo privilegiado no cliente e sem autorização inferida de
metadata. Owner recebe todas as capabilities de Atividades; Operations recebe
gestão de taxonomia; os demais usuários dependem do perfil de acesso.

Busca, leitura e comandos são sempre limitados no backend ao escopo autorizado.
O handle da Atividade é privado, global e editável, com aliases históricos. A
identidade aceita foto no Supabase Storage privado, sigla com cor ou ícone
Material allowlisted; não herda a identidade visual da instituição. Mídias de
Now, Happens e Moments permanecem no R2.

O CTA `Criar atividade` permanece disponível, conforme
`activities.create`, nos estados com dados, vazio, sem resultados e falha
recuperável. Ele não aparece no estado sem autorização. Estados loading, vazio,
sem resultados, falha, sem permissão e não encontrado refletem o backend e
nunca usam fixtures, repovoamento artificial ou sucesso sintético.

Categorias, subtipos e modelos vêm de catálogo versionado. Há 40 modelos
iniciais aprovados, incluindo Natação, Futebol, Futsal, Matemática e Física,
distribuídos por categorias filtráveis coerentes. Começar a partir de um modelo ocorre em uma única mutação
idempotente: o servidor aplica defaults, mescla overrides, persiste a origem e
audita. Duplicar modelo é outro comando e cria uma cópia institucional; não
cria uma Atividade.
