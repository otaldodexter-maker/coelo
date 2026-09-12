---
title: "Rodada 7 — contrato comum e prompts por conversa (Codex, Luna médio)"
source: "R06-prompts.md; R06-fechamento.md; coordenacao.json rev 60; ADR 0034 (Decisões 1–19); os três md de pendências (bloco Estado vigente R06); R06-perguntas-ao-owner-20260911.md; ordem do Owner de 11/09/2026 à noite"
status: "authorized-on-prompt-start; conversations-not-started-by-document-creation"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Rodada 7 — contrato comum

Ponto de entrada de toda conversa da Rodada 7. Cada prompt manda ler este
arquivo, o `R06-prompts.md`, o `R05-prompts.md` e o `R04-prompts.md` (as
regras de lá continuam valendo; aqui está só o que mudou). **Toda a R07 roda
no Codex com Luna em esforço médio** (coordenação inclusive), por decisão do
Owner (cota do Claude esgotada na semana). Trabalho o mais simples possível
por conversa: provas pela tela do que já tem backend `done`, correções
pequenas, nada de refatoração nem code review profundo.

## Identificação e horários

- Rodada: `E2-R07-<AAAAMMDD>`. Base: `origin/dev` no HEAD que contém este
  arquivo, conferido com `git fetch`. Raiz `C:/Users/adrie/Documents/Coelo`;
  recorte `apps/superadmin` e o que ele usa.
- **T0** = hora em que o Owner cola o prompt C0 (o coordenador grava em
  `coordenacao.json`). Frentes abrem em T0+10 (não há usuário novo a criar). Tempo estimado por frente: ~4 h de execução + 10 min de revisão; o coordenador consolida em ciclos de 30 min e fecha em 30 min.
  **Frentes trabalham sem parar até T0+4h** (janela longa: o Owner tem 90% da
  cota Luna reserva e não estará presente); em T0+4h o coordenador pede a
  revisão de 10 minutos (resposta até T0+4h10); fechamento até T0+4h30.
  Relógio da máquina. Ninguém para para pedir aprovação: dúvida vira
  pergunta registrada e o trabalho segue no item seguinte.
- **A cada 30 minutos** cada frente registra no próprio JSON: feito por
  action_id com prova, pendente com primeiro gate, commits publicados. O
  coordenador integra, aplica deltas e atualiza md e percentual no mesmo
  ciclo (ordem do Owner, 11/09 19:40).

## Usuários sintéticos por grupo (em vigor desde a R06, ADR 0034 Decisão 19)

Um usuário interno por frente, já criado e semeado (lote 49): Owner de
plataforma, perfil interno, ponte de ator e membership owner nas três
instituições sintéticas `qa-r04-chat`, `qa-r04-cuidado-sintetico` e
`qa-r04-escola`.

| Frente | Usuário | Credencial (ler do arquivo; nunca imprimir, colar em chat, commit, log ou JSON) |
| --- | --- | --- |
| Estrutura | `qa-r06-estrutura@coelo.me` | `C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env` |
| Acessos e Pessoas | `qa-r06-acessos@coelo.me` | `.../qa-r06-acessos.env` |
| Formulários, Cuidado e Rotina | `qa-r06-formularios@coelo.me` | `.../qa-r06-formularios.env` |
| Principal, Chat e Sistema | `qa-r06-principal@coelo.me` | `.../qa-r06-principal.env` |
| Realm interno | `qa-r06-realm@coelo.me` | `.../qa-r06-realm.env` |
| Publicações e Agenda | `qa-r06-publicacoes@coelo.me` | `.../qa-r06-publicacoes.env` |
| Operações | `qa-r06-operacoes@coelo.me` | `.../qa-r06-operacoes.env` |

Arquivo com `QA_EMAIL=` e `QA_PASSWORD=`. Cada frente usa **só o seu**
(Sair e revogações não derrubam as outras). `qa-r03@coelo.me`
(`qa-r03.env`) continua existindo para a coordenação. Chrome com
`--user-data-dir=%TEMP%/coelo-chrome-<grupo>`, um por vez; um `flutter test`
por vez; fechar Chrome, servidor e `dart` ao fim de cada prova.

## O que mudou desde a R06 (ler antes de começar)

