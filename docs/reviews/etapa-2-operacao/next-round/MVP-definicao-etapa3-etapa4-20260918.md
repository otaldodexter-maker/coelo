---
title: "Definição do MVP do Coelo — o que está entregue, o que falta, e a proposta de corte Etapa 3 × Etapa 4"
source: "docs/product/prd-master.md §12–14, §19–20; prd-superadmin.md §4; prd-admin.md §4; prd-app.md §5; decisions/0035, 0039, 0041, 0044; R16-levantamento-fechamento-mvp-20260918.md; docs/agent/backlog.md; apps/* (estado em 18/09)"
status: "decided; ver ADR 0045"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "owner"
---

# Definição do MVP — para o Owner cortar Etapa 3 × Etapa 4

> Objetivo: dizer **exatamente o que é o MVP** cruzando o que os PRDs prometem com
> o que existe em 18/09/2026, para o Owner decidir o que fica na Etapa 3 (ADR 0035)
> e o que vai para uma Etapa 4 nova. Nada aqui abre etapa nem muda estado; o
> resultado vira ADR 0045 depois da decisão.

## 1. O que os PRDs chamam de MVP

| Módulo (PRD Master §12/§19) | Promessa do MVP | Superfície |
|---|---|---|
| Login unificado | e-mail/celular, convites, pessoa única, contexto ativo; recuperação/reset na Etapa 3 | todas |
| Multi-tenant / RBAC | instituição › unidade › grupo › criança › responsável; RLS | backend |
| Superadmin | instituições (criar, editar, ativar, inativar, suspender), usuários internos, avisos, perfis oficiais Coelo, uso básico, auditoria, suporte com acesso; **Planos fora** | superadmin.coelo.me |
| Admin | unidades, grupos, atividades, pessoas, responsáveis, equipe, permissões, importação, conteúdo, chat, dados básicos | admin.coelo.me |
| App (Principal) | login/contexto, Happens, Now, Moments, diário de rotina, chat/canais, agenda, notificações, perfil/portal; **comentários fora** | app.coelo.me + iOS/Android |
| Feed/comunicados | privado, contextual, mídia, confirmação de leitura, reações simples | Admin + App |
| Stories/momentos | privado, com expiração | Admin + App |
| Chat completo | 1:1 contextual, canais, equipe, leitura, anexos, auditoria; sem responsável↔responsável | Admin + App |
| Agenda | eventos, lembretes, RSVP/autorização simples | Admin + App |
| Diário de rotina | templates e registro rápido | Admin + App |
| Notificações | central in-app desde o MVP; push com payload mínimo | App |
| Dados para dashboards | eventos e tabelas; **dashboard visual fora** | backend |
| Offline | offline-tolerant (cache, rascunho, fila curta); **offline-first fora** | App |

Fora do MVP pelos PRDs: dashboard visual, site/SEO completo, pagamentos, matrícula
digital, ERP, gamificação, white label forte, IA em produção crítica, comentários,
impersonation, Planos comerciais (ADR 0039), MFA (adiado, ADR 0044 E9),
importação/exportação geral (ADR 0031; só Formulários exporta).

## 2. O que existe em 18/09/2026

