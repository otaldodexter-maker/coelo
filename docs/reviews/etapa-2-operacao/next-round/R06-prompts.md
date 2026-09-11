---
title: "Rodada 6 — contrato comum e prompts por conversa (2 h de frentes + 30 min de fechamento)"
source: "R05-prompts.md; R05-fechamento.md; coordenacao.json rev 51; ADR 0034 (Decisões 1–17); os três md de pendências (bloco Estado vigente R05); R05-perguntas-ao-owner-20260911.md; artefato de aprovações 2150f92d; ordem do Owner de 11/09/2026 à tarde"
status: "authorized-on-prompt-start; conversations-not-started-by-document-creation"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Rodada 6 — contrato comum

Ponto de entrada de toda conversa da Rodada 6. Cada prompt manda ler este
arquivo, o `R05-prompts.md` e o `R04-prompts.md` (as regras de lá continuam
valendo; aqui está só o que mudou). Nada aqui inicia execução; a conversa
começa quando o Owner cola o prompt. **Toda a R06 roda no Claude com Opus 5 em
esforço médio** (coordenação inclusive).

## Identificação e horários (duração curta)

- Rodada: `E2-R06-<AAAAMMDD>`. Base: `origin/dev` no HEAD que contém este
  arquivo, conferido na abertura com `git fetch`. Raiz
  `C:/Users/adrie/Documents/Coelo`; recorte `apps/superadmin` e o que ele usa.
- **T0** = hora em que o Owner cola o prompt C0 (o coordenador grava T0 no
  `coordenacao.json` e as frentes leem de lá). **T0+20** = abertura das
  frentes (o coordenador gasta os 20 primeiros minutos criando os usuários
  sintéticos por grupo). **Frentes trabalham sem parar até T0+2h** e
  entregam tudo (commits publicados, worktree limpa ou WIP nomeado, deltas em
  arquivo, pacotes SQL, dúvidas). **T0+2h**: o coordenador pede a revisão de
  10 minutos; as frentes respondem no JSON até T0+2h10. **T0+2h30**: o
  coordenador entrega o fechamento no formato fixo. Horário de relógio da
  máquina; em dúvida, a frente pergunta no JSON e continua.
- Com 2 horas, **cada frente recebe uma ordem curta e fecha o máximo dela**;
  o que não couber fica registrado com o primeiro gate. Nada de code review
  profundo; nada de refatoração.

## Usuários sintéticos por grupo (decisão do Owner, 11/09 15:20)

- O coordenador cria na abertura, sem custo, um usuário interno por frente:
  `qa-r06-estrutura@coelo.me`, `qa-r06-acessos@coelo.me`,
  `qa-r06-formularios@coelo.me`, `qa-r06-principal@coelo.me`,
  `qa-r06-realm@coelo.me`, `qa-r06-publicacoes@coelo.me`,
  `qa-r06-operacoes@coelo.me` — pela API de administração do Auth (nunca
  insert em `auth.users`), cada um com perfil interno (padrão do 171200),
  ponte de ator (220400) e membership owner nas instituições sintéticas
  `qa-r04-*` (padrão do 230024), por migration idempotente em
  `candidatos/coordenador` provada no espelho.
- Credencial de cada um só em `C:/Users/adrie/Documents/Coelo-backups/qa-r06-<grupo>.env`
  (ler do arquivo; nunca imprimir, colar em chat, commit, log ou JSON). O
  Codex usa os mesmos arquivos (P37). `qa-r03` continua existindo para a
  coordenação.
- Cada frente usa **só o seu usuário**: Sair, sessões e revogações deixam de
  derrubar as outras. Chrome com `--user-data-dir` próprio por frente
  (`%TEMP%/coelo-chrome-<grupo>`); na abertura o coordenador fecha Chromes
  de CDP órfãos (portas 9xxx) da rodada anterior.

## O que mudou desde a R05 (ler antes de começar)