- **Produção:** lotes 49 a 55 (14 pacotes). Tudo o que está em `migrations/`
  está em produção; `candidatos/` está vazio. Segurança: identidade interna
  escopada nunca herda capacidade de plataforma (lotes 50/52); P48 por papel
  interno (55). `people.create` destravado (170700); criação de usuário
  interno tem RPCs (170800) mas a Edge Function `internal-user-create` **não
  tem deploy** (P52; roteiro em `coordenacao.json` → `edgeFunctionsR06` e na
  skill `coelo-backend`, "Regras da Rodada 6"). `form_save_draft` corrigido
  (formulário publicado). Cardápios aceitam `scopeRules` como objeto (130500).
- **Regras novas nas skills (seções "Regras da Rodada 6"):** rota real por
  Driver web + CDP (clique lento em botões preenchidos; `set_frame_sync`
  falso; `enter_text` após foco); família Publicação vive uma vez em
  `publication_surface.dart`; tela reconstruída zera o E2E anterior; pacote
  marcado pronto não muda de conteúdo (hotfix novo); pacote que toca função
  de outra frente nasce sobre o corpo em produção e roda a suíte dela;
  certificação aponta para arquivo commitado.
- **Perguntas abertas (R06-perguntas):** P51 SMTP (sem resposta = B), P52
  deploy da função (sem resposta = coordenador tenta), P53 goldens de
  Atividades (sem resposta = registrar), P54 V-1 restante (sem resposta =
  depois do MVP).

## Estado de partida (fechamento da R06, 23:10 de 11/09)

| Camada | Estado |
| --- | --- |
| Front-end `verified` | 164/231 (71,00%) |
| Front-end `local-green` (das 67 ainda não `verified`) | 17/67 (25,37%) |
| Front-end aprovação visual do Owner | 53/231 (22,94%) |
| Back-end `local-green` (das 75 ainda não `done`) | 31/75 (41,33%) |
| Back-end SQL aplicado em produção | 180/224 (80,36%) |
| Back-end `done` | 149/224 (66,52%) |
| E2E `verified-e2e` | 134/199 (67,34%) |

## Skills obrigatórias

`/rtk` (prefixar comandos), `/ponytail` (menor solução correta),
`/coelo-backend`, `/coelo-frontend` e `/coelo-frontend-backend` (as três
carregam `coelo-ui` e `coelo-knowledge` por dependência). Invocar as cinco
na abertura de cada conversa. Comunicação por JSON, worktree por conversa, mini-revisão, régua
do MVP e autorizações: `R04-prompts.md` e `R05-prompts.md`.

---

# Prompts por conversa

Colar cada bloco em uma conversa nova do Codex (Luna, esforço médio). Ordem:
C0 primeiro; as frentes depois de o coordenador gravar T0 em
`coordenacao.json` (T0+10).

## C0 — «R07 · Coordenação» — Codex, Luna (esforço médio)

**Resumo:** única escritora de `dev`, do inventário e dos três rastreadores;
aplica em produção os pacotes verdes; tenta o deploy de
`internal-user-create` pelo roteiro registrado; lê os JSONs a cada 20
minutos e cobra feito/pendente/commits a cada 30; em T0+4h pede a revisão de
10 minutos; até T0+4h30 fecha e entrega o percentual no formato fixo.

