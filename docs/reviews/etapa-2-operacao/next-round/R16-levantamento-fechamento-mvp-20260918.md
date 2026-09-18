---
title: "Levantamento para o fechamento do MVP do Superadmin — decisões do Owner e roteiro de telas"
source: "docs/agent/current-state.md; docs/agent/backlog.md; R16-pendencias.md; decisions/0035, 0044; specs/README.md; docs/reviews/inventario-etapa-2.json; .agents/skills/coelo-supabase, coelo-flutter-review, coelo-flutter-supabase-review (SKILL.md e references/review-scope.md); apps/superadmin/lib/app/router/superadmin_router.dart"
status: "draft-for-owner-decision"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "owner"
---

# Levantamento — o que falta para fechar o MVP do Superadmin

> Documento de apoio à decisão. Não muda estado de nenhum `action_id`, Owner item
> ou H; a fila viva continua `R16-pendencias.md`. Depois das decisões, a coordenação
> atualiza a fila e, se for o caso, abre a proposta consolidada da Etapa 3 (ADR 0035).

## 1. Situação em 18/09/2026

| Medida | Valor | Fonte |
|---|---|---|
| Ações MVP (FE / BE / E2E) | 199/199, 186/186, 186/186 | `R16-checkpoint-20260917.md` |
| Ações não terminais no MVP | 0 | inventário (186 `verified/done/verified-e2e` + 13 `flutter-only`) |
| Ações fora do MVP (`v1`) | 33 | ADR 0044 |
| Owner items | 39/53 concluídos; 14 abertos/parciais/deferred | `R16-pendencias.md` |
| Resíduos H | 19 abertos (12 "R16", 10 "Etapa 3", H11 → V1) | idem |
| Dívida técnica da Mesa R16 | 11 itens "R16" + 6 itens "Etapa 3" | ADR 0044 |
| Produção | lote 81; Histórico, snapshot e sino já aplicados no lote 74 (prova pendente) | ver §2.1 |

**Conclusão de leitura:** pelo critério vigente (Etapa 2 = E2E do MVP, ADR 0044), a
Etapa 2 está fechada. "Fechar o MVP do Superadmin" hoje significa duas coisas, e o
Owner precisa dizer qual delas está pedindo:

- **(a) fechar o app da Etapa 2 pela revisão de telas** — zerar a reserva R16 que é
  UI/UX e prova, mandando o resto para a Etapa 3;
- **(b) fechar o MVP inteiro** — a Etapa 3 ainda faz parte do MVP (ADR 0035): acesso
  contextual de funcionários, tour, home com IA, admin/app.coelo.me e deploy público.

## 2. Reserva R16 — o que ainda não foi executado

### 2.1 Funcionalidades em produção sem prova na rota real (correção de 18/09)

**Correção:** as migrations `20260916180000` (Histórico), `20260916183000`
(snapshot) e `20260916190000` (sino de Medicação) **estão em produção desde o
lote 74 (16/09 17:40, ledger 307–309)**. As linhas de r12-04/06/33 em
`R16-pendencias.md` que dizem "NÃO aplicada" estão desatualizadas. O que falta é
só a prova na rota real, não lote novo.

| Item | O que a tela promete | O que falta | Destino (18/09) |
|---|---|---|---|
| owner.r12-04 | Acompanhamento › Assiduidade › **Histórico** (`/attendance/history`) | rota real, reload, negativa cross-tenant; decidir onde fica "Publicar lançamento" (spec 052 §3) | Sessão RESERVA, Bloco 1 |
| owner.r12-06 | rotina **registrada na conclusão** no detalhe e no Histórico | concluir/reabrir chamada real, legado, negativa PT409 | Sessão RESERVA, Bloco 1 |
| owner.r12-33 | **Sino** de Medicação | corrigir `recipients-bug` + incluir responsável (E7 = b) em v2 (lote 82); provar com 3 identidades | Sessão RESERVA, Bloco 1 |
| owner.r12-49 | Avaliações › **fechar / reabrir** | candidato não aplicado; prova na rota real | Sessão RESERVA, lote 82 |
| owner.r12-18 | Segurança › pessoa **sem conta** com documento | envio final pela tela; upload depende do CORS de `coelo-documents-prod` (E13) | envio agora na revisão de telas; upload na Etapa 3 |