- **Produção:** lotes 28 a 48 (34 pacotes) e cinco Edge Functions
  (`chat-media` nova; `form-operations`, `form-media`,
  `form-export-download`, `moments-media` reimplantadas). Tudo o que está em
  `migrations/` está em produção; `candidatos/` está vazio.
- **Regras novas nas skills (ler as seções "Rodada 5"):** uma única frente é
  dona de cada Edge Function e de cada família de RPC (nomeada abaixo);
  provar pacote com a ordem real de produção incluindo os lotes dos outros
  grupos; pessoas de serviço nunca são destinatárias; `DELETE`/`UPDATE` em
  função sempre com `WHERE`; célula de tabela alinhada pelo composto e quem
  muda o composto regrava os goldens de todas as famílias; deltas só em
  arquivo no formato do aplicador; frentes de backend puro sem o MCP `dart`.
- **Respostas do Owner (16:45) já anotadas** em `coordenacao.json` →
  `respostasDoOwnerR05` (17 telas, IMP-R05-2, P43–P50) e resumidas no prompt de
  cada frente abaixo; executar dentro do ciclo. **Família visual Publicação:**
  os publicadores do Principal (Acontece, Momentos, Agora) e Lançar faltas,
  Circulares e Eventos seguem a família Publicação registrada em
  `.agents/skills/coelo-ui/references/principal-visual-surfaces.md` (seção
  "Família Publicação"), com as 12 telas novas **aprovadas pelo Owner em
  11/09 às 17:19** no canvas "Publicar no Coelo" (versão 4) e guardadas em
  `docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/`
  (`<tela>-mobile-375.png` e `<tela>-web-1440.png`); no web a tela vive
  dentro do contêiner principal do Superadmin; o wizard administrativo não é
  usado nelas.
- **4 falhas novas de teste da R05 a corrigir na abertura** (donos abaixo):
  `fail_closed_screens_with_data_probe_test` Importações 1440/375 (G7),
  `principal_real_route_test` P28 (G4), `health_care_golden_test` tabs hover
  (G3). As 49 restantes já falhavam antes e ficam registradas.
- **Memória:** máximo um Chrome por conversa e um `flutter test` por vez;
  fechar Chrome e `dart` ao fim de cada prova.

## Estado de partida (fechamento da R05, 16:00 de 11/09)

| Camada | Estado |
| --- | --- |
| Front-end `verified` | 138/231 (59,74%) |
| Front-end `local-green` (das 93 ainda não `verified`) | 23/93 (24,73%) |
| Front-end aprovação visual do Owner | 53/231 (22,94%) |
| Back-end `local-green` (das 92 ainda não `done`) | 46/92 (50,00%) |
| Back-end SQL aplicado em produção | 178/224 (79,46%) |
| Back-end `done` | 132/224 (58,93%) |
| E2E `verified-e2e` | 105/199 (52,76%) |

## Skills obrigatórias

`rtk`, `ponytail`, `coelo-frontend`, `coelo-backend`, `coelo-frontend-backend`,
`coelo-ui`, `coelo-knowledge`, `flutter-dart-code-review`, `supabase`;
`cloudflare`/`wrangler` só no pacote autorizado. O resto do contrato
(comunicação por JSON, worktree por conversa, mini-revisão, régua do MVP,
autorizações) está em `R04-prompts.md` e `R05-prompts.md`.

---

# Prompts por conversa

Colar cada bloco em uma conversa nova. Ordem: C0 primeiro; as frentes só
depois de o coordenador gravar em `coordenacao.json` que os usuários
`qa-r06-*` existem (T0+20). Toda a R06 roda no Claude com Opus 5 em esforço
médio.