| Frente | Estado | Evidência |
|---|---|---|
| Backend Supabase (schema, RLS, RPCs, Edges, R2) | **entregue** para tudo que o Superadmin usa: 186/186 BE; lotes 1–81 em produção | inventário; ledger |
| Superadmin web (Flutter, 505 arquivos Dart, ~45 famílias de tela) | **entregue** na Etapa 2: 199/199 FE, 186/186 E2E provados em produção | `R16-checkpoint-20260917.md` |
| Principal (app familiar) | **hospedado dentro do Superadmin** (`/principal-now`, `-moments`, `-happens`, `-for-you`, `-profile`, `-conversations`) e provado por lá; `apps/principal` tem só READMEs | `apps/principal/lib` |
| Admin (painel da instituição) | **não existe** como app; `apps/admin` tem só READMEs. As operações de Admin (unidades, turmas, pessoas, atividades, rotina, agenda, avisos, circulares, chat, formulários, cardápios, cuidado, segurança, assiduidade, avaliações) hoje existem **no Superadmin**, com escopo por tenant | `apps/admin/lib` |
| Site público (Astro) | existe; fora do MVP pelo PRD | `apps/site` |
| Deploy público | **nenhum**: `superadmin.coelo.me` não existe; builds QA locais em 3014–3024; CORS R2 só local; sem SMTP próprio | `R16-pendencias.md` §operacional |
| Apps instalados (iOS/Android) | **nenhum**; sem push (nenhuma dependência FCM/OneSignal); ADR 0035 tira lojas do momento | `pubspec.yaml` |
| Notificações | central in-app (sino) entregue no Superadmin; **push não existe** | — |
| Offline-tolerant | pontos de cache/fila no Superadmin (12 arquivos); sem prova formal | — |
| Analytics events | tabela preparada (1 migration); sem consumo | — |
| Tour / home com IA | tour do menu (48 passos, 18/09) e tour por tela (42 telas, 265 passos) + tour completo (menu → telas, retoma após reload) entregues em `dev` em 19/09; home com IA segue placeholder | ADR 0035; `tour-telas-rascunho-20260918.md` |
| Reserva R16 | 14 Owner items, 19 H, 17 dívidas; D2/D4/D5/D6/D7 em execução pela Sessão RESERVA | `R16-levantamento-…` |

**Leitura:** o Superadmin cumpre o PRD do Superadmin **e** absorveu a operação
do Admin. Do MVP dos PRDs faltam, em ordem de tamanho: (1) as superfícies
Admin e App como apps próprios com papel adaptado; (2) publicação (host, Auth,
CORS, SMTP); (3) push e app instalado; (4) acesso contextual de funcionários,
tour e IA (ADR 0035); (5) specs 064–069; (6) a reserva R16 de UI/UX e dívida.

## 3. Inventário do que falta, com tamanho estimado

Tamanho: **P** até 1 dia de sessão; **M** 2–5 dias; **G** mais de uma semana ou
com dependência externa (domínio, provedor, loja, decisão de produto).

