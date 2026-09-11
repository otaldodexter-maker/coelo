---
title: "Rodada 4 — perguntas ao Owner (noite de 10→11/09/2026)"
source: "coordenacao.json R04; JSONs das frentes; producao medida por supabase db query --linked (somente leitura)"
status: "open"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Perguntas ao Owner — Rodada 4

Numeração continua a da R03 (P1–P21). Cada pergunta traz o que já existe, as
opções e a recomendação do coordenador. Responder em lista "Pxx - decisão,
observação" basta.

## P22 — Ponte entre o realm interno e o realm de pessoas (bloqueia rota normal de 9 famílias)

**Medido em produção às 22:20:** `person_auth_links` tem 0 linhas. Os quatro
usuários do Superadmin (os seus três e o `qa-r03@coelo.me`) existem só no realm
interno v2 (`app_private.superadmin_internal_auth_links`). O shell do
Superadmin autentica por esse realm, mas as RPCs de Unidades, Rotina,
Assiduidade, Perfis de cuidado, Medicação, Cardápios, Suporte, Conta, Pessoas,
Perfis/Modelos de acesso e Segurança infantil resolvem o ator por
`app_private.current_person_id()` + `has_platform_permission`, que leem
`person_auth_links` e `platform_memberships`. Consequência: **nenhum usuário,
nem você, alcança essas RPCs hoje**. Duas frentes (Operações e Acessos e
Pessoas) bateram no mesmo muro e eu assumi a dependência como pacote único do
coordenador.

**Bloqueio:** a escrita desse pacote foi recusada duas vezes pelo classificador
de permissões da minha sessão (ele trata mudança de identidade/autorização
como ação sensível). Não vou contornar. Preciso de uma de duas coisas:

- **Opção A (recomendada):** você cola na minha conversa "P22 aprovado, opção
  2" e libera a escrita (ou adiciona a regra de permissão sugerida pelo
  classificador). Eu escrevo, provo no espelho com pgTAP e aplico no lote
  seguinte.
- **Opção B:** você mesmo cria o arquivo com o conteúdo que eu passar e eu só
  aplico. Mais lento.

**Desenho (opção 2, sem tocar nos guards de realm):**

1. tabela `app_private.superadmin_internal_actor_people` ligando cada
   identidade interna a uma pessoa de serviço (`people.person_type='service'`,
   nome opaco "Equipe Coelo xxxxxxxx", sem e-mail);
2. `app_private.current_person_id()` cai nessa ligação quando não há vínculo
   `person_auth_links` (o vínculo people continua tendo precedência);
3. a pessoa de serviço recebe `platform_memberships` com o **mesmo papel e
   escopo** da membership interna ativa, mantida por trigger: membership
   interna revogada ou suspensa revoga a espelhada;
4. backfill das quatro identidades existentes; nenhuma RPC muda; os guards de
   realm (`person_auth_links` × `superadmin_internal_auth_links`) ficam
   intactos porque a ponte não cria `person_auth_links`.

**Desenho alternativo (opção 1, descartado):** relaxar o guard de realm e
criar `person_auth_links` para as identidades internas. Mais simples, mas
remove uma barreira de segurança deliberada.

**Efeito de não decidir:** as nove famílias acima ficam sem CRUD em produção
na régua do MVP nesta rodada; as frentes seguem no que usa
`require_superadmin_internal_context` (Convites, Usuários internos,
Segurança infantil leitura, Chat, Avisos, Circulares, Acontece, Agora,
Momentos, Formulários) e no cliente.

## P23 — Owner de instituição em Cardápios (principal-chat-sistema)

`has_platform_permission` só enxerga membership com `scope_kind='platform'` e
instituição nula. Um Owner **de instituição** nunca tem `meal_plans.manage`,
nem com a concessão nova. Para o MVP do Superadmin basta; quando Admin entrar,
nenhum administrador de instituição gerenciará cardápios. O pacote P7 do grupo
acessos-pessoas (membership por instituição em `has_platform_permission`)
resolve isso se você confirmar que é a regra pretendida: **quem tem a
capacidade no perfil de instituição gerencia os cardápios dessa instituição.**
Recomendação: sim (é a sua Decisão 12/P7 aplicada a Cardápios).

## P24 — Criar grupo no Chat: quem pode criar e quem entra (realm-interno)

O pacote `20260910240400` (Criar grupo, P8) está pronto com a regra: quem tem
`chat.internal.manage` cria grupo; membros são identidades internas ativas
(conversa interna do Superadmin), com auditoria. Confirmar que no MVP o grupo
é **só entre identidades internas** (equipe Coelo) e que grupos com famílias
ou instituições ficam para o chat contextual (realm de pessoas), fora desta
rodada. Recomendação: sim.

## P25 — Instituição e unidade sintéticas em produção (bloqueia CRUD com sessão de 5 famílias)

Produção não tem nenhuma instituição ativa (a única linha é a sintética do
grupo realm-interno, já arquivada). Circulares, Agenda, Chat contextual,
Formulários, Cuidado e Alunos exigem contexto institucional para criar
qualquer coisa; a frente Publicações pediu uma instituição de teste para
rodar Circulares e Agenda na sessão `qa-r03`.

O `insert` direto em produção foi recusado pelo classificador da minha sessão
(dado em produção), e pedir a outra conversa para fazê-lo também foi recusado.
Opções:

- **Opção A (recomendada):** você manda à conversa «R04 · Estrutura» criar
  pela rota normal, com a sessão `qa-r03`, a instituição
  "[R04-QA] Instituição de teste" e uma unidade "[R04-QA] Unidade de teste",
  e publicar os ids no `estrutura.json`. É exatamente o `institutions.create`
  e `units.create` da régua do MVP, e serve às outras frentes.
- **Opção B:** você libera o `insert` sintético na minha conversa ("P25
  aprovado, opção B") e eu crio os dois registros com ids fixos
  (`9f040000-0000-4000-8000-0000000000a1` e `...a2`), removidos ao fim.

## Registro

- Respostas entram em `coordenacao.json` (revisão seguinte), na ADR 0034
  (Decisão 13) e nas skills afetadas no mesmo turno.