## C0 — «R06 · Coordenação» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Coordenação» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois next-round/R05-fechamento.md, comunicacao/coordenacao.json (revisão 51), os três md de pendências em docs/reviews (bloco "Estado vigente — Rodada 5"), decisions/0034-mvp-remote-application-and-acceptance-bar.md (Decisões 1–17), next-round/R05-perguntas-ao-owner-20260911.md, AGENTS.md e as skills rtk, ponytail, coelo-backend, coelo-frontend, coelo-frontend-backend, coelo-ui e coelo-knowledge. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-coordenacao -b work/etapa2-r06-coordenacao origin/dev. Nunca edite o checkout principal. Registre posse em coordenacao.json (revisão 52, round E2-R06-<AAAAMMDD>, T0 pelo relógio da máquina) e agende /loop 20m Leia os JSONs das frentes, emita ACK, aplique pacotes verdes, integre e atualize rastreadores; liste ao Owner em uma linha as conversas sem revisão nova há mais de 20 minutos e mande-as retomar.

Primeiros 20 minutos, antes de liberar as frentes: (a) conferir se o Owner salvou versão nova do artefato de aprovações (https://claude.ai/code/artifact/2150f92d-3c61-4f8e-a67c-07cb8d3983fb; a versão 2 já está anotada em coordenacao.json → respostasDoOwnerR05 e na ADR 0034 Decisão 18) (o canvas "Publicar no Coelo" já foi aprovado às 17:19 e as imagens estão em docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/ — não precisa reler); gravar ownerVisualApproval por action_id no inventário para as telas com A; (b) criar os sete usuários qa-r06-<grupo>@coelo.me pela API de administração do Auth (senha gerada localmente, gravada só em Coelo-backups/qa-r06-<grupo>.env), escrever em candidatos/coordenador (faixa 2026091123xxxx ou do dia) a migration idempotente que dá a cada um perfil interno, ponte de ator e membership owner nas três instituições sintéticas qa-r04-*, provar no espelho coelo_baseline (reconstruir com db reset da baseline + psql da ordem-de-aplicacao-producao.txt se estiver defasado), aplicar em produção (dump por lote, ledger, mover para migrations/), fechar os Chromes de CDP órfãos (portas 9xxx) e gravar em coordenacao.json "usuarios qa-r06 prontos" com T0+20 — só então o Owner cola os prompts das frentes.

Responsabilidades (iguais à R05): única escritora de dev, inventário e três rastreadores; integrar work/etapa2-r06-* por merge, flutter analyze e testes das famílias tocadas, node docs/reviews/apply-tracker-delta.cjs <deltas.json> e validate-trackers.cjs, commits pequenos em português, push em dev; aplicar em produção cada pacote verde de candidatos/<grupo>/ na ordem da fila (preflight no espelho na ordem real, dump por lote em Coelo-backups/schema-producao-<data>-loteNN.sql, supabase db query --linked -f, ALTER TYPE ADD VALUE em chamada separada, ledger, mover, anotar a ordem, ligar a chave de composição; um só dono por Edge Function: deploy é seu); ler os sete JSONs, ACK e recibo por revisão, responder bloqueios; segredos nunca em chat, commit, log ou JSON, segredos sem custo você cria e registra na skill coelo-backend; máximo um Chrome e um flutter test por vez por conversa. Em T0+2h peça em coordenacao.json a revisão de 10 minutos; de T0+2h10 a T0+2h30 encerre: integrar tudo, status limpo, worktrees removidas depois de integradas (branches preservadas), rastreadores e inventário regenerados e validados, bloco "Estado vigente — Rodada 6" nos três md (R05 vira anterior), skills e ADR 0034 com regra ou decisão nova, portão coelo-knowledge, next-round/R06-fechamento.md e R06-perguntas-ao-owner-<data>.md (visuais numa página lado a lado R/A com botão Salvar, como o artefato 2150f92d), e o fechamento ao Owner no formato fixo (FE verified /231, FE local-green sobre as ainda não verified, FE aprovação visual /231, BE local-green sobre as ainda não done, BE SQL em produção /224, BE done /224, E2E /199; duas casas; sem percentual composto; aprovação visual nunca vira verified/done/E2E). Ao final: dados sintéticos criados (limpeza só no fim da Etapa 2) e chaves criadas. Não pare até T0+2h30 ou ordem do Owner.
```

## G1 — «R06 · Estrutura» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Estrutura» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/estrutura.json (revisão 53; campo respostaARevisaoFinal e o gate do @ na rev 45), docs/reviews/evidence/etapa-2/r05-estrutura/handoff.md, os três md de pendências no recorte das suas famílias, coordenacao.json (respostasDoOwnerR05 e T0), AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-estrutura -b work/etapa2-r06-estrutura origin/dev. Grave a primeira revisão da R06 em comunicacao/estrutura.json e agende /loop 15m Retome o recorte da Rodada 6 sem parar: próximo item executável, atualize estrutura.json, não encerre o turno antes de T0+2h.

Usuário: qa-r06-estrutura@coelo.me (credencial em Coelo-backups/qa-r06-estrutura.env; Chrome com --user-data-dir próprio; um Chrome por vez). Recorte (49 ações; 23 em E2E). Ordem, sem parar: (1) @ no cliente de Unidades, Turmas e Atividades: enviar handle no payload dos RPCs v2 de criação (contrato 211100) e a ação "Alterar @" na edição com superadmin_structure_handle_set_v1 (trava de 30 dias com mensagem honesta); prova na rota real; (2) groups.list, groups.members e groups.location; units.list/error/access-denied; (3) Avaliações: pacote em candidatos/estrutura que dê vínculo profissional ao qa-r06-estrutura numa turma sintética (ou reutilizar a de qa-r03) e provar assessments.entry/gradebook/close/reopen/detail e activities.assessment/publish na rota real (P36: publicar exige turma); (4) locations.list e locations.detail-links; (5) os 9 goldens de activity_golden_test que já falhavam antes da R05: conferir a causa nas imagens de falha e regravar só se a diferença for regra transversal já aprovada (Pesquisar no menu, rodapé, sem chat, composto), senão registrar; (6) institutions.status/files/error/access-denied. Deltas em docs/reviews/evidence/etapa-2/r06-estrutura/deltas-r06-estrutura.json no formato do aplicador (certificacao com arquivo em docs/...). Escreva só em comunicacao/estrutura.json e nos seus commits/handoffs.

Horário: até T0+2h sem parar; em T0+2h responda à revisão de 10 minutos no JSON (SHA publicado, fechado por action_id com prova, aberto com o primeiro gate, deltas, pacotes, dúvidas ao Owner com imagens lado a lado, dados sintéticos, chaves). Depois de T0+2h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/estrutura (faixa 2026091218xxxx ou do dia); nenhum segredo em Git, chat ou JSON; commits pequenos em português.
```

## G2 — «R06 · Acessos e Pessoas» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Acessos e Pessoas» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/acessos-pessoas.json (revisão 137), docs/reviews/evidence/etapa-2/r05-acessos-pessoas/handoff.md, os três md de pendências no recorte das suas famílias, coordenacao.json (respostasDoOwnerR05: P45 e P46), AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-acessos-pessoas -b work/etapa2-r06-acessos-pessoas origin/dev. Grave a primeira revisão da R06 em comunicacao/acessos-pessoas.json e agende /loop 15m Retome o recorte da Rodada 6 sem parar: próximo item executável, atualize acessos-pessoas.json, não encerre o turno antes de T0+2h.

Usuário: qa-r06-acessos@coelo.me (credencial em Coelo-backups/qa-r06-acessos.env). Recorte (32 ações; 11 em E2E). Ordem, sem parar, tudo pela rota real: (1) Convites: create/detail/resend/revoke pela tela (backend done); (2) Usuários internos: list/create/edit/suspend (create está fail-closed: abrir com a ponte de ator; P46 se o Owner disse sim: @ do usuário interno pela pessoa de serviço); (3) Alunos: link/transfer/edit/revoke pela tela (backend done; hotfix do safeupdate em produção); (4) Perfis de acesso edit/assign/delete e Modelos edit/duplicate (P45 conforme a resposta); (5) people.create e people.edit (create fail-closed: abrir); (6) @ de pessoas na tela de Pessoas e de Alunos (visível e editável por quem responde pela pessoa, com disponibilidade enquanto digita e trava de 30 dias). Respostas do Owner: P45 = B (modelo de sistema criado pelo Superadmin pode ser excluído, conforme hierarquia, como owner); P46 = A (@ do usuário interno pela pessoa de serviço); V-11 A+ (diretório de Perfis: sem dados de demonstração no app real e card Criar sempre presente em cards e tabela, mesmo vazio); V-13 e V-14 aprovados. Deltas em docs/reviews/evidence/etapa-2/r06-acessos-pessoas/deltas-r06.json no formato do aplicador. Escreva só em comunicacao/acessos-pessoas.json e nos seus commits/handoffs.

Horário: até T0+2h sem parar; em T0+2h responda à revisão de 10 minutos no JSON. Depois de T0+2h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/acessos-pessoas (faixa 2026091217xxxx ou do dia); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G3 — «R06 · Formulários, Cuidado e Rotina» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Formulários, Cuidado e Rotina» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/formularios-cuidado-rotina.json (revisão 46) e comunicacao/formularios-cuidado-rotina-handoff.md, os três md de pendências no recorte das suas famílias, comunicacao/realm-interno.json (contratoFormsFiles e edgeFunctions.form-media), coordenacao.json (respostasDoOwnerR05), AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-formularios-cuidado-rotina -b work/etapa2-r06-formularios-cuidado-rotina origin/dev. Grave a primeira revisão da R06 em comunicacao/formularios-cuidado-rotina.json e agende /loop 15m Retome o recorte da Rodada 6 sem parar: próximo item executável, atualize formularios-cuidado-rotina.json, não encerre o turno antes de T0+2h.

Usuário: qa-r06-formularios@coelo.me (credencial em Coelo-backups/qa-r06-formularios.env). Recorte (43 ações; 26 em E2E). Ordem, sem parar: (0) corrigir health_care_golden_test "profile directory tabs hover and table evidence" (falha nova da R05: conferir se é o composto de tabela e regravar após conferir); (1) Medicação create/detail/edit/evidence e health-care.list pela rota real; (2) Rotina edit/publish/list; (3) Segurança infantil list/child e a prova do balão de chat desligado em Lançar/Concluir chamada; (4) Arquivos de Formulários pela tela: forms.upload/resolve-file/expire-file/delete-file com a form-media (question-image em R2 já implantada; para respostas, trocar o cliente para upload_url/required_headers e só então pedir ao coordenador para ligar COELO_FORMS_MEDIA_PROVIDER=r2); (5) forms.location-question e forms.location-answer; (6) tela de políticas macro da unidade (Segurança infantil e Medicação, RPCs superadmin_unit_care_policy_get_v1/set_v1 do lote 36) se sobrar tempo. Respostas do Owner: V-15 A+ (Rotina: card Criar modelo de rotina e Criar rotina sempre presentes; na tabela, ações duplicar e arquivar como no card do modelo); V-12 aprovado. (7) Lançar chamada segue a família Publicação, aprovada pelo Owner às 17:19: reconstruir attendance.entry/complete sobre a referência docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/lancar-chamada-{mobile-375,web-1440}.png (segmentos P/F/A, Marcar todos presentes, observação por aluno, resumo no web, sem balão de chat), com golden novo comparado a essas imagens e prova na rota real. Deltas em docs/reviews/evidence/etapa-2/r06-formularios-cuidado-rotina/deltas-r06-fcr.json. Escreva só em comunicacao/formularios-cuidado-rotina.json e nos seus commits/handoffs.

Horário: até T0+2h sem parar; em T0+2h responda à revisão de 10 minutos no JSON. Depois de T0+2h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/formularios-cuidado-rotina (faixa 2026091222xxxx ou do dia); a Edge Function form-media é sua (deploy pelo coordenador); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G4 — «R06 · Principal, Chat e Sistema» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Principal, Chat e Sistema» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/principal-chat-sistema.json (revisão 29), docs/reviews/evidence/etapa-2/r05-principal-chat-sistema/ (handoff, deltas e skills-deltas), os três md de pendências no recorte das suas famílias, comunicacao/realm-interno.json (contratoChatAttach), coordenacao.json (respostasDoOwnerR05: P47, P48 e as telas do Principal), AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-principal-chat-sistema -b work/etapa2-r06-principal-chat-sistema origin/dev. Grave a primeira revisão da R06 em comunicacao/principal-chat-sistema.json e agende /loop 15m Retome o recorte da Rodada 6 sem parar: próximo item executável, atualize principal-chat-sistema.json, não encerre o turno antes de T0+2h.

Usuário: qa-r06-principal@coelo.me (credencial em Coelo-backups/qa-r06-principal.env). Recorte (35 ações; 12 em E2E). Ordem, sem parar: (0) corrigir principal_real_route_test "offers the profile selector (P28)" (falha nova da R05); (1) Cardápios conforme P47 (se A: remover o fail-closed de tenant no cliente; o servidor valida) e provar list/create/edit/model-create/model-edit/publish na rota real; (2) Momentos create/publish/remove e Agora create/publish/expire com mídia (moments-media corrigida em 15:22; dirigir o compositor por Key/semântica, não por coordenadas; Stream só no Agora, 24 h); (3) chat.create-group pela UI e chat.attach no cliente (contrato prepare/authorize_finalize/read da chat-media já implantada, sem Stream); (4) principal.profile-edit e principal.for-you na rota real; (5) errors.403/404/409/500/503/retry pela rota real; (6) P48 = A: pacote em candidatos/principal-chat-sistema que distingue owner → institution_admin e operations → leitura no sincronizador 130000. Respostas do Owner (P47 = A confirmado): V-1 Perfil A+ (avatar clicável abre o Agora do perfil; contorno em degradê laranja quando há Agora não visto; sombra do círculo igual à do menu flutuante; botão Acompanhar sumiu — voltar); V-2 Para Você A+ (degradê dos cards atrapalha a leitura sobre a imagem; clique do responsável não leva a lugar algum por enquanto); V-3 Acontece A+ (no mobile o contêiner do feed sem o espaçamento e cantos arredondados do padrão; foto esticada perdendo qualidade no mobile e web; separação Agora→menu e Acontece→cards do Agora sem capricho; conferir fontes e cores do design system); V-4/V-5/V-6 (publicadores) REPROVADOS: o estilo de publicação do Principal não usa o wizard — reconstruir sobre a família Publicação (coelo-ui, seção "Família Publicação") conforme as telas aprovadas pelo Owner às 17:19 em docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/ (agora-, acontece-, momentos- em mobile-375 e web-1440; no web dentro do contêiner principal do Superadmin, título "Sua publicação", rodapé em card); é o item (2) do seu recorte: primeiro a tela, depois a prova de create/publish na rota real; golden novo comparado a essas imagens. Deltas em docs/reviews/evidence/etapa-2/r06-principal-chat-sistema/deltas-r06-pcs.json. Escreva só em comunicacao/principal-chat-sistema.json e nos seus commits/handoffs.

Horário: até T0+2h sem parar; em T0+2h responda à revisão de 10 minutos no JSON. Depois de T0+2h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/principal-chat-sistema (faixa 2026091213xxxx ou do dia); as Edge Functions happens-media, now-media e moments-media são suas (deploy pelo coordenador); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G5 — «R06 · Realm interno e segurança» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Realm interno e segurança» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/realm-interno.json (revisão 38), docs/reviews/evidence/etapa-2/r05-realm-interno/ (handoff, prova-producao, skills-deltas), docs/reviews/coelo-supabase-pendencias.md integralmente, decisions/0034 (Decisões 13, 15, 16, 17), AGENTS.md e as skills rtk, ponytail, coelo-backend, coelo-frontend-backend, coelo-knowledge, supabase e supabase-postgres-best-practices. Não carregue o MCP dart. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-realm-interno -b work/etapa2-r06-realm-interno origin/dev. Grave a primeira revisão da R06 em comunicacao/realm-interno.json e agende /loop 15m Retome o recorte da Rodada 6 sem parar: próximo item executável, atualize realm-interno.json, não encerre o turno antes de T0+2h.

Recorte (backend transversal, candidatos/realm-interno na faixa 2026091221xxxx ou do dia; pgTAP verde no seu descartável com a ordem real de produção incluindo os lotes de hoje; o coordenador aplica). Ordem: (1) raiz da ponte de ator: a membership interna escopada em instituição é espelhada como platform_membership sem escopo (220400/130000); provar por família com identidade escopada (Rotina, Cuidado, Assiduidade, Cardápios, Suporte, Pessoas, Formulários — os 12 helpers listados no seu handoff) e entregar o pacote que corrige a raiz (espelho com escopo e helpers que consultam o realm interno antes de has_platform_permission), mantendo 211200 e todas as suítes verdes; (2) usuário sintético por grupo: se o coordenador ainda não tiver aplicado a semente dos qa-r06-*, escreva-a para ele (perfil interno + ponte + memberships, idempotente por e-mail); (3) 180060: decidir com o coordenador se has_activity_capability volta a não exigir instructor (mudança de comportamento) ou registrar como decisão de produto; (4) code review dos pacotes da R05 que ficaram sem segunda leitura (210500 notificações, 211100 handles) só se sobrar tempo. Segredos sem custo você cria no Vault; valor nunca em chat, commit, log ou JSON. Escreva só em comunicacao/realm-interno.json e nos seus commits/handoffs; contrato no JSON antes de o coordenador aplicar.

Horário: até T0+2h sem parar; em T0+2h responda à revisão de 10 minutos no JSON. Depois de T0+2h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores e aplica em produção; um projeto Supabase descartável por conversa, parado ao terminar; commits pequenos em português.
```

## G6 — «R06 · Publicações e Agenda» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Publicações e Agenda» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/publicacoes-agenda.json (revisão 43), docs/reviews/evidence/etapa-2/r05-publicacoes-agenda/ (handoff, skill-deltas), os três md de pendências no recorte das suas famílias, coordenacao.json (respostasDoOwnerR05: agenda_create_*, P50), AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-publicacoes-agenda -b work/etapa2-r06-publicacoes-agenda origin/dev. Grave a primeira revisão da R06 em comunicacao/publicacoes-agenda.json e agende /loop 15m Retome o recorte da Rodada 6 sem parar: próximo item executável, atualize publicacoes-agenda.json, não encerre o turno antes de T0+2h.

Usuário: qa-r06-publicacoes@coelo.me (credencial em Coelo-backups/qa-r06-publicacoes.env). Recorte (24 ações; 21 em E2E). Ordem, sem parar: (1) circulars.attach pela tela (gancho SuperadminQaHooks.circularFilePicker com PNG sintético no qa_main; upload em coelo-media-prod, bloco de mídia no v2, publicação e leitura por signed_url); (2) circulars.respond conforme P50 (A: só o resumo das respostas no Superadmin, com o estado FE registrado como verified pelo resumo; B: tela de resposta); (3) agenda.location pela tela com o seletor de contexto (A+ dos goldens agenda_create_* conforme a resposta do Owner); (4) aplicar as respostas do Owner às telas de Avisos e Circulares da página de aprovações; (5) se sobrar tempo: notificações no sino (context_notification_events do lote 36) no shell — leitura e marcação, sem redesenho. Respostas do Owner: P50 = B (tela de resposta à circular também no Superadmin: "mediante a hierarquia, como owner sempre pode tudo"); V-7 Criar evento A+ (wizard no padrão de Instituições, sem fundo cinza); V-8 Lista A+ (no mobile o toggle calendário/lista novo ficou melhor; no web o toggle do R era melhor — restaurar no web); V-9 e V-10 aprovados. (6) Circulares e Eventos ganham telas de publicação na família Publicação, aprovadas pelo Owner às 17:19: reconstruir circulars.create/edit sobre circular-{mobile-375,web-1440}.png e agenda.create/edit sobre evento-{mobile-375,web-1440}.png em docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/ (substitui o wizard do V-7; a resposta A+ do V-7 sobre fundo cinza fica atendida pela família), golden novo comparado a essas imagens e prova na rota real. Deltas em docs/reviews/evidence/etapa-2/r06-publicacoes-agenda/deltas-r06-pa.json. Escreva só em comunicacao/publicacoes-agenda.json e nos seus commits/handoffs.

Horário: até T0+2h sem parar; em T0+2h responda à revisão de 10 minutos no JSON. Depois de T0+2h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/publicacoes-agenda (faixa 2026091219xxxx ou do dia); a Edge Function circular-media é sua (deploy pelo coordenador); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```

## G7 — «R06 · Operações» — Claude, Opus 5 (esforço médio)

```text
Você é a conversa «R06 · Operações» da Rodada 6 (E2-R06-<AAAAMMDD>) da Etapa 2 do Coelo (Claude, Opus 5, esforço médio). Leia integralmente C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R06-prompts.md, R05-prompts.md e R04-prompts.md, depois comunicacao/operacoes.json (revisão 38), docs/reviews/evidence/etapa-2/r05-operacoes/handoff.md, os três md de pendências no recorte das suas famílias, coordenacao.json (respostasDoOwnerR05: P43, P44, P49, IMP-R05-2), AGENTS.md e as skills rtk, ponytail, coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, flutter-dart-code-review, supabase. Crie sua worktree: git fetch origin && git worktree add C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-operacoes -b work/etapa2-r06-operacoes origin/dev. Grave a primeira revisão da R06 em comunicacao/operacoes.json e agende /loop 15m Retome o recorte da Rodada 6 sem parar: próximo item executável, atualize operacoes.json, não encerre o turno antes de T0+2h.

Usuário: qa-r06-operacoes@coelo.me (credencial em Coelo-backups/qa-r06-operacoes.env). Recorte (38 ações; 14 em E2E). Ordem, sem parar: (0) corrigir fail_closed_screens_with_data_probe_test "Importações lays out with data" 1440 e 375 (falha nova da R05, Importações no composto); (1) Conta: settings e theme pela rota real; sessões conforme P43 = B: tela mínima no MVP (lista + revogar todas) com Edge Function sobre o Admin API do Auth (candidato + função, deploy pelo coordenador); (2) Suporte conforme P49 = A: abas de estado no lugar do filtro Status e persistir cards/tabela, prova na rota real; IMP-R05-2 aprovado; (3) Planos activate/assign pela rota real (backend pending: contrato mínimo com RLS em candidatos/operacoes se faltar); (4) Catálogo conforme P44 = B: atualizar o índice e os fingerprints agora; V-16 A+ (composto base sem fundo cinza; UI ainda "pobrinha", melhorar o que couber); (5) texto honesto da página genérica de recurso adiado ("Disponível depois do MVP" em vez de 503) se o Owner aprovou em IMP-R05-2; (6) audit.export pela rota real se sobrar tempo (Edge Function audit-export sem deploy: pedir ao coordenador). Deltas em docs/reviews/evidence/etapa-2/r06-operacoes/deltas-r06-ops.json. Escreva só em comunicacao/operacoes.json e nos seus commits/handoffs.

Horário: até T0+2h sem parar; em T0+2h responda à revisão de 10 minutos no JSON. Depois de T0+2h10 não retome. Só o coordenador escreve em dev, inventário e rastreadores; pacote verde nasce em candidatos/operacoes (faixa 2026091220xxxx ou do dia); nenhum segredo em Git, chat ou JSON; um Chrome e um flutter test por vez; commits pequenos em português.
```