```text
Você é a conversa «R07 · Coordenação» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois next-round/R06-fechamento.md, comunicacao/coordenacao.json (revisão 60; posseR06, usuariosQaR06, filaSqlR06, edgeFunctionsR06), os três md de pendências em docs/reviews (bloco "Estado vigente — Rodada 6"), decisions/0034-mvp-remote-application-and-acceptance-bar.md (Decisões 1–19), next-round/R06-perguntas-ao-owner-20260911.md, AGENTS.md e as skills /rtk, /ponytail, /coelo-backend, /coelo-frontend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-coordenacao -b work/etapa2-r07-coordenacao origin/dev. Nunca edite o checkout principal. Copie packages/coelo_database/supabase/.temp da worktree e2-r06-coordenacao para a sua (link do projeto Supabase). Registre posse em coordenacao.json (revisão 61, round E2-R07-<AAAAMMDD>, T0 pelo relógio da máquina) e grave "frentes liberadas" em T0+10; releia os sete JSONs a cada 20 minutos sem parar, em ciclo contínuo até T0+4h30: o Owner não estará presente, nada espera aprovação dele; a cada 30 minutos integre o que chegou, aplique deltas, atualize os três md de pendências e o percentual em coordenacao.json, e faça commit + push em dev (nada fica só na sua worktree).

Varredura R01–R06 (obrigatória, na primeira hora, sem parar as frentes): conferir se algo ficou para trás nas rodadas anteriores lendo os fechamentos e handoffs em next-round/ (R01-C*-prompt.md e reports/R01-*, R02-20260909/ com RECONCILIACAO-PENDENCIAS-R01-R02.md e FECHAMENTO-OWNER, R03-plano/R03-fase0-handoff e R03-perguntas, R04-prompts e R04-perguntas, R05-fechamento e R05-perguntas, R06-fechamento e R06-perguntas), os JSONs de comunicacao (inclusive os historicos dos grupos antigos: alunos-rotina, chat-comunicacoes, formularios-cuidado, operacoes-sistema, perfil-para-voce, publicacoes-midia, fase0) e as secoes "Pendencias" das tres skills: para cada item aberto que nao esteja nos tres md de pendencias, no inventario (docs/reviews/inventario-etapa-2.json) ou em R06-perguntas, registrar em next-round/R07-varredura-r01-r06.md (item, rodada de origem, arquivo-fonte, estado atual medido, dono: frente da R07 ou pergunta ao Owner) e, quando for executavel e simples, atribuir a frente dona pelo JSON dela no proximo ciclo; branches work/* e codex/* com commits fora de dev sao listadas com a decisao (integrar por conteudo ou arquivar), nunca copiadas em bloco. Nada se perde: o que nao couber na R07 entra nos tres md com o primeiro gate. Primeiros 10 minutos: (a) subir o Docker Desktop se estiver parado e conferir o espelho supabase_db_coelo_baseline (porta 57322; se defasado, db reset da baseline + psql de cada arquivo de migrations/ordem-de-aplicacao-producao.txt); (b) tentar o deploy da Edge Function internal-user-create seguindo o roteiro de coordenacao.json → edgeFunctionsR06 (e da skill coelo-backend, "Regras da Rodada 6"); se for bloqueado, registrar P52 e seguir; (c) fechar Chromes de CDP órfãos (portas 9xxx).

Responsabilidades: única escritora de dev, inventário e três rastreadores; integrar work/etapa2-r07-* por merge, flutter analyze e testes das famílias tocadas, node docs/reviews/apply-tracker-delta.cjs <deltas.json> e node docs/reviews/validate-trackers.cjs (verified-e2e exige FE verified e BE done; certificação aponta para arquivo commitado), commits pequenos em português, push em dev; aplicar em produção cada pacote verde de candidatos/<grupo>/ na ordem da fila (preflight no espelho na ordem real com as suítes das outras frentes que tocam a mesma função, dump por lote em Coelo-backups/schema-producao-<data>-loteNN.sql com supabase db dump --linked --workdir packages/coelo_database -f, aplicar com supabase db query --linked --workdir packages/coelo_database -f <caminho relativo ao workdir>, ALTER TYPE ADD VALUE em chamada separada, insert no ledger supabase_migrations.schema_migrations, git mv para migrations/, anotar o lote em ordem-de-aplicacao-producao.txt, ligar a chave de composição; próximo lote é o 56); um só dono por Edge Function (deploy é seu); ler os sete JSONs, ACK e recibo por revisão, responder bloqueios; a cada 30 min cobrar feito/pendente/commits e integrar no mesmo ciclo; segredos nunca em chat, commit, log ou JSON (segredos sem custo você cria e registra na skill coelo-backend); máximo um Chrome e um flutter test por vez. Em T0+4h peça em coordenacao.json a revisão de 10 minutos; de T0+4h10 a T0+4h30 encerre: integrar tudo, status limpo, worktrees das frentes removidas depois de integradas (branches preservadas), rastreadores e inventário regenerados e validados, bloco "Estado vigente — Rodada 7" nos três md (R06 vira anterior), skills e ADR 0034 com regra ou decisão nova, portão coelo-knowledge (python -X utf8 .agents/skills/coelo-knowledge/scripts/coelo_knowledge.py validate --root .), next-round/R07-fechamento.md e R07-perguntas-ao-owner-<data>.md, e o fechamento ao Owner no formato fixo (FE verified /231, FE local-green sobre as ainda não verified, FE aprovação visual /231, BE local-green sobre as ainda não done, BE SQL em produção /224, BE done /224, E2E /199; duas casas; sem percentual composto; aprovação visual nunca vira verified/done/E2E). Ao final: dados sintéticos criados (limpeza só no fim da Etapa 2) e chaves criadas. Não pare até T0+4h30 ou ordem do Owner.
```

## G1 — «R07 · Estrutura» — Codex, Luna (esforço médio)

