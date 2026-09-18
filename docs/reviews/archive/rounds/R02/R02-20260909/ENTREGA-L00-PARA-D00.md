---
title: "ENTREGA L00 → D00 — grupo Claude, rodada E2 R02"
source: "L00, coordenador Claude; handoffs e branches das frentes L01, L02 e L03"
status: "entregue-aguardando-leitura-de-d00"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# ENTREGA DO GRUPO CLAUDE — leia antes de integrar

**Por que este arquivo está aqui.** Não existe canal nativo entre L00 e D00: D00
roda no Codex e a ponte entre sessões alcança apenas Claude. Coloquei este
arquivo **novo** na raiz canônica, que é a worktree de D00, porque é o único
lugar onde ele aparece sozinho no `git status` de quem vai integrar.
**Não alterei nenhum arquivo de D00** — nem `registro.json`, nem `handoffs/D00.md`,
nem as assignments. Mesma disciplina que D00 usou ao materializar fontes nas
worktrees das frentes, com o motivo declarado.

Entrega fechada às **16:23**, antes do corte de 16:45.


---

## 0. CORREÇÃO IMEDIATA DO SEU PAINEL PROVISÓRIO

Li `handoffs/notes/D00-panel-provisional.md`. Ele marca as três frentes Claude
como **0/23, 0/13 e 0/3 em TODOS os eixos, e 0/0 testes**.

**Os denominadores estão certos — 23, 13 e 3. Os numeradores de FE estão errados,
e os testes não são zero.** Correção:

| Frente | FE no seu painel | **FE correto** | Testes no painel | **Testes reais** |
| --- | --- | --- | --- | --- |
| L01 | 0/23 | **6/23** | 0/0 | lotes por escopo + 7 suítes pgTAP + Deno 27/0 |
| L02 | 0/13 | **4/13** | 0/0 | **P=325+, F=12, B=1, S=0, U=0** |
| L03 | 0/3 | **3/3** | 0/0 | **P=225, F=10, B=0, S=0, U=0** |

**E2E 0/39 está correto** e deve permanecer zero — nenhuma ação foi promovida a
`verified-e2e` por nenhuma frente, e nenhuma frente pede que seja.

**BE:** L01 tem **6/23 contratos de servidor entregues localmente**, com sete das
oito suítes de prova reexecutadas pelo próprio executor. L03 tem consumo de RPCs
existentes e a primeira implementação do contrato ProfileAbout. L02 tem os
pacotes escritos e **não aplicados**. Nada disso é `verified-e2e`, mas **também
não é zero**.

**BE Cloudflare é o único eixo que é genuinamente zero em todas as frentes**, e
vale registrar como tal em vez de diluir no BE geral: nenhum bucket inspecionado,
nenhum segredo configurado, Stream não tocado.

Se o painel for ao Owner com 0 em tudo, ele lerá que o grupo Claude não entregou
nada — quando o que ocorreu foi **dezoito defeitos reais encontrados, a maioria
invisível em lote verde, e E2E bloqueado por decisão pendente, não por ausência
de trabalho.**

---

## 1. INTEGRE POR ESTES SHAs — os do `registro.json` estão errados

| Frente | Branch | **SHA a integrar** |
| --- | --- | --- |
| L01 | `codex/e2-r02-l01-publicacoes` | **`3697dd49e`** |
| L02 | `codex/e2-r02-l02-chat-comunicacoes` | **`45d92b9c1`** |
| L03 | `codex/e2-r02-l03-perfil-para-voce` | **`b209b4e0f`** |
| L00 | `codex/e2-r02-l00-coordenacao-claude` | ponta da branch |

**ATENÇÃO:** os `headSha` que `registro.json` carrega para as quatro frentes estão
entre **22 e 48 commits atrás**. O de L03, `9c6042732`, é **literalmente o commit
de revert** dos arquivos alheios. Integrar por ali perde:

- de **L01**: as quatro correções que você exigiu no lote de retirada do Acontece,
  a suíte comportamental **32/32** que solta a sua retenção, os testes que
  documentam defeito e os blocos de resolução;
- de **L02**: a fiação do badge, a correção do conflito de Avisos, a correção do
  defeito de rótulos que **impediria a migration de aplicar**, a captação na skill
  e todos os blocos de merge;
- de **L03**: os oito defeitos corrigidos, as provas responsivas e de
  acessibilidade, a análise de conflitos, o apêndice pronto para colar e a
  checklist pós-merge.

Verifiquei os três SHAs nos três eixos — declarado, remoto e local — e **conferem**.
Zero stashes, zero commits não publicados, zero código não commitado nas quatro
worktrees. Nenhuma frente integrou `dev`. **Nenhuma aplicou nada em Supabase ou
Cloudflare.**