| # | Item | Origem | Tamanho | Depende de |
|---|---|---|---|---|
| F1 | Revisão de telas do Superadmin (correções UI/UX do bloco de notas do Owner) | Owner, 18/09 | M | nada |
| F2 | Reserva R16 "R16": H18–H28, H08/H13/H23 (spec 069), `momentos-ux`, `orfaos-cardapio`, `form-diario`, `forms-v2-qa`, `espelho-cli`, `h02-aal2`, `oq048-membership` | ADR 0044 | M | F1 (mesmas telas) |
| F3 | Reserva "Etapa 3": r12-10, H02/H03/H04/H07/H09/H10/H12/H14/H16/H26, Local interno ADR 0038, `activity-msg`, goldens (cabeçalho componentizado) | ADR 0044 | M | F1 |
| F4 | Specs aprovadas sem implementação: 065 Perfis de cuidado, 066 ciclo de vida + `institutions.status`, 067 Locais com mapa, 069 Avisos | ADR 0044 | G (4 specs, FE+BE+rota real) | nada |
| F5 | Specs em rascunho: 064 perfil transversal / Principal sem membership (OQ-044/048), 068 perfis oficiais (OQ-032; **PRD Superadmin diz MVP**) | backlog | M cada, após aprovação | D8 |
| F6 | Deploy público: host `superadmin.coelo.me`, allowlist de Auth, CORS dos buckets R2, SMTP próprio + prova do reset | ADR 0035/0044 | M + externo (DNS, Cloudflare, SMTP) | decisão de host |
| F7 | Acesso contextual de funcionários — **entregue em 19/09** (Sessão ACESSO-CONTEXTUAL): lote 84 em produção (`staff_access_v1`: regras/afastamentos por vínculo, enforcement em `has_context_permission`, RPCs, auditoria, pgTAP 68/68), telas Acessos › Acesso de funcionários e Afastamentos, popup no Principal, tour; 6 decisões tomadas pelo padrão da sessão (pendentes anotadas). **Complemento 19/09 (Sessão ACESSO-PERFIL, decisão do Owner):** horário definido pelo PERFIL de funcionário (Perfis e permissões › passo "Utilização do app", lote 86 `staff_access_profile_v1`), vínculo herda e pode ficar "fora do padrão" com "Voltar ao padrão do perfil"; origem do horário no diretório com filtro; varredura de 8 leitores legados (lote 90); `PT403`/`STAFF_ACCESS_DENIED` com motivo nos resolvers de ator e popup no cliente (lote 91); superfície recalculada ao redimensionar; pgTAP 39+13+18 (+68); prova em `docs/reviews/evidence/etapa-3/acesso-perfil/`. **Complemento 20/09 (Sessão ACESSO-PERFIL-FECHAMENTO):** PT403 em sessão aberta provado na rota real (popup do listener, folha "Ver como" fecha); fixture QA v2 (segundo vínculo na Instituição Sintética, prova pela API com 2 contextos); lote 102: dois perfis com horário → vale a mais restritiva (pgTAP 45/45) | ADR 0035 | — | Owner revisa olhando a tela |
| F8 | Tour funcional — **entregue** (menu 18/09; por tela e completo 19/09, Sessão TOUR-TELAS) | ADR 0035 | — | — |
| F9 | Home com IA sobre o app | ADR 0035 | G + custo de provedor | fonte/limites/custo |
| F10 | `apps/admin` em admin.coelo.me com adaptação de papel | ADR 0035 / PRD | G | F6; decisão do que sai do Superadmin |
| F11 | `apps/principal` em app.coelo.me (hoje hospedado) | ADR 0035 / PRD | G | F6; spec 064 |
| F12 | Três instituições fictícias com hierarquia para validar "Para você" | ADR 0039 | P | nome "Para você" |
| F13 | Push notifications (PRD: "push com payload mínimo") | PRD, sem ADR | G + provedor | F11 ou app instalado |
| F14 | App instalado (distribuição fora das lojas) | ADR 0035 | G | F11, F13 |
| F15 | Offline-tolerant provado (cache, rascunho, fila) | PRD | M | F11 |
| F16 | Eventos de analytics gravados desde o MVP | PRD | M | nada |
| F17 | Importação CSV/XLSX (PRD Admin diz MVP; ADR 0031 adiou para V1) | conflito PRD × ADR | G | decisão |
| F18 | MFA para internos (PRD Superadmin; adiado ADR 0044 E9) | conflito | M | decisão |

## 4. Decisão do Owner (18/09/2026) — ver ADR 0045

O Owner respondeu às perguntas M1–M9 na conversa com a coordenadora. O corte
vigente está em `decisions/0045-mvp-definition-etapa3-etapa4-20260918.md`:

- **Etapa 3** = correções da revisão de telas (com a reserva R16), tour, acesso
  contextual de funcionários, specs 065–069 (064 e 068 aprovadas; 064 vai para a
  Etapa 4), dez nomes para "Para você" e as instituições fictícias no fim.
- **Etapa 4** = publicação (host, Auth, CORS, SMTP), `apps/admin`,
  `apps/principal` com a spec 064, preparação de push e app instalado (lojas na
  V1), analytics, home com IA (reavaliar → V1).
- **V1** = importação/exportação, MFA, lojas, e o que já estava fora.

As seções 4–6 originais abaixo ficam como proveniência da proposta.

## 4-orig. Proposta de corte (proveniência) (recomendação da coordenação)

