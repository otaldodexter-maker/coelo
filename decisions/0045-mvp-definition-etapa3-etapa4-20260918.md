---
title: "Definição do MVP e corte entre Etapa 3 e Etapa 4 (18/09/2026)"
source: "Owner em 2026-09-18 (conversa com a coordenadora: D1–D9 e as sete definições do corte); docs/reviews/etapa-2-operacao/next-round/MVP-definicao-etapa3-etapa4-20260918.md; R16-levantamento-fechamento-mvp-20260918.md; decisions/0035, 0039, 0041, 0044; docs/product/prd-master.md §12–14"
status: "accepted"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
lifecycle: "current"
supersedes: "decisions/0035 (somente a alocação de tour, home com IA, admin/app.coelo.me e deploy entre etapas; o conteúdo da ADR 0035 continua válido); decisions/0044 §Etapa 3 (a lista de transferências passa a ser lida com este corte)"
audience: "team"
---

# ADR 0045 — Definição do MVP e corte Etapa 3 × Etapa 4

Em 18/09/2026 o Owner declarou a **Etapa 2 fechada** (FE 199/199, BE 186/186,
E2E 186/186; ADR 0044) e passou o foco para o **MVP inteiro**. Como o que falta
não cabe numa etapa só, o Owner dividiu o restante entre a **Etapa 3** (já prevista
na ADR 0035) e uma **Etapa 4** nova. Este documento é a fonte canônica dessa
divisão e da definição do MVP. Não certifica implementação.

## 1. O que é o MVP (definição vigente)

O MVP do Coelo é o conjunto abaixo, provado em produção. Fecha quando as Etapas 3
e 4 terminarem.

| Frente | Estado em 18/09 | Fecha em |
|---|---|---|
| Backend Supabase (schema, RLS, RPCs, Edges, R2) | entregue (lotes 1–83) | — |
| Superadmin web com a operação da instituição (escopo por tenant) | entregue na Etapa 2; correções pela revisão de telas | Etapa 3 |
| Principal hospedado no Superadmin | entregue na Etapa 2 | Etapa 3 (correções) |
| Tour do menu e do cabeçalho | em execução (Sessão TOUR) | Etapa 3 |
| Acesso contextual de funcionários (horários, dias, vigência, afastamentos, popups) | não iniciado | Etapa 3 |
| Specs 065, 066, 067, 068, 069 | aprovadas, não implementadas | Etapa 3 |
| Publicação: host, allowlist de Auth, CORS dos buckets, SMTP e prova do reset | não existe | Etapa 4 |
| `apps/admin` em admin.coelo.me | não existe | Etapa 4 |
| `apps/principal` em app.coelo.me (spec 064) | não existe | Etapa 4 |
| Push e app instalado | não existe | Etapa 4 (preparar); lojas na V1 |
| Home com IA | placeholder | Etapa 4 (reavaliar → V1) |
| Eventos de analytics gravados | tabela preparada | Etapa 4 |

## 2. Critério do corte

- **Etapa 3 = correções e o que o Owner já pediu**: revisão tela a tela do
  Superadmin (com a reserva R16), tour, acesso contextual de funcionários e as
  specs aprovadas. Sem publicação, sem app novo, sem dependência externa.
- **Etapa 4 = publicar e criar superfícies**: host e SMTP, `apps/admin`,
  `apps/principal`, preparação de push e app instalado, IA, analytics.

O Owner escolheu esse critério para que a Etapa 3 absorva o volume de correções
que a revisão de telas vai gerar.

## 3. Decisões do Owner (18/09/2026)

| # | Decisão |
|---|---|
| E1 | Etapa 2 fechada; foco no MVP inteiro; restante dividido em Etapa 3 e Etapa 4. |
| E2 | Critério do corte conforme §2. |
| E3 | `apps/admin` e `apps/principal` como apps próprios ficam na **Etapa 4**; no piloto da Etapa 3 o Superadmin com escopo por tenant faz o papel de Admin e o Principal segue hospedado. |
| E4 | Home com IA vai para a **Etapa 4**; ao abrir a Etapa 4, reavaliar se vai para a V1. |
| E5 | Push e app instalado: deixar **tudo preparado na Etapa 4**; publicação nas lojas só na **V1**. |
| E6 | Specs **064 e 068 aprovadas**. 068 (perfis oficiais) na Etapa 3; 064 (perfil transversal e Principal para responsável sem membership) na Etapa 4, junto do app próprio. |
| E7 | Publicação (host de `superadmin.coelo.me`, Auth, CORS dos buckets, SMTP, prova do reset) vai para a **Etapa 4**. |
| E8 | Nome **"Para você"** mantido por ora; as três instituições fictícias ficam para o **fim da Etapa 3**, quando a coordenação propõe dez alternativas de nome. |
| E9 | **Importação/exportação** e **MFA** de internos: **V1**; encerra o conflito PRD × ADR 0031/0044. |
| E10 | Tour funcional executado agora, isolado, no conceito "orientar o usuário sobre o que cada coisa faz" (menu e cabeçalho primeiro; tour por tela depois). |
| E11 | Decisões operacionais do mesmo dia (executadas pela Sessão RESERVA): D2 prova de Histórico/snapshot/sino; D4 massa sintética `QA R15`; D5 Celular em E.164 `+55DDD9NNNNNNNN` no servidor e máscara `+55 (DD) 9NNNN-NNNN` na tela; D6 `can_remove` do Agora segue a RPC; D7 21 testes funcionais corrigidos, goldens na Etapa 3; "Publicar lançamento" fica no Histórico (spec 052 §3); lotes 82 e 83 autorizados nominalmente. |