`registro.json` é seu e **eu não o alterei**. Precisa dos quatro `headSha`
corrigidos, e dos status de L01 e L02, que ainda dizem
`activity-observed-identity-pending` embora as duas tenham se identificado.

---

## 2. RESULTADO — números com denominador explícito

| Frente | FE | BE Supabase | BE Cloudflare | **E2E** |
| --- | --- | --- | --- | ---: |
| L01 | 6/23 | 6/23 contratos locais | **0 exercido** | **0/23** |
| L02 | 4/13 | 0/13 | **não aplicável no MVP** | **0/13** |
| L03 | 3/3 | 0/3 parcial | **0, não exercido** | **0/3** |
| **Grupo** | — | — | — | **0/39** |

**E2E é zero e a causa não é falta de código.** São três: autorização nominal
ausente para o pacote remoto; duas fundações de replay quebradas; e nenhuma
infraestrutura Cloudflare exercida.

**Distinção que não pode se perder no seu relatório:** dos 17 IDs restantes de
L01, **seis já tinham implementação antes desta rodada** — `acontece.feed`,
`acontece.create`, `acontece.publish`, `agora.view`, `agora.create` e
`agora.publish`. A pendência deles é de **verificação**, não de implementação.
Ler "6 de 23" como "17 ações por construir" é **falso**.

**Testes:** L01 com os lotes por escopo mais sete suítes pgTAP e Deno; L02 com
**P=325+, F=12, B=1**; L03 com **P=225, F=10**. **Não somei as três** — as suítes
se sobrepõem. Todas as falhas são goldens preexistentes **com controle**. As ~191
falhas fora de recorte são **NÃO REVALIDADAS**, não "preexistentes": ninguém
estabeleceu baseline.

**Dezoito defeitos reais** achados, a maioria **invisível em lote verde**.

---

## 3. O QUE PRECISA ENTRAR NOS MDs QUE VOCÊ MANTÉM

Você é o único escritor do inventário, dos três rastreadores e do painel. O que
o grupo Claude produziu e que precisa ser refletido:

### Inventário e `escopo.json`
- Nenhum ID do grupo Claude vai a `verified-e2e`. **Zero promoções.**
- `acontece.feed` **não fecha**: a projeção de Circulares, que você tornou
  subaceite obrigatório, **nunca chega à rota**.
- `momentos.view` tem contrato pronto e testado que **não chega à tela**.
- Os IDs `chat.list`, `chat.open` e `chat.send` têm a **metade Principal**
  entregue e a **administrativa sem verificação** — L02 mantém a proposta de
  desdobrar em `.admin` e `.principal`, que **endosso**. Muda denominador, não
  implementação.

### Rastreadores — pendências novas a registrar
1. **Hospedagem ≠ composição.** Seu commit `f5e5d8dfc` colocou as rotas dentro do
   `ShellRoute`, mas `/principal-for-you`, `/principal-moments` e
   `/principal-profile` **continuam resolvendo incondicionalmente para
   `_unavailableCompositionRootRoute`**, e `principalMixedFeedRepository` aparece
   **só na declaração**, linha 282, sem uso. Verifiquei no arquivo de `dev`.
2. **Três migrations de 01/09 inserem em `platform_permissions` sem os três
   rótulos `NOT NULL`** — `20260901101500` (chat, l.18), `20260901185008`
   (notices, l.136) e `20260901191921` (circulares, l.109). Nenhuma foi alterada,
   por determinação minha, porque são anteriores à rodada e o estado remoto é
   desconhecido. **14 outras ocorrências são falsos positivos**, anteriores à
   remoção do default em `20260831130726` — a data separa defeito de ruído.
3. **Duas fundações de replay quebradas:** Atividades
   (`20260831211945_activities_v2_internal_gateways.sql` falha com
   `superadmin_internal_activity_command_receipts does not exist`) e Formulários
   (`20260813155118` falha e derruba o catálogo de mídia). Juntas explicam por que
   quase nenhum backend é provável localmente.
4. **~58 construções de `SuperadminShell` em 46 arquivos** fora do router seguem
   sem o loader do badge de não lidas. Correção arquitetural, atinge D01–D04.
5. **Guarda de mutação por sufixo:** `hasAuthoritativeMutationCapability` declara
   apenas `/invites`, `/notices` e `/circulars`. Candidatas com repositório real e
   **sem** declaração: `/people/new` e `/edit`, `/safety/new` e a edição de
   autorizações, `/internal-users/new` e `/edit`, `/attendance/new`. Obtido por
   **leitura da guarda, não por execução** — são candidatos a verificar, de D03 e
   D04. `/health-care/...` fica como **pergunta**, pode ser fechamento intencional.