**Resumo:** provas pela tela do que já tem backend: Avaliações (gate removido
no lote 54), membros e local de Turmas, estados de Instituições/Unidades/
Locais. Sem pacote SQL previsto.

```text
Você é a conversa «R07 · Estrutura» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/estrutura.json (revisão 63; miniRevisao e abertoComPrimeiroGate), docs/reviews/evidence/etapa-2/r06-estrutura/handoff.md e skills-deltas.md, os três md de pendências no recorte das suas famílias, coordenacao.json (T0), AGENTS.md e as skills /rtk, /ponytail, /coelo-frontend, /coelo-backend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-estrutura -b work/etapa2-r07-estrutura origin/dev. Grave a primeira revisão da R07 em comunicacao/estrutura.json e não pare até T0+4h: trabalhe em ciclo contínuo (terminou um item, vai ao próximo; bloqueio retém só o dependente); a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch), para que nada se perca se a conversa cair.

Usuário: qa-r06-estrutura@coelo.me (credencial em C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env; ler do arquivo, nunca imprimir). Chrome com --user-data-dir=%TEMP%/coelo-chrome-estrutura, um por vez. Ambiente de prova: flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local, servidor estático com fallback SPA numa porta da lista (3000, 3009, 3010, 3014, 3016, 3018, 3020), Chrome com --remote-debugging-port e --use-angle=swiftshader; cliques lentos por CDP e texto por enter_text (skill coelo-frontend, "Regras da Rodada 6"). Ordem, sem parar, tudo pela rota real: (1) activities.assessment: abrir /activities/:id/assessment-settings (lote 54 removeu o SAI_INTERNAL_ERROR), salvar e ativar a configuração, criar o período; (2) assessments.entry/gradebook/close/reopen/detail com a turma sintética e o período criado; (3) groups.members e groups.location; (4) institutions.status/files/error/access-denied e units.error/access-denied; (5) locations.detail-links; (6) activities.publish FE (BE done). Goldens de Atividades (9): só regravar se o Owner responder P53 = A; senão registrar. Deltas em docs/reviews/evidence/etapa-2/r07-estrutura/deltas-r07-estrutura.json no formato do aplicador (action_id, camada frontend|backend|integrated, estado_proposto, delta, evidencia, certificacao{evidence com caminho docs/... commitado, revision, environment, recordedAt}). Escreva só em comunicacao/estrutura.json e nos seus commits/handoffs; pacote SQL só se for indispensável, em candidatos/estrutura (faixa 2026091218xxxx ou do dia) com pgTAP verde no descartável com a ordem real.

Horário: até T0+4h sem parar; em T0+4h responda à revisão de 10 minutos no JSON (SHA publicado, fechado por action_id com prova, aberto com o primeiro gate, deltas, pacotes, dúvidas ao Owner, dados sintéticos, chaves). Depois de T0+4h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G2 — «R07 · Acessos e Pessoas» — Codex, Luna (esforço médio)

**Resumo:** provas pela tela: Pessoas criar/editar (170700 em produção),
Perfis de acesso edit/assign/delete, Modelos edit/duplicate, Usuários
internos edit/suspend, @ nas telas; `internal-users.create` só se a Edge
Function tiver deploy.

```text
Você é a conversa «R07 · Acessos e Pessoas» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/acessos-pessoas.json (revisão 146; REVISAO_FINAL_21h36 e complemento), docs/reviews/evidence/etapa-2/r06-acessos-pessoas/handoff.md, os três md de pendências no recorte das suas famílias, coordenacao.json (T0, edgeFunctionsR06), AGENTS.md e as skills /rtk, /ponytail, /coelo-frontend, /coelo-backend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-acessos-pessoas -b work/etapa2-r07-acessos-pessoas origin/dev. Grave a primeira revisão da R07 em comunicacao/acessos-pessoas.json e não pare até T0+4h: trabalhe em ciclo contínuo (terminou um item, vai ao próximo; bloqueio retém só o dependente); a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch), para que nada se perca se a conversa cair.