Critério: **Etapa 3 = tornar o que existe usável por um cliente real numa
instituição piloto, pelo navegador**. **Etapa 4 = superfícies novas e
dependências externas.** Fecha o MVP quem entrega as duas.

### Etapa 3 — fechar e publicar o app que existe

| Entra | Por quê |
|---|---|
| F1 revisão de telas + F2 + F3 | é o que o Owner já mandou para "tela a tela" |
| F4 specs 065/066/067/069 | contratos aprovados; 066 devolve `institutions.status` ao MVP como o PRD pede |
| F5 spec 068 perfis oficiais | PRD Superadmin lista como MVP |
| F6 deploy público + SMTP + CORS | sem isso nenhum cliente entra |
| F7 acesso contextual | núcleo da ADR 0035; segurança do vínculo profissional |
| F8 tour | pequeno, depende só de roteiro |
| F12 instituições fictícias | prova do "Para você" |
| F16 analytics | PRD exige "desde o MVP"; barato agora, caro depois |
| F18 MFA | decisão: manter adiado (recomendado) ou incluir |

### Etapa 4 — superfícies próprias e entrega no dispositivo

| Entra | Por quê |
|---|---|
| F10 `apps/admin` | app novo; exige decidir o que sai do Superadmin |
| F11 `apps/principal` em app.coelo.me + F5 spec 064 | app novo; hoje o Principal já funciona hospedado |
| F13 push + F14 app instalado + F15 offline | dependem de provedor e de app próprio |
| F9 home com IA | custo de provedor e governança (PRD: "IA em produção crítica" fora) |
| F17 importação | ADR 0031 já adiou; manter em V1 salvo decisão contrária |

### Fora do MVP (confirmar)

Planos comerciais, Financeiro, Catálogo de UI, dashboard visual, site/SEO,
comentários, lojas, white label, impersonation, matrícula, ERP, gamificação.

## 5-orig. Perguntas feitas ao Owner (respondidas) para fechar a definição

| # | Decisão | Recomendação |
|---|---|---|
| M1 | Aceitar o critério "Etapa 3 = publicar o que existe; Etapa 4 = superfícies novas" | sim |
| M2 | Admin como app próprio (F10) é MVP (Etapa 4) ou o Superadmin com escopo por tenant já cumpre o papel de Admin no piloto | Superadmin cumpre no piloto; `apps/admin` na Etapa 4 |
| M3 | Home com IA (F9): Etapa 3, Etapa 4 ou pós-MVP | Etapa 4 |
| M4 | Push e app instalado (F13/F14): MVP (Etapa 4) ou pós-MVP | Etapa 4, só web na Etapa 3 |
| M5 | Importação CSV/XLSX (F17): manter V1 | manter V1 |
| M6 | MFA internos (F18): manter adiado | manter adiado |
| M7 | Aprovar specs 064 e 068 e o nome "Para você" (D8) | aprovar 068 para a Etapa 3; 064 junto da Etapa 4 |
| M8 | Destino da dívida técnica "R16" (D3): revisão de telas ou Etapa 3 | junto da revisão de telas |
| M9 | Host e domínio de publicação (`superadmin.coelo.me`; Cloudflare Pages?) e provedor SMTP | decidir antes de abrir a Etapa 3 |

## 6-orig. Próximos passos previstos

1. ADR 0045: decisões D1–D9 e M1–M9, definição do MVP, abertura da Etapa 3 e
   registro da Etapa 4 (a ADR 0035 continua valendo; a 0045 a fatia).
2. Proposta consolidada da Etapa 3 (escopo, ordem, dependências, aceites,
   estimativa), como a ADR 0035 exige, com a lista F1–F18 marcada por etapa.
3. `current-state.md`, `backlog.md`, skills e `R16-pendencias.md` atualizados.
4. Bloco de notas da revisão de telas → linhas com tela, destino e ID existente.