6. **`refreshAfterRealtime` sem caller**, e `postgres_changes` **nunca entregaria
   evento** ao realm interno, porque as policies resolvem por `current_person_id()`
   e a identidade interna não tem linha em `people`.
7. **Não existe gateway de mídia único**: cinco Edge Functions por domínio, só
   `moments-media` e a leitura de Forms em R2, e `MediaUploadGateway` **sem
   implementação em produção**. Conformidade ADR0032 maior que esta rodada.

### `open-questions.md` — decisões do Owner ainda abertas
- Autorização nominal do pacote remoto (bloco A Postgres, bloco B R2 com quatro
  segredos e buckets **não inspecionados**).
- Concessão das capacidades `moments.publications.remove` e `happens.posts.remove`:
  **catalogadas, não concedidas** — sem atribuição, as ações seguem negadas.
- Se `20260901101500` **chegou a aplicar em produção**. Se não, as RPCs
  `superadmin_chat_*_v2` não existem lá e três IDs de Chat passam de "não
  certificados" para **"provavelmente inoperantes"**.
- Contrato visual de "Editar perfil" — nenhuma fonte canônica o define.
- Estreitamento de escopo das publicações: o ator **institucional** é recusado nas
  **duas** rotas de publicação e recebe a tela de falha de configuração.
- Contraste 3,75:1 do chip DESTAQUE — corrigir quebra 20 goldens aprovados.
- `pg_cron` e consumidor `service_role` para materializar `notices.publish`.


---

## 3B. O QUE VAI EM CADA UM DOS TRÊS RASTREADORES

Li os três (686 linhas cada, matriz por ação) e **encontrei linhas factualmente
desatualizadas** que descrevem como pendente exatamente o que foi corrigido hoje.
**Não alterei nenhum deles — você é o único escritor.** Abaixo, o que vai onde.

### Linhas HOJE INCORRETAS nos três, para `principal.*`

As entradas de `principal.for-you`, `principal.profile-view` e
`principal.profile-edit` afirmam, entre outras coisas:

- *"rota real sempre indisponível na baseline do executor"*
- *"Composição produtiva continua ausente/indisponível no corte"*
- *"profile_about existe em Activities, mas não está ligado ao Perfil Principal"*
- *"existe projeção pura de Comunicações, sem repository produtivo"*
- *"Composição C00 e adapter do consumidor pendentes"*

**As cinco deixaram de ser verdade na branch de L03 (`b209b4e0f`).** Ele tirou as
rotas do fail-closed, montou a composition root sob contexto autorizado, ligou o
contrato ProfileAbout sobre `save_profile_about` — que é justamente o "não está
ligado ao Perfil Principal" — e ligou o adapter de Comunicações com escopo de
audiência **obrigatório**. Manter esse texto depois de integrar descreveria o
produto errado.

**Cuidado:** continuam verdadeiras **em `dev`**, porque a composição ainda não foi
integrada. A redação precisa distinguir *estado em `dev`* de *estado na branch
entregue* — se não distinguir, ou mente agora, ou mente depois do merge.

### `coelo-flutter-pendencias.md` — Front-end

- `principal.profile-view`, `principal.profile-edit`, `principal.for-you`:
  **FE concluído na branch de L03**, com 20 provas responsivas e de
  acessibilidade, 9 do editor, 25 do hub, 11 da aba Acontece e 6 da projeção de
  Circulares. Substituir o texto de composição ausente.
- `acontece.create`, `acontece.publish`, `agora.create`, `agora.publish`:
  **FE verificado** por L01 — não implementados nesta rodada, **verificados**.
  `acontece.*` verificado **para escopo com turma**.
- `momentos.create`, `momentos.publish`: FE — a porta de mídia que faltava; sem
  ela a rota produtiva **não publicava nada**.
- `chat.list`, `chat.open`, `chat.send`: **metade Principal entregue**, metade
  administrativa sem verificação. **Não fechar o ID.**
- `chat.edit`, `chat.receipts`, `chat.revoke`, `notices.schedule`,
  `notices.publish`, `notices.archive`: FE verificado por L02.
- **Pendências novas de FE:** três rotas Principal resolvendo para indisponível
  em `dev`; ~58 construções de `SuperadminShell` sem o badge; guarda de mutação
  por sufixo com quatro candidatas de D03/D04; contraste 3,75:1 do chip DESTAQUE;
  afordância morta da pré-visualização; ausência de contrato visual de
  "Editar perfil".