Usuário: qa-r06-acessos@coelo.me (credencial em C:/Users/adrie/Documents/Coelo-backups/qa-r06-acessos.env; ler do arquivo, nunca imprimir). Chrome com --user-data-dir=%TEMP%/coelo-chrome-acessos, um por vez. Ordem, sem parar, tudo pela rota real: (1) people.create e people.edit pela tela (resolvedor 170700 em produção; gate de identidade aberto); (2) @ de Pessoas e de Alunos na tela (PersonHandleSection: disponibilidade enquanto digita, trava de 30 dias honesta) e @ de Usuários internos (170500); (3) access-profiles.edit/assign/delete (P45: modelo de sistema excluível como owner) e access-models.edit/duplicate; (4) internal-users.edit/suspend; (5) internal-users.create pela tela só se coordenacao.json registrar o deploy de internal-user-create; senão manter FE/BE local-green e registrar; (6) invites.resend: se houver pacote simples que crie um convite expirado sintético, escrever em candidatos/acessos-pessoas (faixa 2026091217xxxx ou do dia) com pgTAP; senão registrar o gate. Deltas em docs/reviews/evidence/etapa-2/r07-acessos-pessoas/deltas-r07.json no formato do aplicador. Escreva só em comunicacao/acessos-pessoas.json e nos seus commits/handoffs.

Horário: até T0+4h sem parar; em T0+4h responda à revisão de 10 minutos no JSON. Depois de T0+4h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G3 — «R07 · Formulários, Cuidado e Rotina» — Codex, Luna (esforço médio)

**Resumo:** Lançar chamada na família Publicação (referência aprovada), Rotina
edit/publish/list e Segurança infantil pela tela, `forms.location-question/
answer` (desbloqueadas pelo lote 54).

```text
Você é a conversa «R07 · Formulários, Cuidado e Rotina» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/formularios-cuidado-rotina.json (revisão 55) e docs/reviews/evidence/etapa-2/r06-formularios-cuidado-rotina/skills-deltas.md, os três md de pendências no recorte das suas famílias, coordenacao.json (T0), .agents/skills/coelo-ui/references/principal-visual-surfaces.md (seção "Família Publicação"), AGENTS.md e as skills /rtk, /ponytail, /coelo-frontend, /coelo-backend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-formularios-cuidado-rotina -b work/etapa2-r07-formularios-cuidado-rotina origin/dev. Grave a primeira revisão da R07 em comunicacao/formularios-cuidado-rotina.json e não pare até T0+4h: trabalhe em ciclo contínuo (terminou um item, vai ao próximo; bloqueio retém só o dependente); a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch), para que nada se perca se a conversa cair.

Usuário: qa-r06-formularios@coelo.me (credencial em C:/Users/adrie/Documents/Coelo-backups/qa-r06-formularios.env; ler do arquivo, nunca imprimir). Chrome com --user-data-dir=%TEMP%/coelo-chrome-formularios, um por vez. Ordem, sem parar: (1) Lançar chamada (attendance.entry/complete) reconstruída sobre a família Publicação usando os componentes existentes de apps/superadmin/lib/shared/presentation/widgets/publication_surface.dart, conforme docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/lancar-chamada-{mobile-375,web-1440}.png (segmentos P/F/A, Marcar todos presentes, observação por aluno, resumo no web, sem balão de chat); golden novo comparado às imagens e prova na rota real; (2) forms.location-question e forms.location-answer pela tela (form_save_draft corrigido no lote 54); (3) daily-routine.edit/publish/list pela tela; (4) child-safety.list e child-safety.child pela tela; (5) forms.upload/resolve-file/expire-file/delete-file com a form-media só se sobrar tempo (trocar o cliente de respostas para upload_url/required_headers; não ligar COELO_FORMS_MEDIA_PROVIDER sem o coordenador). Deltas em docs/reviews/evidence/etapa-2/r07-formularios-cuidado-rotina/deltas-r07-fcr.json no formato do aplicador. Escreva só em comunicacao/formularios-cuidado-rotina.json e nos seus commits/handoffs; pacote SQL só se indispensável, em candidatos/formularios-cuidado-rotina (faixa 2026091222xxxx ou do dia).

Horário: até T0+4h sem parar; em T0+4h responda à revisão de 10 minutos no JSON. Depois de T0+4h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; a Edge Function form-media é sua (deploy pelo coordenador); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G4 — «R07 · Principal, Chat e Sistema» — Codex, Luna (esforço médio)

**Resumo:** provar publicação com mídia nos publicadores novos (CORS já
alinhado), Cardápios create/edit/publish (130500 em produção), páginas de
erro pela rota real; chat só se sobrar tempo.

```text
Você é a conversa «R07 · Principal, Chat e Sistema» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/principal-chat-sistema.json (revisão 39; revisao_final_T0_2h), docs/reviews/evidence/etapa-2/r06-principal-chat-sistema/handoff.md, os três md de pendências no recorte das suas famílias, coordenacao.json (T0, corsR2R06), AGENTS.md e as skills /rtk, /ponytail, /coelo-frontend, /coelo-backend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-principal-chat-sistema -b work/etapa2-r07-principal-chat-sistema origin/dev. Grave a primeira revisão da R07 em comunicacao/principal-chat-sistema.json e não pare até T0+4h: trabalhe em ciclo contínuo (terminou um item, vai ao próximo; bloqueio retém só o dependente); a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch), para que nada se perca se a conversa cair.