Também nesta família: `oq048-membership` (candidato `20260917113000` versionado e
não aplicado) e `can-remove` (Agora; D6).

### 2.2 Provas pendentes sem código novo

| Item | Falta | Bloqueio |
|---|---|---|
| owner.r12-05 | negativa do contexto Atividade (instituição alheia / atividade inelegível); esclarecer `participants []` | nenhum; Mesa R16 aceitou massa sintética |
| owner.r12-08 | chamada com ≥2 alunos, múltiplas turmas, rotina vinculada | **decisão do Owner** (ADR 0041 D6: sem massa fictícia) |

### 2.3 Resíduos H marcados "R16" (12)

| ID | Tema | Tela | Natureza |
|---|---|---|---|
| H18 | unicidade global concorrente de `@` | Pessoas / Conta | backend (revisão de concorrência) |
| H19 | responsável vazio em Medicação | Medicação | reproduzir |
| H20 | imagem da dose sem gateway | Medicação | localizar consumidor |
| H21 | limite/rodapé de Circular | Circulares | BE feito (lote 68); falta host/rodapé (H04) |
| H22 | descritor privado de Circular | Circulares | alinhar à ADR 0032 |
| H24 | rótulos do Sobre | Conta › Sobre | UI |
| H25 | alvo de redimensionamento de tabela | todas as tabelas | acessibilidade |
| H27 | sinal de atualização de Momentos | Principal › Momentos | implementar (ADR 0038: saudação por hora, ponto laranja) |
| H28 | filtros, avatar e buffers de Pessoas | Pessoas | UI |
| H08 / H13 / H23 | Avisos: duplicar, CTA, visual (spec 069 aprovada) | Avisos | implementar FE+BE |

### 2.4 Dívida técnica e ambiente marcados "R16" (11)

`recipients-bug`, `can-remove`, `oq048-membership` (ver §2.1); `momentos-ux`
(publicador não bloqueia 2º toque; feed mostra "Curtido por Maria e outras 531
pessoas" de demonstração); `celular-mascara` (Conta: máscara e normalização do
Celular, decidir E.164 × exibição); `orfaos-cardapio` (2 imagens órfãs em cardápio
publicado); `form-diario` (form QA 4555ba07 com 30 ocorrências diárias);
`forms-v2-qa` (`superadmin_forms_*_v2` negando identidade QA; P0002 → 500;
account-media 422 em vez de 403); `espelho-cli` (`Sync-SupabaseCliMigrations.ps1
-Mode Clean`); `h02-aal2` (Sobre exige AAL2 com MFA fora do MVP); `testes-vermelhos`
(21 testes funcionais pré-existentes).

### 2.5 Já enviado à Etapa 3 pela Mesa R16 (não precisa nova decisão)

- Owner items: r12-10 (Table canônica em Segurança), r12-19/23 (spec 064),
  r12-29/30 (spec 065), r12-46 (Celular; sobrepõe `celular-mascara`), r12-53
  (spec 066/067).
- H: H02, H03, H04, H07, H09, H10, H12, H14, H16, H26.
- ADR 0038 Local interno em Formulários; `goldens` (139 vermelhos em 33 suítes;
  nota do Owner: componentizar o cabeçalho); `cors-r2`; `deploy-publico`;
  `activity-msg`; `smtp-reset`; `specs-064-069`.

### 2.6 Fora do MVP (sem decisão pendente)