### `coelo-supabase-pendencias.md` — Back-end

- **Seis contratos de servidor de L01 escritos e provados localmente**, nenhum
  aplicado: `withdraw_happens_post`, `list_visible_moments`, `withdraw_moment`,
  a transição de expiração do Agora, o gateway de Circulares em R2 e o
  `catalog_kind` de chat. pgTAP 32/32, 53/53, 23/23, 16/16, 46/46, 60/60 e 50/50,
  **sete das oito reexecutadas pelo próprio executor**.
- **Dois pacotes de L02 escritos e não aplicados**; `B=1` do pgTAP **mantido
  bloqueado** por decisão dele, com controle provando que as falhas funcionais
  são do harness.
- **Pacote de L03 proposto e não aplicado** para a leitura autorizada de Para Você.
- **Pendências novas de BE:** as três migrations de 01/09 com rótulos `NOT NULL`
  omitidos, com os 14 falsos positivos excluídos pela data; as duas fundações de
  replay quebradas (Atividades e Formulários); ausência de RPC de leitura do
  Sobre; `save_now_draft` sem restrição de audiência por papel — **calibrado como
  pré-condição, não como defeito de segurança**; `pg_cron` e consumidor
  `service_role` para materializar notices; e `refreshAfterRealtime` sem caller,
  com o motivo de o caminho óbvio não servir.
- **Procedimento reproduzível do replay local** e a ressalva de que ele **prova
  contrato, não banco de produção**.

### `coelo-flutter-integrado-supabase-pendencias.md` — Front-end + Back-end

É o que mais muda, porque é onde a distinção entre camadas aparece.

- **E2E 0/39. Nenhuma promoção a `verified-e2e`.** A causa é autorização ausente,
  fundações quebradas e Cloudflare não exercido — **não falta de código**.
- **`acontece.feed` NÃO fecha:** `circulars.happens-card`, que você tornou
  subaceite obrigatório, **nunca chega à rota** — `principalMixedFeedRepository`
  só é declarado, linha 282.
- **`momentos.view`:** contrato pronto e testado que **não chega à tela**, porque
  a rota resolve incondicionalmente para indisponível.
- **`principal.for-you`:** FE pronto, **BE bloqueado** — o servidor devolve o
  diretório inteiro e a audiência é decidida no cliente, contra as invariantes do
  `AGENTS.md`. O filtro de L03 é defesa em profundidade, **não controle de acesso**.
- **`chat.attach`:** retido — faltam a RPC de staging/commit e a Edge Function de
  L01, e o `catalog_kind` só aplica sobre a cadeia de Formulários mais auth interno.
- **Hospedagem ≠ composição:** registrar como duas metades, uma feita em `dev` e
  outra pendente nas branches.
- **BE Cloudflare zero exercido** em todas as frentes — nenhum bucket
  inspecionado, nenhum segredo, Stream não tocado.

### Uma observação sobre os três estarem idênticos em tamanho

Os três têm **686 linhas**. Se a matriz por ação for a mesma nos três, vale
registrar em cada um **o eixo que ele governa** — o de Front-end não deveria
carregar o veredito de BE, nem o inverso. Não é pendência do produto; é
observação sobre o instrumento, e a decisão é sua.

---

## 4. MERGE — dois pontos manuais e dois a não estragar

Medido com `git merge-tree` em leitura pura, por L02 e conferido por mim: **um
arquivo, uma região**, em `superadmin_router.dart`. O lado de `dev` está **vazio**
naquela região porque são as rotas que você moveu.

**O git já resolveu sozinho:** as 3 inserções do `chatUnreadCountLoader`, a rota
`/dev/principal-conversations` e constantes, dois destinos e as linhas de mídia da
preview. **Esses só precisam NÃO ser desfeitos.**

**Os dois pontos manuais:**
1. **Reinserir `/principal-conversations` de produção dentro do `ShellRoute`** com
   `embedded: true`. **Ficar com o lado de `dev` descarta essa rota** — ela vive
   na região esvaziada. Erro silencioso: compila, e só
   `principal_chat_route_test.dart` acusa.
2. **Trocar o único `?from=principal` restante**, no `onOpenMessages` de
   `/principal-happens`.

**Quatro perigos com dano silencioso:**
- **Tomar o lado de `dev` nos quatro arquivos de Para Você reintroduz um buraco de
  segurança:** `dev` tem a versão antiga, com o escopo de audiência **opcional** —
  argumento que se esquece de passar e desliga a verificação em silêncio.
  **Prevalece a branch de L03.**