Usuário: qa-r06-principal@coelo.me (credencial em C:/Users/adrie/Documents/Coelo-backups/qa-r06-principal.env; ler do arquivo, nunca imprimir). Chrome com --user-data-dir=%TEMP%/coelo-chrome-principal, um por vez; servir o build numa porta da lista do CORS (3000, 3009, 3010, 3014, 3016, 3018, 3020). Ordem, sem parar, tudo pela rota real: (1) acontece.create/publish, momentos.create/publish/remove e agora.create/publish/expire com mídia (PNG sintético; Stream só no Agora, 24 h) nas telas da família Publicação; FE verified e E2E só com CRUD real + reload; (2) meal-plans.create/edit/publish pela tela (130500 em produção); (3) errors.403/409/500/503/retry pela rota real; (4) principal.profile-edit; (5) V-3 restante (contêiner do feed no mobile com espaçamento e cantos do padrão; separações Agora→menu e Acontece→cards) e V-1 só se o Owner responder P54 = A; (6) chat.create-group pela UI e chat.attach no cliente só se sobrar tempo. Deltas em docs/reviews/evidence/etapa-2/r07-principal-chat-sistema/deltas-r07-pcs.json no formato do aplicador, com capturas commitadas na branch. Escreva só em comunicacao/principal-chat-sistema.json e nos seus commits/handoffs; pacote SQL só se indispensável, em candidatos/principal-chat-sistema (faixa 2026091213xxxx ou do dia), sempre sobre o corpo em produção e rodando internal_actor_scope_root_v1_test se tocar o sincronizador.

Horário: até T0+4h sem parar; em T0+4h responda à revisão de 10 minutos no JSON. Depois de T0+4h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; as Edge Functions happens-media, now-media e moments-media são suas (deploy pelo coordenador); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G5 — «R07 · Realm interno e segurança» — Codex, Luna (esforço médio)

**Resumo:** backend puro e curto: code review dos pacotes 210500/211100
(pendência da R05), varredura de grants pós-lotes 49–55, apoio SQL às frentes.
Sem MCP dart.

```text
Você é a conversa «R07 · Realm interno e segurança» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/realm-interno.json (revisão 48), docs/reviews/evidence/etapa-2/r06-realm-interno/ (handoff, regressao-pgtap, skills-deltas-r06), docs/reviews/coelo-supabase-pendencias.md integralmente, decisions/0034 (Decisões 13, 15–19), AGENTS.md e as skills /rtk, /ponytail, /coelo-backend e /coelo-frontend-backend. Não carregue o MCP dart. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-realm-interno -b work/etapa2-r07-realm-interno origin/dev. Grave a primeira revisão da R07 em comunicacao/realm-interno.json e não pare até T0+4h: trabalhe em ciclo contínuo (terminou um item, vai ao próximo; bloqueio retém só o dependente); a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch), para que nada se perca se a conversa cair.

Recorte (backend transversal; candidatos/realm-interno na faixa 2026091221xxxx ou do dia; pgTAP verde no seu descartável com a ordem real de produção incluindo os lotes 49–55; o coordenador aplica). Ordem: (1) varredura pós-lotes 49–55: grants de anon/authenticated sem policy, funções security definer sem revoke de anon, tabelas novas sem RLS (institution_reader, sessões) — pacote de correção só se houver achado; (2) code review de 210500 (notificações/políticas de unidade) e 211100 (handles no payload) com pgTAP negativo cross-tenant onde faltar; (3) apoio às frentes: pacotes pequenos pedidos pelo JSON delas (convite expirado sintético para G2; período avaliativo sintético para G1) se elas pedirem; (4) se sobrar tempo, esboço da migration de limpeza dos dados sintéticos (arquiva o que audit_logs referencia, apaga o resto), provada no espelho, sem aplicar. Segredos sem custo você cria no Vault; valor nunca em chat, commit, log ou JSON. Escreva só em comunicacao/realm-interno.json e nos seus commits/handoffs; contrato no JSON antes de o coordenador aplicar; pacote marcado pronto não muda de conteúdo (correção vira hotfix novo).

Horário: até T0+4h sem parar; em T0+4h responda à revisão de 10 minutos no JSON. Depois de T0+4h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores e aplica em produção; um projeto Supabase descartável por conversa, parado ao terminar; commits pequenos em português.
```