## 4. Conteúdo da Etapa 3

1. **Revisão tela a tela** do Superadmin pelo Owner (bloco de notas → correções
   com tela, destino e ID existente). Inclui a reserva R16: Owner items
   r12-10, 18, 19*, 23*, 29, 30, 46 (layout A+), 53; H02, H03, H04, H07, H09,
   H10, H12, H14, H16, H26 e os H "R16" ainda abertos (H18–H28, H08/H13/H23);
   dívidas `momentos-ux`, `orfaos-cardapio`, `form-diario`, `forms-v2-qa`,
   `espelho-cli`, `h02-aal2`, `oq048-membership`, `activity-msg`, Local interno
   (ADR 0038), goldens (componentizar o cabeçalho).
   *r12-19/23 dependem da spec 064 → o que for só Superadmin fica; o resto vai
   com a 064 para a Etapa 4.
2. **Tour** do menu e do cabeçalho (em execução) e, depois, tour por tela.
3. **Acesso contextual de funcionários** (ADR 0035): spec própria, duas telas,
   restrição no servidor, popups, auditoria. As seis decisões de desenho da ADR
   0035 são tomadas na spec.
4. **Specs 065, 066, 067, 068, 069** implementadas com pgTAP, FE e rota real.
5. **Fechamento**: dez propostas de nome para "Para você" e as três instituições
   fictícias.

## 5. Conteúdo da Etapa 4

1. Publicação: host, allowlist de Auth, CORS dos buckets R2 com a origem
   pública, SMTP próprio, prova detalhada do reset (E8/E10 da ADR 0042).
2. `apps/admin` em admin.coelo.me com adaptação de papel.
3. `apps/principal` em app.coelo.me, com a spec 064.
4. Preparação de push e do app instalado (sem lojas).
5. Eventos de analytics.
6. Home com IA (reavaliar → V1 na abertura).

## 6. Fora do MVP (V1 e além)

Importação/exportação (exceto Formulários), MFA, lojas, Planos comerciais,
Financeiro, Catálogo de UI, dashboard visual, site/SEO, comentários,
impersonation, matrícula, ERP, gamificação, white label, H11 autosave.

## 7. Regra de trabalho da Etapa 3 (Owner, 18/09/2026)

O Owner constatou que o projeto anda devagar por excesso de processo, não por
tamanho. Na Etapa 3 vale o seguinte:

1. Uma lista só: o bloco de notas da revisão de telas é a fila. Sem inventário,
   Owner item, delta de rastreador ou arquivo de evidência por item; prova é o
   commit, os testes e o olhar do Owner na tela.
2. Zero rodadas novas: nada de R17, checkpoint ou mesa. A lista vai até acabar.
3. UI/UX é decidida pela sessão; o Owner corrige depois. O Owner só entra em
   regra de negócio e segurança.
4. Prova por teste: widget test e pgTAP certificam; navegador só na aceitação
   do Owner.
5. Rito de produção completo só para migration que muda RPC, RLS ou contrato.
   Fixture, dado de QA e projeção vão em lote leve com pgTAP.
6. Sessões por módulo, sem coordenadora fixa; integração em `dev` uma vez por
   dia.
7. Documentação congelada: skills, `current-state.md`, índices e trackers só
   são atualizados no fechamento da etapa.
8. Os invariantes de segurança (AGENTS.md) não mudam.

## 8. Consequências

- A ADR 0035 continua a fonte do conteúdo do acesso contextual, tour, IA e apps;
  esta ADR só redistribui entre Etapa 3 e Etapa 4.
- A proposta consolidada exigida pela ADR 0035 (escopo, ordem, dependências,
  aceites, estimativa) é escrita para a Etapa 3 a partir do §4, após a revisão
  de telas.
- `current-state.md`, `backlog.md`, `R16-pendencias.md`, `specs/README.md`
  (064 e 068 → `approved-for-implementation`) e as skills passam a citar esta ADR.
- A R16 continua vigente como fila da reserva até a abertura formal da Etapa 3.
