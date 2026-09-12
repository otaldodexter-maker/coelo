---
title: Ambiente Supabase de produção
knowledge_id: supabase-production-environment
source: decisions/0034-mvp-remote-application-and-acceptance-bar.md
status: validated
generated_at: 2026-09-01
updated_at: 2026-09-12
audience: team
surfaces: [supabase, database, auth, storage, edge-functions]
visibility: internal
review_owner: Coelo Product
---

# Ambiente Supabase de produção

O projeto Supabase `coelo`, identificado por `evvbomzejfijozbtgvpt`, é o
ambiente de **produção** e, em 10/09/2026, ainda não tem clientes reais.

Desde a ADR 0034 o integrador tem autorização permanente do Owner para aplicar
migrations forward-only nesse projeto quando o pgTAP local passou, a ordem
serializada da fila foi respeitada e o backup por ponto no tempo está ligado.
Não é preciso pedir autorização por pacote. O que ficar aberto depois da
aplicação vai para os rastreadores, e o Owner revisa em ciclo semanal ou
quinzenal.

Cada pacote ainda precisa de contrato aprovado, RLS deny-by-default,
privilégios mínimos e pgTAP verde, incluindo negação de outro tenant. Segredos,
buckets e Workers do Cloudflare continuam exigindo autorização nominal, exceto
o pacote da Decisão 5 da ADR 0034 (CORS, lifecycle do transitório, token R2
mínimo, migração das três funções de mídia e spike), executado só pelo
coordenador da rodada.

Em 10/09/2026 a coordenação da Rodada 3 mediu que o backup por ponto no tempo
do projeto estava **desligado** (`pitr_enabled: false`). Pela Decisão 8 da
ADR 0034 o PITR pago fica dispensado até existir cliente real: a condição
passa a ser um `supabase db dump` lógico local (fora do Git), tirado pelo
coordenador antes de cada lote SQL e registrado em `coordenacao.json`.

Na mesma decisão o versionamento do banco ganhou uma **baseline**: o dump
schema-only de produção de 10/09/2026 é a migration inicial, o catálogo de
permissões é seed versionado e a cadeia anterior fica arquivada como
histórico. Todo pacote novo é provado por `supabase db reset` sobre a baseline
mais pgTAP, e esse replay é o preflight antes de produção. O ledger
`supabase_migrations.schema_migrations` não espelha os arquivos locais, então
a aplicabilidade de um pacote antigo é decidida por presença de objeto em
`pg_proc`/`pg_class`, nunca pelo carimbo.

Regras medidas na Rodada 4 (noite de 10→11/09/2026, ADR 0034 Decisões 12 e
13):

- **MFA fora do MVP:** `requires_mfa` é falso em todo o catálogo e
  `app_private.has_mfa_aal2()` aceita sessão `aal1`; nenhuma função nega por
  segundo fator. A ADR 0019 volta depois do MVP.
- **Ordem real de aplicação:** produção não recebeu as migrations em ordem
  de carimbo (o lote 3 entrou antes do lote 4). O espelho local só reproduz
  produção seguindo `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`:
  `db reset` com só a baseline em `supabase/migrations/` (baseline + seed) e
  depois `psql` de cada arquivo na ordem do lote. `db reset` com `migrations/`
  inteira falha em `20260910170100` e `170800`.
- **`supabase db query -f` executa o arquivo inteiro numa transação:**
  `ALTER TYPE ... ADD VALUE` precisa ir em arquivo próprio anterior, senão o
  valor novo não pode ser usado (erro 55P04). O ledger
  `supabase_migrations.schema_migrations` é preenchido à mão (`version`,
  `name`) no mesmo lote.
- **Ator no realm de pessoas:** os usuários do Superadmin existem só no realm
  interno v2; as RPCs baseadas em `current_person_id()` só os alcançam pela
  ponte de ator (`20260910220400`: pessoa de serviço + membership espelhada +
  fallback em `current_person_id()`), sem tocar nos guards de realm.

Fechamento da Rodada 4 (11/09/2026, ADR 0034 Decisão 14): produção recebeu 66
pacotes em 16 lotes numa noite, sempre com pgTAP verde no espelho e dump
lógico antes de cada lote; o ledger tem 102 versões de 10/09. A ordem real de
aplicação vive em `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`
e é a única forma de reconstruir o espelho. Candidatos retidos por decisão do
Owner ficam em `candidatos/<grupo>/` com o sufixo `RETIDO-Pnn` no nome.
Dados sintéticos das provas (prefixos `[R04-QA]`, `9f040000-`, `d0c40000-`
e o usuário `qa-r03@coelo.me`) só saem de produção com a limpeza aprovada.

Fechamento da Rodada 5 (11/09/2026 à tarde, ADR 0034 Decisão 17): mais 20
lotes (28 a 47) e 37 pacotes, com o mesmo rito; o espelho local é reconstruído
por `db reset` da baseline seguido do `psql` de cada arquivo da ordem real
sempre que um pacote devolvido já tinha entrado nele. Regras medidas: a prova
de um grupo inclui os lotes que os outros grupos publicaram depois da abertura;
as pontes de ator espelham identidades internas como pessoas de serviço
(`person_type = 'service'`), que nunca são destinatárias de notificação nem
"equipe"; a membership escopada espelhada sem escopo é uma pendência de
revisão profunda (corrigida na Agenda pelo lote 44); `DELETE`/`UPDATE` dentro
de função sempre com `WHERE`, porque o `pg_safeupdate` do PostgREST bloqueia o
que o pgTAP via psql deixa passar; uma única frente é dona de cada Edge
Function; a sessão do `qa-r03` é única para todas as frentes e um Sair global
derruba as demais, por isso a Rodada 6 passou a ter um usuário sintético por grupo.

Fechamento da Rodada 6 (11/09/2026 à noite, ADR 0034 Decisão 19): mais 7
lotes (49 a 55) e 14 pacotes. Existe agora um usuário sintético por frente
(`qa-r06-estrutura`, `qa-r06-acessos`, `qa-r06-formularios`,
`qa-r06-principal`, `qa-r06-realm`, `qa-r06-publicacoes`,
`qa-r06-operacoes`, todos `@coelo.me`), criados pela API de administração
do Auth e semeados por migration idempotente com identidade interna, Owner de
plataforma, perfil, ponte de ator e membership owner nas instituições
sintéticas; a credencial de cada um vive só em `Coelo-backups/qa-r06-<grupo>.env`
e vale para Claude e Codex. Regra de segurança medida e corrigida: a
identidade interna escopada em instituição nunca herda capacidade de
plataforma, e o sincronizador que dá ao Superadmin visão no Principal
concede por papel interno sobre uma fonte única de escopo, sem filtrar por
status da instituição (o filtro por status desativou memberships de uma
instituição em rascunho e exigiu hotfix no mesmo dia). Pacote marcado pronto
não muda de conteúdo: correção posterior nasce como pacote novo. Sessões da
Conta são listadas por RPC própria e revogadas pelo GoTrue (`scope=others`),
sem função de borda nem chave de serviço.

Na execução coordenada (ADR0034 Decisão20), C0 publica os lotes integrados
e mantém slots globais de um Chrome e um flutter test. Checkpoints agendados
retomam trabalho executável até o corte, sem iniciar outra rodada. Deploy,
preflightHTTP e teste local são evidências distintas de CRUD, RLS e reload.