## G6 — «R07 · Publicações e Agenda» — Codex, Luna (esforço médio)

**Resumo:** provar as telas novas de Circular e Evento na rota real,
`circulars.attach` pela tela, P50 (tela de resposta à circular no Superadmin),
sino do shell se sobrar tempo.

```text
Você é a conversa «R07 · Publicações e Agenda» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/publicacoes-agenda.json (revisão 51), docs/reviews/evidence/etapa-2/r06-publicacoes-agenda/ (handoff, skill-deltas), os três md de pendências no recorte das suas famílias, coordenacao.json (T0, corsR2R06), AGENTS.md e as skills /rtk, /ponytail, /coelo-frontend, /coelo-backend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-publicacoes-agenda -b work/etapa2-r07-publicacoes-agenda origin/dev. Grave a primeira revisão da R07 em comunicacao/publicacoes-agenda.json e não pare até T0+4h: trabalhe em ciclo contínuo (terminou um item, vai ao próximo; bloqueio retém só o dependente); a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch), para que nada se perca se a conversa cair.

Usuário: qa-r06-publicacoes@coelo.me (credencial em C:/Users/adrie/Documents/Coelo-backups/qa-r06-publicacoes.env; ler do arquivo, nunca imprimir). Chrome com --user-data-dir=%TEMP%/coelo-chrome-publicacoes, um por vez; porta da lista do CORS. Ordem, sem parar, tudo pela rota real: (1) circulars.create/edit e agenda.create/edit nas telas novas da família Publicação (criar, salvar, reload, publicar); golden comparado a docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/{circular,evento}-{mobile-375,web-1440}.png; (2) circulars.attach pela tela (PNG sintético; upload em coelo-media-prod; leitura por signed_url); (3) P50 = B: tela de resposta à circular no Superadmin (owner responde; resumo das respostas); (4) notices.* e agenda.* que ainda não estejam em E2E no recorte, pela tela; (5) sino do shell (context_notification_recipients/events; leitura e marcação, sem redesenho) só se sobrar tempo. Deltas em docs/reviews/evidence/etapa-2/r07-publicacoes-agenda/deltas-r07-pa.json no formato do aplicador, capturas commitadas. Escreva só em comunicacao/publicacoes-agenda.json e nos seus commits/handoffs; pacote SQL só se indispensável, em candidatos/publicacoes-agenda (faixa 2026091219xxxx ou do dia).

Horário: até T0+4h sem parar; em T0+4h responda à revisão de 10 minutos no JSON. Depois de T0+4h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; a Edge Function circular-media é sua (deploy pelo coordenador); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G7 — «R07 · Operações» — Codex, Luna (esforço médio)

**Resumo:** o mais simples da rodada: Conta settings/theme/sessions pela
tela (200200/200300 em produção), Suporte com abas pela tela, Auditoria
export honesto, warning do analyze em `test_driver/qa_login.dart`.

```text
Você é a conversa «R07 · Operações» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/operacoes.json (revisão 51), docs/reviews/evidence/etapa-2/r06-operacoes/handoff.md, os três md de pendências no recorte das suas famílias, coordenacao.json (T0), AGENTS.md e as skills /rtk, /ponytail, /coelo-frontend, /coelo-backend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-operacoes -b work/etapa2-r07-operacoes origin/dev. Grave a primeira revisão da R07 em comunicacao/operacoes.json e não pare até T0+4h: trabalhe em ciclo contínuo (terminou um item, vai ao próximo; bloqueio retém só o dependente); a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch), para que nada se perca se a conversa cair.

Usuário: qa-r06-operacoes@coelo.me (credencial em C:/Users/adrie/Documents/Coelo-backups/qa-r06-operacoes.env; ler do arquivo, nunca imprimir). Chrome com --user-data-dir=%TEMP%/coelo-chrome-operacoes, um por vez. Ordem, sem parar, tudo pela rota real: (0) corrigir o warning strict_raw_type em apps/superadmin/test_driver/qa_login.dart:40 (flutter analyze limpo); (1) account.settings, account.theme e account.sessions pela tela (listar, Atualizar, Encerrar as outras sessões; reload mantém); (2) support.* que ainda não estejam em E2E no recorte, com as abas de estado (P49) e persistência cards/tabela; (3) plans.* restantes e catalog.validate/sync/publish pela tela; (4) audit.export com botão honesto (Edge Function audit-export sem deploy: registrar) e imports.*/profile_files.* com indisponibilidade honesta conferida; (5) se sobrar tempo, melhorar o composto base (V-16: UI "pobrinha") sem mudar regras nem regravar goldens de outras famílias. Deltas em docs/reviews/evidence/etapa-2/r07-operacoes/deltas-r07-ops.json no formato do aplicador, capturas commitadas. Escreva só em comunicacao/operacoes.json e nos seus commits/handoffs; pacote SQL só se indispensável, em candidatos/operacoes (faixa 2026091220xxxx ou do dia).