33 ações `v1`: importação/exportação (exceto Formulários), MFA ×3, Catálogo de UI,
`plans.assign`, `institutions.status/files/locations-map`. Planos comerciais e
Financeiro: V1/V2 (ADR 0039). As telas existem no app (`/imports`, `/plans`,
`/governance/catalog`) e vão aparecer na passagem; conferir só se estão
sinalizadas como indisponíveis.

## 3. O que as skills dizem sobre a Etapa 3

As três skills (`coelo-supabase`, `coelo-flutter-review`,
`coelo-flutter-supabase-review`) **não carregam uma lista própria da Etapa 3**.
Elas publicam o mesmo parágrafo de estado (SKILL.md §Estado da Etapa 2) e a regra
em `review-scope.md:271`: "Etapa 3 só abre por decisão explícita do Owner (ADR
0035), após a revisão de telas". O conteúdo da Etapa 3 vive na ADR 0035, na ADR
0044 e em `backlog.md`. Consolidado:

**Predefinido (ADR 0035, 0039, 0041, 0044):**

1. Acesso contextual de funcionários: tela de acesso por instituição/unidade
   (web/tablet/mobile/app instalado, dias e horários, vigência) e tela de
   afastamentos; restrição imposta no servidor ao vínculo profissional; popups
   configuráveis e só informativos; auditoria.
2. Tour funcional e home com IA sobre os fluxos reais.
3. admin.coelo.me e app.coelo.me (`apps/admin`, `apps/principal`) com adaptação
   de papel; sem lojas.
4. Transferências da Mesa R16 (§2.5) e SMTP próprio + prova do reset (E8/E10).
5. Specs com implementação pendente: 065, 066, 067, 069 (aprovadas); 064 e 068
   (rascunho, aguardam aprovação).
6. Três instituições fictícias com hierarquia completa para validar o "Para você".

**A decidir pelo Owner (backlog.md):** abertura formal com proposta consolidada;
formato e agenda da revisão de telas; localização das telas de acesso contextual,
permissões, fuso/virada de dia/janelas, precedência instituição × unidade,
distinção de dispositivo, frequência dos popups; roteiro do tour, fonte e limites da
IA, custo de provedor; host de `superadmin.coelo.me`, allowlist de Auth, CORS dos
buckets, distribuição do app instalado; aprovar specs 064/068 e o nome "Para
você"; destino da dívida técnica da reserva.

## 4. Decisões do Owner em 18/09/2026

Tomadas na conversa com a coordenadora (registrar em ADR 0045 junto com a definição do MVP):

- **D1 = (b)**: o foco é o **MVP inteiro**; a Etapa 2 está fechada. Se faltar muito, o Owner divide entre **Etapa 3** (já existe, ADR 0035) e uma **Etapa 4** nova. Para isso, definir exatamente o que é o MVP (`MVP-definicao-etapa3-etapa4-20260918.md`).
- **D2 = sim** (na prática: prova na rota real, pois as migrations já estão em produção desde o lote 74).
- **D4 = liberar** massa sintética `QA R15` para r12-08.
- **D5 = E.164 + máscara** para o Celular.
- **D6**: Owner listou as duas opções sem escolher; padrão adotado = **feed segue a RPC** (administradores podem remover), a confirmar.
- **D7 = sim**: 21 testes funcionais antes de fechar; goldens na Etapa 3 (componentizar o cabeçalho).
- **Execução**: D2/D4/D5/D6/D7 vão para uma sessão paralela única e sequencial (`R16-prompt-reserva-20260918.md`); a revisão tela a tela e a definição do MVP ficam com o Owner e a coordenadora nesta conversa.
- Pendentes: D3, D8, D9 (abaixo).

### Tabela original das decisões (referência)

