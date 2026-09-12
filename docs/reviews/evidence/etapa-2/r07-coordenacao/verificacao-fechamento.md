---
title: "R07 — verificação da base integrada e do fechamento"
source: "Git das oito frentes; execução C0 na worktree e2-r07-coordenacao; handoffs finais; Supabase functions list"
status: "verificado; limites e residuos explicitados"
generated_at: "2026-09-12"
timezone: "America/Sao_Paulo"
---

# Verificação C0 — R07

Esta evidência distingue medição do coordenador de relato das frentes.
Nenhuma prova local, OPTIONS ou deploy abaixo certifica CRUD/E2E.

## Edge Functions — medido na manhã de 12/09

- circular-media: código b2e61a22e, já integrado desde R06, ainda não estava
  implantado com x-client-info. Antes: OPTIONS 200 nas origens autorizadas,
  sem esse cabeçalho. Teste Deno com o deno.json da função e
  --allow-env --allow-read: **25 aprovados, zero falhas**.
  Deploy por API, sem Docker, confirmado às 09:38:21 BRT:
  **versão 13 ACTIVE**. Depois: OPTIONS 200 com x-client-info para
  https://superadmin.coelo.me e http://127.0.0.1:3014.
  http://127.0.0.1:3016 e origem externa retornam 403 sem allow-origin.
  R08 usa uma origem realmente permitida; CORS do bucket não comprova CORS
  da Edge Function. Upload/reload pela tela continua aberto.
- internal-user-create: versão 2 existia desde a abertura R07, mas OPTIONS
  respondia **500**, pois Response(204) recebia corpo JSON.
  G2 corrigiu no commit fcecf66bf, integrado pelo merge 3c7bf0516:
  corpo nulo no 204 e x-client-info anunciado. C0 executou
  deno test --config packages/coelo_database/supabase/functions/internal-user-create/deno.json --allow-env packages/coelo_database/supabase/functions/internal-user-create/cors_test.ts:
  **3 aprovados, zero falhas**. Deploy confirmado às 09:41:36:
  **versão 3 ACTIVE**. OPTIONS nas origens produtiva e 3014: 204, zero bytes,
  allow-origin correto; origem externa sem allow-origin; POST anônimo: 401.
  Nenhum usuário criado nesta verificação; criação e definição de senha
  pela rota normal continuam abertas.
- Comando dos dois deploys: supabase functions deploy NOME --use-api
  --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database.
  Só essas funções foram implantadas neste fechamento. Nenhum secret novo.
- A listagem remota confirmou ACTIVE: form-media v16, form-export-download
  v15, form-operations v15, moments-media v9, happens-media v5, now-media v5,
  notice-publication-worker v4 e chat-media v3. Textos históricos dizendo
  “sem deploy” não são gates atuais; falta conferir cada fluxo,
  configuração/origem e provedor.

## Integração e testes locais

- G8: revisão estática dos 40 arquivos dos 16 commits desde 7b229593c,
  sem escrita em lib/features ou lib/shared/presentation.
  Nos 24 arquivos do último lote de router, 22 mudanças eram formatação;
  duas atualizavam contratos aprovados. Nenhum skip novo.
- Router integrado antes do fechamento: **434 aprovados, 1 pulado,
  6 falhas de golden** (detalhe de Pessoas, Unidades e Turmas).
- G8 havia classificado Criar modelo de atividade como “non-form wrapper”
  no teste de rodapé. C0 retirou essa exceção: é um formulário com lacuna
  real, que deve permanecer visível no teste e no backlog de G1.
- Analyzer apontou dois imports não usados em
  test/core/config/structure_detail_composition_test.dart; C0 removeu
  somente esses imports. Analyzer final sem issues (192,4s).
  Censo final independente:6727PASS/33FAIL/11SKIP, em426s;
  contratoRPCdaG8 corrigido e4/4PASS; coelo_api/forms134PASS.
  Arquivos/donos e limites em censo-final.md no mesmo diretório.