Horário: até T0+4h sem parar; em T0+4h responda à revisão de 10 minutos no JSON. Depois de T0+4h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G8 — «R07 · Suítes pré-existentes» — Codex, Luna (esforço médio) — opcional, 3 h, sem colisão com G1–G7

**Resumo:** frente extra que só toca `test/app`, `test/core/config`,
`test/shared`, `lib/dev` e `lib/core/config` do Superadmin (as 49 falhas
pré-existentes registradas desde a R05) e mede a suíte completa; escreve
em `comunicacao/fase0.json`; nunca edita `lib/features` nem
`lib/shared/presentation` (registra em vez de mexer).

```text
Você é a conversa «R07 · Suítes pré-existentes» da Rodada 7 (E2-R07-<AAAAMMDD>) da Etapa 2 do Coelo (Codex, Luna, esforço médio; frente extra de 3 horas). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R07-prompts.md, R06-prompts.md, R05-prompts.md e R04-prompts.md, depois next-round/R05-fechamento.md (seção "Pendências de revisão profunda": suítes pré-existentes) e R06-fechamento.md, docs/reviews/coelo-flutter-pendencias.md (bloco "Estado vigente — Rodada 6"), comunicacao/fase0.json (histórico da Fase 0; você escreve nele com round E2-R07), coordenacao.json (T0), AGENTS.md e as skills /rtk, /ponytail, /coelo-frontend e /coelo-frontend-backend. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-suites -b work/etapa2-r07-suites origin/dev. Grave a primeira revisão em comunicacao/fase0.json (round E2-R07-<AAAAMMDD>, grupo "suites") e não pare até T0+3h: trabalhe em ciclo contínuo; a cada 30 min registre no JSON feito/pendente/commits publicados (git push da sua branch).

Recorte estrito, para não colidir com as sete frentes: apps/superadmin/test/app (dev_menu, import_development_routes, prototype_navigation_routes: 18 falhas pré-existentes), apps/superadmin/test/core/config (4), apps/superadmin/test/shared (underline_tabs e form_action_footer_adoption: 11), o golden institution_directory_pagination_disabled_light_1440 (diferença de 0,21%), e os arquivos de produção que esses testes cobrem: lib/dev, lib/core/config e as rotas /dev. Proibido editar lib/features/**, lib/shared/presentation/**, packages/coelo_ui*/**, goldens de outras famílias, pubspec e qualquer arquivo de outra frente; se a correção exigir isso, registrar no JSON a causa, o arquivo e a proposta (com o teste que provaria) e seguir para o próximo item. Ordem: (1) rodar flutter test apps/superadmin/test/app, test/core/config e test/shared na base limpa e registrar causa por teste (teste desatualizado × código quebrado × golden defasado); (2) corrigir o que for teste desatualizado ou código de /dev (sem mudar comportamento de produção); (3) o golden de 0,21%: conferir a imagem de diferença e regravar só se for ruído de renderização, senão registrar; (4) ao final, flutter test completo do Superadmin (um por vez, sem Chrome) e registrar aprovados/falhos/pulados por diretório, comparando com os 6692/53/11 da R05, em docs/reviews/evidence/etapa-2/r07-suites/censo-suite-completa.md; (5) sem deltas de estado por action_id (esta frente não muda estados do inventário). Não use Chrome nem rota real; sem usuário sintético. Escreva só em comunicacao/fase0.json e nos seus commits/handoffs; commits pequenos em português; um flutter test por vez.

Horário: até T0+3h sem parar; em T0+3h grave a mini-revisão de 10 minutos no JSON (SHA publicado, falhas corrigidas por arquivo, falhas que permanecem com a causa e o dono sugerido, censo da suíte completa). Depois de T0+3h10 não retome. Só o coordenador escreve em dev e nos rastreadores; ele integra a sua branch no ciclo seguinte.
```