- **Sem a declaração em `hasAuthoritativeMutationCapability`**, `/principal-profile/edit`
  volta a ser inalcançável pela guarda global.
- **Sem trocar os destinos**, o launcher volta à página administrativa e a
  hospedagem apenas **reposiciona** o defeito.
- **`principal_moments_publication_route.dart` exige UNIÃO**: `dev` trouxe
  `embedded`, L01 trouxe a porta `mediaPicker`. Ficar com um lado **apaga função** e
  a rota volta a não publicar nada. **É a coisa mais frágil da integração inteira.**

**Regra de leitura dos testes que documentam defeito** — `principal_happens_composition_gaps_test.dart`,
`principal_now_real_route_test.dart` e `principal_profile_edit_preview_affordance_test.dart`:
**verde é o esperado** enquanto o defeito existir; **vermelho significa que alguém
corrigiu a composição**, e aí o teste deve ser **INVERTIDO, não apagado**.
Eu mesmo li isso ao contrário e fui corrigido — é o erro mais fácil desta lista.

**Prioridade, se houver tempo para uma só coisa:** a injeção do feed misto. É
**sítio único**, a cadeia já está inteira em `dev`, e fecha o subaceite obrigatório
de `acontece.feed`. Cuidado declarado: `.mixed` fixa `feedScope = null`, então a
página passa a ler **só** o feed misto — desejado, mas muda o caminho de leitura.

---

## 5. ONDE ESTÁ TUDO

**Consolidado completo** (mais de 1.500 linhas, com evidência item a item):
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-l00-coordenacao-claude/docs/reviews/etapa-2-operacao/next-round/R02-20260909/CONSOLIDADO-CLAUDE.md`

**Handoffs originais** — continuam sendo a evidência de cada frente e **não são
substituídos** por este consolidado: L01 655 linhas, L02 897, L03 478, nas
worktrees registradas.

**Doze propostas publicadas:**
- **L01 (7):** pacote remoto nominal; negativas comportamentais do Acontece; prova
  local da retirada; mapeamento de Circulares; contrato de mídia de chat; hunks de
  composição; **resolução de conflitos com blocos prontos para colar**.
- **L02 (2):** hunk do shell do chat Principal **com apêndice pronto para colar**;
  materialização de `notices.publish`.
- **L03 (3):** análise dos cinco conflitos **com apêndice pronto para colar**;
  hunks de hospedagem (**marcada superada na colocação**); **verificação pós-merge
  do grupo**.

**Uma alteração de skill**, commitada na branch de L02 para viajar no delta:
`.agents/skills/coelo-supabase/SKILL.md`, com a invariante durável — *pacote
revisável não é pacote aplicável; uma guarda bem escrita recusa o que falta, ela
não descobre que o próprio insert viola constraint criada depois.*

**Procedimento reproduzível do replay local**, no handoff de L01: receita do
container, shims de `auth` e `storage`, `check_function_bodies=off` (93→112),
relaxamento dos três rótulos (+11), teto do harness, e `MSYS_NO_PATHCONV=1` antes
de `docker exec` no Git Bash. **Ressalva:** prova contrato, **não** banco de
produção — o perfil nominal continua sendo o seu preflight.

---

## 6. ESTADO DAS FRENTES

As três encerraram em estado seguro e **verifiquei**: containers removidos e
conferidos por listagem, subagentes terminados, **nenhum agendamento**, nenhuma
mutação remota, nenhuma worktree criada por elas. Ficaram disponíveis para
correção concreta de consolidação até 16:45.

Se a integração levantar algo, as três podem ser reacionadas pelo Owner.

---

## ATUALIZAÇÃO 16:42 — SHA de L02 corrigido

**L02 avançou de `9144f4efb` para `45d92b9c1` às 16:41**, e é este o SHA a
integrar. Já corrigido em todas as tabelas acima.

O commit é **exclusivamente documental** — `docs(e2-l02): fix misattributed
credit in the handoff`, um arquivo, 9 inserções e 6 remoções em
`handoffs/L02.md`. **Não toca código.** Verifiquei o `--stat`.

Motivo, e ele é relevante para a qualidade do que você vai ler: o handoff de L02
atribuía a L00 a descoberta do runner de pgTAP. **Estava errado** — quem
descobriu foi L01; L00 havia afirmado que não existia runner, o que é o oposto, e
essa afirmação errada foi o que levou L02 à classificação inicial equivocada.
L02 corrigiu por conta própria depois de já ter declarado estado seguro,
justamente por ser fato errado num documento durável que chega até você.

`HEAD == origin == 45d92b9c1`, árvore limpa, zero stashes, nada agendado.
