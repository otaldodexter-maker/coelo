---
name: coelo-frontend-backend
description: Use when a Coelo review, audit, correction, implementation, estimate, or completion claim crosses Front-end and Back-end, including Flutter/Dart or Astro with Supabase/Postgres, Auth, Edge Functions, Cloudflare R2, Stream, Workers, Media Gateway, remote persistence, or end-to-end behavior.
metadata:
  source: "AGENTS.md; decisions/0032-mvp-private-media-r2.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
  status: "active"
  generated_at: "2026-09-09"
---

# Coelo Front-end + Back-end

> O caminho `coelo-flutter-supabase-review/` foi mantido para compatibilidade.
> O nome e o contrato canônicos são **Coelo Front-end + Back-end**
> (`coelo-frontend-backend`).

## Chamada padrão: resolver pendências ponta a ponta

Invocar `$coelo-frontend-backend` para trabalhar no projeto significa **executar
a resolução de uma fatia da Etapa 2 até sua prova ponta a ponta**, conforme o
[ciclo de resolução](references/review-scope.md#ciclo-de-resolução-de-pendências).
Preservar o recorte informado; sem recorte novo, retomar a subtela incompleta
do último checkpoint ou selecionar a próxima ação executável do inventário.
Informar a escolha e executar as correções locais necessárias, sem terminar
apenas com auditoria, plano ou atualização de percentuais. Pedido explícito de
explicação, diagnóstico/review somente leitura ou manutenção da skill segue
esse pedido, sem iniciar implementação do produto.

Conectar e provar a mesma ação na UI normal, no backend aplicável e no retorno
após reload. Pacote SQL verde em pgTAP local é aplicado em produção pelo
integrador na ordem da fila (ADR 0034), e a chave de composição do cliente é
ligada em seguida. Só Cloudflare ainda espera decisão nominal. Se um gate
impedir E2E, concluir o trabalho independente do recorte, registrar a causa e o
desbloqueio concreto, sem promover o estado por expectativa.

## Princípio

Controlar conclusão ponta a ponta sem substituir as autoridades de cada camada.
E2E significa executar o fluxo real por todos os provedores que a ação usa; não
significa somente Flutter → Supabase.

## Coordenação sem recursão

Confirmar a base integrada e o handoff antes de reutilizar estado local; seguir
a retomada entre worktrees e o limite de repetição de testes do contrato comum.
Ler `AGENTS.md` e o [contrato de recorte](references/review-scope.md).
Coordenar `coelo-frontend` e `coelo-backend` nas partes afetadas, sem reiniciar
suas dependências. Reutilizar contexto lido e carregar skills técnicas conforme
a operação/provedor; `coelo-ui` decide a família visual e `coelo-knowledge`
cuida da memória durável. Uma tarefa de uma camada não usa esta skill apenas
por mencionar o nome de um provedor.

Se Cloudflare participar da ação, aplicar a descoberta de MCP, skills e
implantação nominal definida em `coelo-backend`/`cloudflare-manager`. Teste
local verde não substitui implantar/verificar o pacote já autorizado. Antes
da validação conjunta, conferir que o checkout de testes contém o SHA integrado.
Priorizar as correções visuais apontadas pelo Owner e ligar seus aceites à
mesma ação no backend, sem refazer composição já aprovada.

Para conclusão ampla integrada, ler integralmente, nesta ordem, os rastreadores
`coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md` e
`coelo-flutter-integrado-supabase-pendencias.md` em `docs/reviews/`.
Para ação específica, cruzar seus IDs, dependências, estados e evidências nos
três, com os cabeçalhos de medição. Os nomes históricos não limitam Back-end
somente a Supabase nem Front-end somente a Flutter.

## Recorte por app

Nomear explicitamente `superadmin`, `admin`, `principal` e/ou `site`. Na Etapa
2 atual, somente `apps/superadmin` e packages/backends que ele usa estão
autorizados. “Coelo (Principal)” é um menu do Superadmin, não o app Principal.
Não tocar apps fora do recorte por conveniência ou compartilhamento.
Plataformas compartilhadas de mídia/API permanecem neutras de app; nesta Etapa
2 somente o composition root do Superadmin é conectado. Admin e Principal
consomem o mesmo contrato em etapas futuras, e o Site não lê mídia privada.

Todo checkpoint identifica **Etapa 2 → apps/superadmin → menu → tela →
subtela/estado → action_id**. Subtelas têm linhas próprias e não herdam conclusão
do diretório, da família ou de outra ação. Consultar o
[contrato de métricas e testes](../../../docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md)
para denominadores, evidência, testes e formato do painel.

## Três medições independentes

- Front-end `verified`: chegou ao fim do cliente; não exige backend real.
- Back-end `done`: chegou ao fim dos provedores backend aplicáveis; não exige
  Front-end.
- Integração `verified-e2e`: cliente real atravessou gateway, autorização,
  provedores, persistência e voltou à UI, incluindo reload e negativas.

Não somar os três denominadores. Preservar progresso de camada quando a cadeia
integrada ainda estiver aberta. `ready-for-e2e` exige Front-end `verified` e
Back-end `done` para a mesma ação.

Em cada entrega, publicar por tela um checkpoint de até quatro linhas: o que
foi ligado e provado, `verified`/`done`/`verified-e2e` em C/N, o que ficou
aberto e quem desbloqueia, e o próximo passo. Contar IDs únicos, nunca médias
de percentuais. Ausência de certificado não é ausência de implementação. Não
montar manifestos com hash, recibos de recibo nem consolidações longas: o Git
e a saída dos testes são a evidência.

## Gate `verified-e2e`

Régua do MVP (ADR 0034). Para cada `action_id`, provar:

1. a rota normal abre a tela sem fixture nem fail-closed;
2. o CRUD persiste no Supabase de produção pelo repository/gateway produtivo;
3. o RLS nega outro tenant;
4. o reload mantém o estado.

Ficam para a revisão profunda de segurança, depois do MVP, e não bloqueiam
`verified-e2e`: revogação durante espera com duas sessões, ID adulterado tela
por tela, auditoria com retry, tenant A/B por ação, golden por estado. Sessão,
capacidade, tenant e hierarquia continuam validados no servidor por cada
migration e provados no pgTAP do pacote.

Quando houver mídia/exportação, a cadeia inclui Supabase para metadados e
autorização, Media Gateway e objeto R2 privado real. Quando a política exigir
vídeo HOT, inclui também Stream privado, signed playback, estado de encoding,
fallback R2 e remoção da cópia Stream. Mock, bucket público, URL artificial,
rota `/dev`, golden ou teste isolado não comprovam isso.

### Contratos de produto obrigatórios

- Agora: R2 master primeiro; Stream HOT por até 24 h quando necessário; apagar
  somente Stream na expiração.
- Momentos: R2 padrão; Stream por demanda medida, sem janela fixa inventada.
- Acontece: R2 padrão; Stream somente quando métricas justificarem.
- Chat: R2, sem obrigação de Stream no MVP.
- Formulários: um XLSX com as respostas do formulário no R2 privado; não uma
  exportação por resposta, e sem CSV/ZIP/PDF inventado.
- Outros import/export do Superadmin: botão visível e honestamente indisponível.

### Regras de integração medidas na Rodada 5 (tarde de 11/09/2026)

- **Fila de produção em lote, com preflight único no espelho reconstruído na
  ordem real**: 17 lotes (28 a 44) e 33 pacotes em quatro horas, cada um com
  dump prévio, preflight no espelho `coelo_baseline` (rebuild por
  `db reset` + `psql` da ordem real quando um pacote devolvido já tinha
  entrado no espelho) e ledger inserido à mão. Um pacote devolvido (asserção
  vermelha no espelho) volta à frente com o erro exato e a ordem em que o
  espelho aplicou os outros grupos.
- **Contrato antes do cliente, uma frente por objeto:** institution_contacts
  (G5 escreve, G1 consome), @ de estrutura (G1 escreve o núcleo, G5 completa
  o payload dos RPCs v2), form-media (G3 e G5 colidiram; regra nova: o prompt
  nomeia a única frente dona de cada Edge Function e de cada família de RPC).
- **Deltas só em arquivo** `deltas-*.json` no formato do aplicador
  (`certificacao.evidence` aponta um ARQUIVO em `docs/...`); propostas em
  campos livres do JSON do grupo são normalizadas uma vez pelo coordenador e a
  regra devolvida ao grupo.
- **E2E por action_id na R05:** Instituições (edit), Atividades
  (create/detail/edit/location), Unidades (edit/status), Perfis de acesso
  (list/detail/create), Pessoas (list/links/reload), Convites (list),
  Formulários (publish/overview/monitor/respond/responses/response-detail),
  Segurança infantil (create/edit/suspend), Cuidado (create/detail/edit),
  Agenda (request/permissions), Avisos (schedule com o worker real),
  Auditoria (list/filter/detail), Planos (list/create/edit), Suporte com
  responsável. Aprovação visual do Owner (G-SUP) continua separada.
- **Sessão compartilhada do `qa-r03`:** um Sair global de uma frente invalida
  as sessões das outras; combinar pelo JSON a hora das provas de Sair.
- **Memória:** cada conversa Claude com o MCP `dart` sobe um servidor de
  análise de ~800 MB; com oito conversas a máquina ficou com 0,02 GB livres e
  as sessões foram reiniciadas às ~14:10 (nomes de sessão mudaram; a máquina
  não reiniciou). Frentes de backend puro não precisam desse MCP.

### Regras de integração medidas na Rodada 4 (10→11/09/2026)

- Deltas de estado chegam ao coordenador em
  `docs/reviews/evidence/etapa-2/<rodada>-<grupo>/deltas-*.json` no formato de
  `docs/reviews/apply-tracker-delta.cjs`: `{action_id, camada:
  frontend|backend|integrated, estado_proposto, delta, evidencia,
  certificacao:{evidence, revision, environment, recordedAt}}`. `camada`
  "fe"/"e2e", estados fora do enum ("blocked", "in-progress", "sem mudança"),
  `evidence` com lista de arquivos, sem prefixo `docs/` ou com sufixo " rNN"
  e `revision` numérica são recusados pelo validador; o coordenador
  normaliza uma vez e devolve a regra ao grupo.
- `verified-e2e` exige Front-end `verified` e Back-end `done` na mesma ação;
  quem propõe E2E propõe as duas camadas com a mesma certificação.
- Prova de rota real que funcionou: `flutter build web -t
  test_driver/qa_main.dart --dart-define-from-file=.env.local`, servidor
  estático com fallback de SPA, Chrome com `--remote-debugging-port` e
  `--use-angle=swiftshader`, login e cliques por CDP (o `tap` do driver trava
  no release), capturas por CDP, RPCs conferidas pela aba Network. Um Chrome
  por conversa; fechar ao terminar.
- Quando a conversa de um grupo cai, o coordenador preserva o WIP em commit
  `wip(<grupo>)` na branch do grupo e pode delegar o recorte a subagentes sem
  Chrome (pacotes SQL, cliente, composto) ou com um Chrome (rota real), em
  worktree do grupo, escrevendo no JSON do grupo com a identificação
  "subagente do coordenador".
- `db query -f` de um arquivo a partir de `candidatos/<grupo>` é o caminho de
  aplicação; ao integrar branches, o Git pode realocar um candidato novo para
  `migrations/` por "rename" de diretório: mover de volta antes do preflight.
- Estrutura na R04 (Instituições, Unidades, Turmas, Atividades, Avaliações e
  Locais): 21 pacotes entraram em produção nos lotes 10 e 11 e as chaves
  `structureMutationsEnabled`/`assessmentMutationsEnabled` foram ligadas; o
  Back-end das 49 ações fica `remote-green`, não `done`, porque só a leitura
  de Instituições foi provada na rota real. `institutions.create` v2 persiste
  apenas ROOT+ADDRESS+handle: representantes, administradores, contato,
  documento, plano e marca ficam vazios no detalhe recarregado até o pacote
  de contatos/pessoas no realm interno, e o E2E dessa ação espera por ele.
- Um grupo que perde a conversa (reinício da máquina) entrega pelo Git: rev do
  JSON com a mini-revisão, `deltas-*.json` ensaiado com
  `apply-tracker-delta.cjs` + `validate-trackers.cjs` na própria worktree e
  revertido (o coordenador aplica), handoff e push da branch. O coordenador
  registra "sem retorno" quando o push não acontece; publicar antes de provar
  vale mais que provar sem publicar.
- Porta local compartilhada: `localhost:3000` resolveu para `[::1]`, onde
  outra frente servia um app Dart, enquanto o build esperado estava em
  `127.0.0.1:3000`; as capturas contra `localhost` eram de outro app. Usar o
  endereço IPv4 explícito e conferir o `flutter_bootstrap.js` servido antes
  de qualquer captura.
- Negativa de outro tenant pela régua do MVP: além do pgTAP, a própria RPC de
  produção chamada com a sessão de teste e um `institution_id` alheio ou
  inexistente deve responder a negativa unificada (`CHAT_NOT_FOUND`,
  `42501`), e isso vale como prova registrada por `action_id`.
- Prova E2E que depende de fixture sintética de outro grupo (o chat usou a
  instituição e as pessoas do realm-interno) combina os ids pelo JSON,
  registra o que criou (conversa, mensagens) e entra na limpeza de dados
  sintéticos ao fim da rodada (P37).
- Contrato antes da aplicação: o grupo de backend publica assinaturas,
  envelope, códigos e capacidades no próprio JSON antes de o coordenador
  aplicar, e o grupo de cliente liga o repositório real sem mudar assinatura.
  Foi assim que a família chat virou o primeiro `verified-e2e` da Etapa 2
  (backend do realm-interno no lote 9 + UI do principal-chat-sistema).
- Fixture sintética compartilhada: ids fixos com prefixo por grupo
  (`9f040000-` para o chat), aplicada uma vez, mantida até o fechamento e
  repassada pelo JSON à frente que precisa dela; quem a criou responde pela
  limpeza, que arquiva o que a auditoria referencia por FK.
- Negativa cross-tenant no MVP quando produção não tem segunda identidade
  escopada: pgTAP com Owner escopado a outra instituição chamando todas as
  RPCs da família (`superadmin_internal_chat_cross_tenant_test.sql`, 21/21)
  mais, em produção, `anon` negado e id inexistente não enumerável. Vale
  como gate de RLS do MVP; a prova por segunda sessão real fica para a
  revisão profunda.
- Pacote transversal de privilégios (revoke de `anon`/`authenticated`): medir
  antes e depois, por papel, tabelas e funções em produção e no espelho
  (contagens iguais para os papéis preservados) e reconferir a rota real com
  o modo somente leitura da prova da família.

## Contrato de abertura

Preservar recorte e autorizações já dados. Não perguntar tempo por padrão nem
usar faixas fixas por tela como estimativa. Estimar o delta comprovado. Inventariar
IDs e dependências antes da edição e registrar: apps/telas/ações, objetivo,
incluído/fora, ownership, ordem, critério de parada, evidências, bloqueios e ETA.

Review sem pedido de correção é leitura. Preparar/corrigir migrations e executar
pgTAP local segue o contrato/spec aprovado da ação. Todo remoto Coelo é
produção e ainda não tem clientes reais; pela ADR 0034 migrations forward-only
verdes são aplicadas pelo integrador na ordem da fila, com backup por ponto no
tempo ligado, sem autorização por pacote. Alterar recursos Cloudflare ainda
exige autorização nominal. Um bloqueio externo retém somente a ação
dependente; continuar todo trabalho seguro independente.

## Execução, rastreadores e encerramento

Usar TDD por fatias verticais. Um único writer coordena migrations, recursos
Cloudflare compartilhados e cutover remoto. Sincronizar os três rastreadores no
mesmo turno de correção, regressão, bloqueio ou mudança de ETA, por
tela/subtela/action_id e não por nome da conversa.

Priorizar o primeiro gate aberto de uma subtela enquanto executável. Diante
de bloqueio demonstrado, registrar a dependência e continuar as ações
independentes autorizadas do recorte. No checkpoint,
registrar o delta: aceites fechados, falhas resolvidas/novas, gate que impede E2E,
próxima ação concreta e responsável. Classificar impedimento como implementação,
verificação, integração de código, ambiente/pacote ou decisão. Um bloqueio não
contamina ações independentes. Retomada reutiliza evidência válida e trata só o
delta; não reinicia auditoria nem reimplementa código por `pending-verification`.

No checkpoint, separar Front-end, Back-end Supabase, Back-end Cloudflare e
prova integrada. Informar commits, testes com quantidade/resultado, primeiro
gate aberto e ETA. Declarar conclusão do recorte quando seus gates estiverem comprovados, com
segredos ausentes e evidências preservadas. Commit, merge e deploy são etapas
separadas quando solicitadas; mudanças alheias não bloqueiam relatar uma
correção local verificada. Não confundir isso com integração ou publicação.

### Decisões do Owner de 11/09/2026 que atravessam as camadas (ADR 0034, Decisão 15)

- Owner de instituição e de unidade fazem tudo dentro do seu contexto; o
  resto é liberado em Perfis e permissões (P23). Perfis padrão do sistema só
  o Owner altera (P31).
- Hierarquia obrigatória: unidade dentro de instituição, turma dentro de
  unidade, atividade dentro de uma ou mais turmas, nunca solta (P36). A
  Rodada 5 começa pela Estrutura na rota real.
- Principal: o Superadmin vê tudo; perfil/usuário Coelo segue e é seguido por
  todos; arrobas `coelo` e `coelo.me` reservados (P35). No cabeçalho do
  Principal a opção de perfil filtra o que se vê: responsável filtra por
  criança, funcionário por turma/instituição, híbrido escolhe ver como
  responsável, como funcionário ou ambos; até 5 perfis inline e "ver todos"
  abre um popup; antes de publicar fora do perfil selecionado, o app pergunta
  em qual perfil vai publicar; o botão "+ Agora" adiciona no Acontece e só
  aparece para quem pode publicar (P28).
- Segurança infantil e Medicação: Superadmin decide com auditoria agora;
  regra alvo com notificações à hierarquia e políticas por unidade (P32).
- Grupos do chat com qualquer perfil e responsáveis (P24). Usuário de teste
  compartilhado com o Codex (P37).

## Regras da Rodada 6 (11/09/2026, noite)

- **Usuário sintético por frente:** a prova E2E cita qual `qa-r06-<grupo>`
  abriu a sessão; Codex e Claude usam os mesmos arquivos `.env`.
- **Tela reconstruída zera o E2E:** quando a frente rebaixa o FE para
  `local-green` por reconstrução (família Publicação), o `verified-e2e`
  anterior volta a `pending-verification` até a prova nova na rota real
  (caso `acontece.create`). `verified-e2e` continua exigindo FE `verified` e
  BE `done`; BE `local-green` com CRUD real provado pela tela sobe a `done`
  no mesmo delta (caso `meal-plans.model-create/edit`).
- **Certificação aponta para arquivo publicado na branch:** o validador
  falha em caminho ausente; captura citada e não commitada invalida o delta.
- Tela que servir usuário interno escopado em instituição nas famílias
  people-based recebe 42501 até o backend decidir por contexto; registrar
  como `fail-closed`, não como defeito da tela.
- Sino do shell: `context_notification_recipients` + `context_notification_events`
  bastam para leitura e marcação sem RPC nova (pendência de UI).
- Detalhe por frente em `docs/reviews/evidence/etapa-2/r06-*/skills-deltas*.md`.