| # | Decisão | Opções | Recomendação da coordenação |
|---|---|---|---|
| D1 | O que significa "fechar o MVP do Superadmin" | (a) app da Etapa 2 fechado pela revisão de telas; (b) MVP completo com Etapa 3 | (a) agora; (b) é a proposta consolidada da Etapa 3 |
| D2 | Aplicar em produção as 3 migrations locais verdes (Histórico, snapshot, sino) **antes** da revisão de telas | sim (lote 82, rito, autorização nominal) / não (telas ficam "sem backend") | **sim**: senão a passagem pelo app registra como defeito o que já está pronto |
| D3 | Executar os itens "R16" da Mesa R16 (§2.3–2.4) antes da revisão, durante, ou mandar para a Etapa 3 | antes / junto da correção de cada tela / Etapa 3 | junto: cada item vira linha do bloco de notas da tela correspondente |
| D4 | Massa para owner.r12-08 (≥2 alunos) | manter D6 (sem massa) / liberar massa sintética `QA R15` | liberar, já que a Mesa R16 aceitou sintéticos para r12-05 |
| D5 | Formato do Celular (r12-46 / `celular-mascara`) | E.164 no servidor + máscara BR na exibição / gravar como digitado | E.164 + máscara |
| D6 | `can-remove` no Agora | feed segue a RPC (administradores podem remover) / RPC restringe ao autor | feed segue a RPC |
| D7 | Destino dos `testes-vermelhos` (21) e goldens (139) | corrigir antes de fechar o app / Etapa 3 com o cabeçalho componentizado | goldens Etapa 3 (já decidido); testes funcionais antes, pois são regressão real |
| D8 | Aprovar specs 064 e 068 e o nome "Para você" | aprovar / revisar | necessário antes de qualquer trabalho da Etapa 3 no Principal |
| D9 | Abrir a Etapa 3 depois da revisão de telas | abrir com proposta consolidada / manter fechada | abrir só após o bloco de notas da revisão estar consolidado |

## 5. Roteiro tela a tela (para o bloco de notas)

Ordem sugerida pelo menu. Em cada tela, anotar: o que está errado (visual, texto,
comportamento), e marcar se é **corrigir agora** ou **Etapa 3**. Os itens já
conhecidos estão indicados para você confirmar ou descartar.