- Medições locais anteriores do C0, não somáveis entre si: Assiduidade +
  API de Formulários **140 PASS**; Operações **345 PASS + 1 skip**;
  erros + publicador de Momentos **102 PASS**; lote inicial de G8 **87 PASS**;
  lote posterior de identidade/rotas **19 PASS**.
- O censo do G8 bc93f4b6c (6713/42/11) foi conferido pelo JSON bruto.
  O número previsto 6719/36/11 não foi executado por G8 e não é adotado.
  C0 iniciou uma execução completa em apps/superadmin na base conjunta,
  com --file-reporter json:build/r07-c0-full.json; o caminho relativo
  evita o problema de parsing do drive Windows.

## Reconciliação de estado

- G3 confirmou os IDs da reconstrução: attendance.mark, attendance.finish,
  attendance.correct. O alias attendance.entry/complete não é ação nova.
  FE local-green e E2E pending-verification até prova nova; BE done
  preservado, sem alteração SQL. attendance.create não mudou
  (AttendanceNewCallPage intocada).
- people.handle é detalhe do aceite de people.edit, não novo ID.
  Teste local de @ não recertifica Pessoas/Alunos/Usuários.
- people.create ganhou evidência local R07; nenhuma ação foi promovida
  a verified/done/E2E por build, analyzer ou teste isolado.
- Revisões/horários das fontes são preservados como declarados. Campos
  futuros ou antigos não são utilizados como relógio de execução. Por
  exemplo, G8 rev18 declara 09:50, mas o commit foi feito às 09:37:10.
  G1 alegou ausência de T0; ele existia na branch do coordenador desde
  f8290b8dc, com liberação em 7b229593c. A cópia antiga do checkout
  principal não era o canal vigente. .env.local público ausente em outra
  worktree era configuração local a copiar com segurança, não decisão Owner.

## Ambiente e preservação

Docker permanece sem o pipe dockerDesktopLinuxEngine nesta manhã.
As duas árvores de sockets movidas anteriormente foram preservadas fora do
Git; nenhum factory reset, volume, imagem ou VM foi apagado.
Não foi aplicado SQL novo na R07: o próximo lote permanece 56.
Não se afirma que o espelho foi atualizado ou que pgTAP passou nesta rodada.
O próximo gate de ambiente é recuperar o daemon e conferir
supabase_db_coelo_baseline:57322, antes de qualquer novo SQL produtivo.

G8 possuía300PNGsignorados, dosquais204semcorrespondenteC0. Foram
preservados e conferidos porSHA256 emCoelo-backups/r07-worktrees-20260912,
junto dosdemais ignorados relevantes:827arquivos,53.829.920bytes.
Dez worktrees encerradas foram removidas comgitworktreeremove, semforce;
branches preservadas. Sómainprincipal eworktreeC0 permanecem.
Nenhuma evidência ignorada pode ser descartada por “git status limpo”.

## Complemento Owner/G8 e segurança

G8rev19/d4a62918c recebeu64A,5A+(uminferido),6R. Lista nominal em
next-round/R07-decisoes-owner-20260912.md, P53=A e rodapémodeloautorizado.
Regra Circularintercalada registrada naADR0034D20; não é funcionalidade
nova entregue pela aprovação. Métrica visual:46Aanteriores+8IDsnovos=54/231;
53reportado anteriormente incluía7objetos sóR.

Às10:06:51BRT C0rotacionou a senha deqa-r06-estrutura por exposiçãoR06;
AuthAdmin200, novo login verificado, sessão de prova encerrada204.
SomenteQA_PASSWORD noarquivo privado correspondente foi atualizado;
zeroAPIkeysnovas, zeroAuthusersnovos. AntesdoOwnerpedir deixar segurança
para revisão. Nãohouve outras rotações; restante de segurança separado
da entrega, conforme instrução posterior doOwner.