| Módulo | Rota | Itens conhecidos a observar |
|---|---|---|
| Login / recuperar / redefinir | `/login`, `/forgot-password`, `/reset-password` | `smtp-reset` (Etapa 3); fluxo já provado |
| Home | `/home` | Tour e IA (Etapa 3) são placeholders — conferir que não simulam serviço |
| Instituições | `/institutions`, `/new`, `/:id/edit`, `/:id/locations` | r12-53 / specs 066–067 (Etapa 3); status e mapa são `v1` |
| Unidades | `/units`, `/new`, `/:id/edit` | — |
| Turmas | `/groups`, `/:id`, `/new`, `/:id/edit` | — |
| Pessoas | `/people`, `/:id`, `/new`, `/:id/edit` | H28 (filtros, avatar, buffers); H18 (`@`) |
| Alunos | `/students`, `/:id/manage` | — |
| Acessos › usuários internos | `/internal-users`, `/:id`, `/:id/edit` | MFA é `v1` |
| Acessos › perfis e modelos | `/profiles`, `/profile-models` (+ `/:domain/:id`, `/edit`, `/duplicate`) | r12-19/23 (spec 064, Etapa 3); resíduos: tooltip por foco não fecha (r12-24), rótulo "Excluir" × "Inativar modelos Admin." e reason `[redacted]` (r12-21), catálogo em inglês, "Vínculos" conta platform_memberships (r12-20) |
| Convites | `/invites`, `/:id`, `/new` | goldens e `invite_responsive_test` |
| Segurança da criança | `/safety`, `/new`, `/children/:id`, `/authorizations/:id/edit` | r12-10 (Table canônica), r12-18 (envio final e upload do documento), H16 |
| Perfis de cuidado | `/health-care/profiles`, `/new`, `/:childId`, `/edit` | r12-29/30 (spec 065: wizard Alimentos × Restrições, reordenar, "o que fazer se consumido?"); `recipients-bug` |
| Medicação | `/health-care/medication-plans`, `/new`, `/:id`, `/edit` | r12-33 (sino, D2), H19, H20 |
| Assiduidade | `/attendance`, `/new`, `/calls/:id`, `/history` | r12-04 (Histórico, D2), r12-06 (snapshot, D2), r12-05 (contexto Atividade), r12-08 (D4), `activity-msg` ("Confira a conexão" em 422), `participants-vazio`; decidir onde fica "Publicar lançamento" (spec 052 §3) |
| Rotina diária | `/daily-routine`, `/new`, `/:id/edit` | aba Lançamentos retirada (r12-04) |
| Atividades | `/activities`, `/new`, `/:id`, `/edit`, `/assessment-settings` | `activity-msg` |
| Avaliações | `/assessments/entry`, `/gradebooks/:id/edit`, `/closing`, `/closing/:id` | r12-49 (fechar/reabrir) |
| Agenda | `/agenda`, `/events`, `/requests`, `/approvals`, `/permissions` | — |
| Avisos | `/notices`, `/new`, `/:id/edit` | H08 duplicar, H13 CTA, H23 visual (spec 069); golden do filtro Estado |
| Circulares | `/circulars`, `/new`, `/:id/edit`, `/:id/read` | H04 compositor/blocos (Etapa 3), H21 host/rodapé, H22 descritor |
| Conversas | `/communication/conversations` | H07 hash (Etapa 3); multi-anexo já provado |
| Formulários | `/forms`, `/new`, `/:id`, `/edit`, `/files`, `/monitor`, `/responses`, `/test`, `/occurrences/:id/respond` | H10, H12, H26 (Etapa 3), Local interno ADR 0038, `form-diario`, `forms-v2-qa` |
| Cardápios | `/meal-plans`, `/new`, `/:id/edit`, `/models/new`, `/models/:id/edit` | `orfaos-cardapio`; golden do diretório |
| Suporte | `/support` | status mapeado (OQ-028) |
| Auditoria | `/audit` | exportar é `v1` |
| Importações / Planos / Catálogo | `/imports`, `/plans`, `/governance/catalog` | `v1` — conferir que a tela sinaliza indisponível |
| Conta (menu do cabeçalho) | perfil, Sobre | r12-46 layout A+ e Celular (D5), H24 rótulos, H02/`h02-aal2` (Etapa 3) |
| Principal hospedado › Agora | `/principal-now`, `/publication` | `can-remove` (D6), H09 expiração agendada (Etapa 3) |
| Principal › Momentos | `/principal-moments`, `/publish` | `momentos-ux` (2º toque; "Curtido por Maria e outras 531 pessoas"), H27 |
| Principal › Acontece | `/principal-happens`, `/publish` | — |
| Principal › Para você | `/principal-for-you` | 3 instituições fictícias e nome (Etapa 3); spec 068 |
| Principal › Perfil | `/principal-profile` | H03 (quatro abas, Etapa 3) |
| Principal › Conversas | `/principal-conversations` | H07 |
| Transversal | todas as tabelas, cabeçalho, sino | H25 (redimensionamento), H14 (sino sem action_id), cabeçalho a componentizar (goldens) |

## 6. Depois das decisões

1. Coordenação registra D1–D9 numa ADR curta (0045) e reordena `R16-pendencias.md`.
2. Se D2 = sim: lote 82 pelo rito (espelho verde → dump → autorização nominal →
   aplicar → pgTAP remoto → ledger), antes da passagem pelo app.
3. O bloco de notas da revisão vira a lista de correções; cada linha recebe tela,
   destino (agora / Etapa 3) e, quando houver, o ID existente (Owner item, H,
   dívida) — sem criar IDs concorrentes.
4. Com a lista fechada, proposta consolidada da Etapa 3 (ADR 0035) para abertura.
