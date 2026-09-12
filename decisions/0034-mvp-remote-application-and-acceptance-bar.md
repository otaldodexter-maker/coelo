---
title: "Aplicação remota autorizada e régua de aceite do MVP"
source: "decisão do Owner Coelo em 2026-09-10; AGENTS.md; docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md"
status: "approved"
generated_at: "2026-09-10"
---

# ADR 0034 — Aplicação remota autorizada e régua de aceite do MVP

## Contexto

Entre 08/09 e 10/09/2026 três rodadas de execução produziram treze pacotes SQL
revisados e verdes em pgTAP local, e nenhum chegou ao banco. A regra vigente
tratava todo recurso remoto como produção e exigia autorização nominal do Owner
por pacote; nenhuma autorização foi concedida, então Back-end e E2E ficaram em
zero por construção. O projeto Supabase `coelo` (`evvbomzejfijozbtbvpt`) ainda
não tem clientes reais. O Owner precisa mostrar o app funcional a um cliente em
duas semanas.

## Decisão 1 — autorização permanente de aplicação forward-only

O Owner autoriza de forma permanente que o integrador aplique migrations
forward-only no projeto Supabase de produção, sem pedido por pacote, quando:

1. o pgTAP local do pacote passou;
2. a ordem serializada da fila foi respeitada;
3. o backup por ponto no tempo do projeto está ligado;
4. o pacote não contém segredo, bucket público nem dado pessoal.

O que ficar aberto depois da aplicação (negativas remotas, reload, E2E) vai
para os rastreadores de Back-end e Front-end + Back-end. O Owner revisa em
ciclo semanal ou quinzenal; a pendência não retém o pacote. A mesma
autorização cobre ligar as chaves de composição do cliente
(`structureMutationsEnabled`, adapters `available: false`) assim que o SQL
correspondente estiver aplicado.

Segredos, buckets e Workers do Cloudflare continuam exigindo autorização
nominal até que o Owner estenda esta decisão a eles.

## Decisão 2 — régua de aceite do MVP

Uma ação da Etapa 2 conta como verificada no MVP quando:

1. a rota normal abre a tela sem fixture nem fail-closed;
2. o CRUD persiste no Supabase real;
3. o RLS nega outro tenant;
4. o reload mantém o estado.

RLS, hierarquia, capacidade e autorização no servidor continuam obrigatórios
dentro de cada migration e são provados uma vez por pacote em pgTAP. As provas
exaustivas por ação (duas sessões concorrentes com revogação durante espera, ID
adulterado tela por tela, auditoria com retry, golden por estado, tenant A/B
por ação) ficam para a fase de revisão profunda de segurança, depois do MVP.
Golden divergente não bloqueia `verified` no MVP; fica registrado.

## Decisão 3 — IDs de estado saem do percentual do MVP

IDs que representam estados de uma tela (recarregar, erro e retry, acesso
negado) e as importações/exportações adiadas permanecem no inventário, mas
não entram no denominador do MVP. Eles são conferidos junto com a tela a que
pertencem e voltam a contar na revisão profunda.

## Decisão 4 — pontos abertos respondidos pelo Owner em 10/09/2026

- Unidades: autorizada leitura de `pg_proc` em produção para conferir se as
  cinco RPCs do diretório existem fora do versionamento.
- Instituições: corrigir a confirmação de saída com alterações que aparece na
  hora errada.
- Tabela administrativa: implementar rolagem vertical no Design System
  (`coelo_ui_admin`), não limitar linhas na tela.
- Chip "Destaque": escurecer o fundo para atingir contraste AA e regravar os
  goldens afetados depois.
- Suporte e Conta / Perfil: construir a camada Supabase agora; não saem do MVP.
- Cardápios: enviar `p_expected_revision` ao apagar imagem.
- Avisos agendados: ligar `pg_cron` no projeto e implantar o worker de
  publicação.
- MFA: o MVP fica sem segundo fator (AAL1), conforme ADR 0019.
- Anexos de UI/UX passados às skills continuam como correções pendentes
  (cards e tabelas fora do padrão, diferenças no menu Coelo Principal); não
  são aprovação do render atual. Goldens só são regravados depois dessas
  correções. Em 10/09 (tarde) o Owner decidiu arquivo por arquivo os 165
  goldens claros divergentes; a lista e as regras transversais estão em
  `docs/reviews/evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md`.
- Dúvidas e aprovações: o Owner quer ser perguntado, com referência visual
  lado a lado quando for UI/UX; decide mais rápido do que o agente.

## Decisão 5 — Cloudflare, custo zero e organização da Rodada 3 (10/09/2026, tarde)

- O Owner autorizou nominalmente o pacote Cloudflare: CORS restrito nos três
  buckets, expiração automática em `coelo-transient-prod`, token R2 de escopo
  mínimo (objetos dos três buckets, sem DNS, billing ou Workers) guardado nos
  secrets das Edge Functions, migração de `happens-media`, `now-media` e
  `moments-media` para R2 e conclusão do spike R2 com dados sintéticos. A
  execução é da conversa que receber o prompt da Rodada 3, não desta.
- O MVP começa **sem custo**: o piloto cabe no nível gratuito do R2 (10 GB-mês,
  1 M Class A, 10 M Class B, egress grátis, conferido na documentação oficial
  em 10/09/2026). Stream não tem nível gratuito; por isso só o Agora usa cópia
  Stream, por até 24 horas, e somente quando a publicação exigir. Nenhuma outra
  superfície promove vídeo ao Stream antes de métricas do piloto.
- Botão Arquivos (importar/exportar) fica escondido em Conversas; o cabeçalho
  mobile segue o anexo do Owner e inclui o botão de Bug.
- Rodada 3: composto de diretório primeiro, depois grupos ponta a ponta. O
  coordenador é uma conversa nova com prompt próprio; a conversa que planejou
  não executa CRUD nem coordena. O Codex, com cota limitada, recebe os grupos
  mais simples e parecidos entre si; o restante roda no Claude com Opus.

## Decisão 6 — respostas do Owner às decisões abertas da rodada noturna (10/09/2026)

- Perfil Principal: a referência aprovada com Acompanhar, Seguidores e Seguindo
  continua valendo. Regra de produto: ao cadastrar uma criança em unidade,
  turma e demais níveis, ela e seus responsáveis acompanham automaticamente
  toda a hierarquia acima, inclusive a instituição.
- Agora: manter o Stream com a estratégia de 24 horas da ADR 0032; sem arquivo
  não há custo. Nada além do Agora vai ao Stream.
- Não existe prévia: Acontece, Agora e Momentos são o produto e cada ação
  funciona de verdade, ponta a ponta; nenhuma mensagem de prévia permanece; o
  feed do Acontece carrega mais pela paginação do servidor.
- Circulares: Agendar com campo inline, Encerrar e Excluir entram no MVP.
- Testar de Formulários lê o formulário por capacidade de edição.
- Lançamentos da Rotina ganham tela mínima sobre o comando existente.
- Guarda de saída do editor de Rotina ligada, igual a Instituições, com as
  seis referências regravadas.
- Sobre do Perfil ganha capacidade de leitura para membros.
- Página de erro 409 usa a família das páginas de erro existentes.
- Chave de idempotência da Assiduidade é gerada e devolvida pelo banco por RPC.
- Botão Arquivos escondido em Conversas; cabeçalho mobile inclui o botão de Bug.

## Decisão 7 — respostas do Owner durante a Rodada 3 (10/09/2026, via grupo estrutura)

- Rodapé dos formulários: opção A, rodapé ancorado no fim da viewport em todas
  as larguras, aplicado no `SuperadminFormFrame` (19 formulários); o golden de
  Instituições em 375 é regravado. Goldens mobile de formulário dos demais
  grupos divergem por consequência e não contam como regressão.
- Balão de chat: não aparece em telas de criar, editar e publicar, nem no
  Agora aberto e no Momentos aberto. Prevalece sobre a regra transversal CHAT
  da lista de goldens de 10/09 quando houver conflito.
- Registro nas skills: `coelo-ui/references/form-layout-contracts.md` e
  `coelo-ui/references/principal-visual-surfaces.md`.

## Decisão 8 — respostas do Owner ao lote P1–P14 da Rodada 3 (10/09/2026)

- **P1, backup por ponto no tempo (opção B):** o PITR pago fica dispensado
  enquanto não houver cliente real. A condição 3 da Decisão 1 passa a ser
  satisfeita por um `supabase db dump` lógico (schema e dados, local, fora do
  Git) tirado pelo coordenador **antes de cada lote SQL**, com nome do arquivo
  e SHA-256 registrados em `coordenacao.json`. O projeto respondeu
  `pitr_enabled: false` em 10/09/2026.
- **P2, token R2 de escopo mínimo:** a sessão OAuth do MCP da Cloudflare não
  cria tokens de API. O token nasce no painel, pelo Owner, e é gravado nos
  secrets das Edge Functions sem passar pelo chat. O roteiro fica na skill
  `coelo-backend`, seção de pendências de segurança, até ser executado.
- **P4, chaves publicáveis:** autorizado gravar `COELO_SUPABASE_URL` e
  `COELO_SUPABASE_PUBLISHABLE_KEY` em `apps/superadmin/.env.local`, ignorado
  pelo Git, para todas as frentes abrirem a rota normal contra produção.
- **P12, baseline do banco:** o dump schema-only de produção de 10/09/2026
  vira a migration inicial de `packages/coelo_database/migrations/`; o
  catálogo de permissões vira seed versionado; a cadeia anterior de 186
  arquivos fica arquivada como histórico e deixa de ser replayada. Todo pacote
  novo é provado por `supabase db reset` sobre a baseline mais pgTAP, e esse
  mesmo replay é o preflight antes de aplicar em produção. Migrations locais
  cujos objetos não existem em produção não são "aplicadas": voltam aos grupos
  como pacotes novos sobre a baseline.
- **P14, credencial exposta por `db dump --dry-run`:** não é preciso agir
  agora. A troca da senha do banco fica registrada como pendência de segurança
  na skill `coelo-backend`, com o roteiro, para o Owner executar quando quiser.

## Decisão 9 — respostas do Owner ao grupo formularios-cuidado-rotina (10/09/2026, 16:00)

- Goldens: `medication_form_mobile_light` volta à referência guardada;
  `profile_form_mobile_light` regravado após a observação;
  `profile_form_desktop_dark` regravado após a observação, seguindo a skill
  `coelo-ui` porque o wizard não segue todo o padrão (contêiner interno).
- "Quem pode ler dado de saúde de uma criança, além da instituição?": opção 1
  da pergunta do grupo.
- "Pergunta de Local no Formulário: opções fixas ou catálogo vivo?": opção 1.
- "Resposta de Local quando o local foi revogado depois": opção 2.
- "Quais são as seis referências da Rotina?": são o modelo de atividade,
  para o modelo de rotina diário.
- O grupo grava o texto das opções escolhidas na spec/skill da família ao
  aplicar; a coordenação registra aqui a resposta como recebida.

## Decisão 10 — respostas do Owner ao segundo lote de perguntas (10/09/2026, noite)

- **P17, sessão de teste em produção: sim.** Existe um usuário sintético de
  Superadmin `qa-r03@coelo.me`, criado pela API de administração do Auth (não
  por insert manual, que quebra o login), vinculado só ao realm interno v2
  como Owner de plataforma, AAL1. A senha foi gerada por script e vive apenas
  em `C:/Users/adrie/Documents/Coelo-backups/qa-r03.env`, fora do Git e fora
  do chat; as frentes leem o arquivo para abrir sessão. O usuário e os dados
  sintéticos que ele criar são removidos ao fim das verificações da rodada
  pelo mesmo gerador em modo de remoção.
- **P18, capacidades de Locais: sim.** As nove `locations.*` foram
  provisionadas em produção (`20260910230012`), Owner-only, `requires_mfa`
  falso no MVP, risco declarado por ação. Isso destravou o catálogo v2 e os
  pacotes de status, cópia e agenda de Locais (lote 5). Reservas, vínculos e
  criação por Atividade/Turma seguem com o grupo estrutura, porque o preflight
  de Reservas exige uma assinatura de `audit_append_superadmin_internal` que
  produção não tem.
- **P16, Local em Formulários: sim, entra no MVP** (novo tipo de item,
  migration e cliente pelo grupo formularios-cuidado-rotina). Caso ainda
  aberto: pergunta obrigatória com local revogado e nenhuma alternativa válida.
- **P2 e P14:** o Owner cria o token R2 no painel e salva os dois valores num
  arquivo local fora do projeto; o coordenador grava nos secrets e apaga o
  arquivo. A troca da senha do banco fica para o Owner depois.
- **Validação visual do Owner (cerca de 170 goldens em 10/09):** passa a ser
  registrada por action_id no inventário e nos três rastreadores como
  aprovação visual, com decisão e observação; não substitui `verified`.

## Decisão 11 — Cloudflare além do pacote da Decisão 5 (10/09/2026, noite, a pedido do Owner)

- **Token R2 (P2) feito pelo Owner** às 18:12: token de conta
  `coelo-edge-functions-r2`, Object Read & Write nos três buckets, sem
  expiração; gravado pelo coordenador como `COELO_R2_*` nos secrets das Edge
  Functions a partir de arquivo local depois apagado. Spike R2-T001/T002/T003/
  T004/T007 PASS contra `coelo-transient-prod`; `circular-media` implantada
  com o ramo R2.
- **Token do Stream criado agora, por decisão do Owner**, token de conta
  `coelo-edge-functions-stream` com permissão Stream Read+Edit apenas, gravado
  como `COELO_STREAM_API_TOKEN` (mais `COELO_CLOUDFLARE_ACCOUNT_ID`). Não há
  uso até o Agora promover o primeiro vídeo; custo zero. A verificação do
  valor fica para o primeiro uso; se falhar, girar o token no painel.
- **Ao vivo no Agora (Stream Live)** não está decidido: fica como pergunta
  P19 de produto (custo por minuto e regra de privacidade de crianças). O
  token atual já cobriria, se decidido.
- **Zona `coelo.me` adicionada à Cloudflare** (plano gratuito) a pedido do
  Owner, com `ssl=full`, `always_use_https`, TLS mínimo 1.2, TLS 1.3, HTTP/3,
  Brotli e Early Hints ligados. Status pendente até os nameservers na
  HostGator (`dns3/dns4.hostgator.com.br`) apontarem para
  `armando.ns.cloudflare.com` e `rosa.ns.cloudflare.com`. Registros de
  `superadmin`, `admin`, `app` e do site entram com cada deploy, que é outro
  pacote (Pages/Workers) com token próprio; DNS e mídia nunca compartilham
  token.
- **Pendência de segurança nova:** existe na conta um token de usuário
  "Cloudflare Agent Token - 2026-09-03" com 25 permissões sobre todas as contas
  e zonas. O Owner revisa (reduzir ou revogar) na próxima janela de segurança
  (P20).

## Decisão 12 — respostas do Owner ao lote P3–P16 e regra geral de MFA (10/09/2026, noite)

- **MFA fora do MVP, sem exceção (P10 e P11):** nenhuma capacidade exige
  AAL2 no MVP; `requires_mfa` passa a falso em todo o catálogo de permissões
  e toda função que hoje nega por AAL2 (Pessoas, escrita de Perfis e Modelos,
  publicação, Rotina, Assiduidade) é alinhada por uma migration única do
  coordenador. Vale inclusive para escrita em dado de criança, por decisão
  explícita do Owner. A ADR 0019 (MFA) fica adiada para depois do MVP.
- **P7, permissões por perfil em toda família:** Cardápios e qualquer outra
  família deixam de ser Owner-only; quem tem a capacidade no perfil, de
  plataforma ou de instituição, gerencia. `has_platform_permission` passa a
  considerar membership de instituição; pacote dos grupos principal-chat e
  acessos-pessoas.
- **P8, Criar grupo no Chat: entra no MVP**, como pacote do grupo
  principal-chat-sistema depois do realm interno v2.
- **P3:** origem `http://localhost:3000` liberada no CORS do R2; outra
  origem só a pedido; upload de teste é apagado depois.
- **P5:** diretório de Turmas abre com o filtro por unidade degradando de
  forma honesta.
- **P6:** o diálogo de importar de Unidades vira a indisponibilidade honesta
  de Instituições.
- **P13:** `units.unit_type_id` é a forma canônica.
- **P15:** rodapé ancorado no fim da tela em todos os formulários (opção b),
  com espaço no fim do conteúdo para a última informação nunca ficar
  escondida nem inalcançável; goldens regravados depois.
- **P16, caso extra:** pergunta obrigatória com local revogado e nenhuma
  alternativa válida fica bloqueada com aviso, sem forçar escolha inválida.
- **P2 e P14:** o Owner declarou feitos (token R2 girado e senha do banco
  trocada). Continuam abertas P19, P20 e P21.

## Decisão 13 — Rodada 4 (noite de 10→11/09/2026): estado vazio dos diretórios e ponte de ator

- **Estado vazio mantém a família inteira (ordem do Owner, 10/09 noite, com
  captura de Instituições em produção com zero registros):** no contêiner
  principal ao lado do shell, a busca, os filtros (mesmo sem opções, com
  rótulo honesto como "Sem tipos cadastrados"), o toggle grade/lista, o botão
  Arquivos e as abas de estado da tela (Todos, Ativos, Em implantação ou
  Rascunhos, Inativos, o conjunto próprio de cada tela) aparecem sempre, com
  nada cadastrado, com zero resultados e antes da primeira carga; o card
  Criar aparece sempre, também no vazio. É do composto `CoeloAdminDirectory`,
  não de cada tela. Registro: `coelo-ui/references/administrative-ui-workflow.md`.
- **Ponte de ator entre o realm interno v2 e o realm de pessoas (medida da
  coordenação, sujeita à confirmação do Owner em P22):** em 10/09 às 22:20
  produção tinha `person_auth_links` vazio e todos os usuários do Superadmin
  só no realm interno, o que deixava sem ator as RPCs baseadas em
  `current_person_id()`/`has_platform_permission` (Unidades, Rotina,
  Assiduidade, Cuidado, Medicação, Cardápios, Suporte, Conta, Pessoas,
  Perfis/Modelos, Segurança infantil). O pacote
  `20260910220400_internal_actor_service_person_v1` (grupo
  formularios-cuidado-rotina) cria uma pessoa de serviço por identidade
  interna, espelha a membership de plataforma por trigger e faz
  `current_person_id()` cair nessa ligação, sem tocar nos guards de realm nem
  nas RPCs. Entra em produção pela Decisão 1 (pacote verde da fila); a
  reversão está no próprio arquivo.
- **Regras de aplicação medidas:** `supabase db query -f` executa o arquivo
  inteiro em uma transação, logo `ALTER TYPE ... ADD VALUE` vai em arquivo
  próprio anterior; a prova local é baseline-only + seed + `psql` das
  migrations posteriores, porque `db reset` com `migrations/` inteira falha em
  `20260910170100` (exige o catálogo antes do seed).

## Decisão 14 — Fechamento da Rodada 4 (11/09/2026, coordenação)

- **Produção recebeu 66 pacotes em 16 lotes (8 a 23) numa única noite**, todos
  provados no espelho reconstruído na ordem real de aplicação e com dump lógico
  por lote; ledger com 102 versões de 10/09. Nenhum pacote foi aplicado sem
  pgTAP verde; três candidatos ficaram retidos por decisão de produto (171600
  P31, 171800 P32) ou por bloqueio de segredo na sessão do coordenador (230023
  disparo do worker de Avisos, P30).
- **Primeiros E2E da Etapa 2 (37 ações)** pela rota real com a sessão
  `qa-r03`: Auth, Chat (6), Avisos, Circulares, Agenda (16), Conta e Suporte
  (7), Formulários e Medicação (5), Modelos de acesso (1). Aprovação visual
  continua separada de `verified`.
- **Ponte de ator (220400) é a regra do MVP** para o realm interno alcançar as
  RPCs baseadas em `current_person_id()`; pacote novo do Superadmin prefere
  `require_superadmin_internal_context`. Fica sujeita à confirmação do Owner
  (P22 respondida pelo pacote; o desenho está na própria migration).
- **Decisões de coordenação sujeitas ao Owner:** instituição sintética do chat
  fica arquivada em produção por FK de `audit_logs` (P25/P37); grants CRUD de
  authenticated sem policy não são revogados antes da demonstração (varredura
  como pendência de revisão profunda); dados sintéticos das provas ficam até a
  limpeza aprovada (P37).
- **Perguntas abertas P22 a P37** em
  `docs/reviews/etapa-2-operacao/next-round/R04-perguntas-ao-owner-20260911.md`;
  as visuais (P26, P28, P33, P34) têm página lado a lado.
- **Regras operacionais registradas nas skills** (memória da máquina, um
  entrypoint de driver, formato dos deltas, E2E exige FE e BE, prova de rota
  real por build web + CDP, subagentes do coordenador quando uma conversa cai).

## Decisão 15 — respostas do Owner ao lote P20–P37 da Rodada 4 (11/09/2026, 10:40)

Respondidas na página de decisões da R04 (artefato "Decisões R04"). Texto
integral das observações em `docs/reviews/etapa-2-operacao/next-round/R04-perguntas-ao-owner-20260911.md`.

- **P20** token antigo da Cloudflare: fica para a revisão de segurança (C).
- **P22** ponte de ator: confirmada, "se isso funcionar sempre" (A).
- **P23** Owner de instituição em Cardápios: sim (A); regra geral: Owner de
  instituição e de unidade fazem tudo dentro do seu contexto, e Perfis e
  permissões liberam o resto.
- **P24** grupos do chat: os dois modelos no MVP (C); grupos com quaisquer
  perfis e responsáveis.
- **P25** instituição sintética: fica arquivada e pode ser usada para teste;
  perguntar ao final se apaga (A).
- **P26** erro 409: aprovar as imagens como golden (A).
- **P28** foto do Perfil: R, com quatro correções (avatar cortado embaixo,
  cabeçalho fora do padrão mobile e logo errada, @ do perfil visível,
  contorno nos avatares sobrepostos) e regras de filtro por perfil no
  cabeçalho do Principal, "+ Agora" só para quem publica e pergunta de perfil
  antes de publicar.
- **P30** worker de Avisos: aprovado (A). Regra nova: tokens, chaves e
  segredos sem custo são criados pelo agente sem pedir; vazamento vira
  pendência com roteiro de redefinição e o Owner aprende a gerar cada chave.
- **P31** perfis padrão: aprovados (A); modelos de sistema para Superadmin,
  Admin e Principal, editáveis só pelo Owner; a unidade parte do modelo ou
  cria do zero; professores atrelados a turmas e atividades.
- **P32** Segurança infantil: B agora (Superadmin decide com auditoria);
  regra alvo com notificações à unidade, à hierarquia da criança e aos demais
  responsáveis, e políticas macro por unidade (aceitar para liberar, só
  inclusão, só exclusão); mesmo conceito para Medicação, com opção de não
  acompanhar.
- **P33** calendário 375: R, aproximar do calendário do iPhone (cantos menos
  redondos, data menor no canto superior esquerdo com respiro, sem contêiner,
  botões calendário/lista a 50%); conteúdo por hierarquia com filtro por
  perfil.
- **P34** detalhe do evento: A+ (sem fundo cinza; cancelar à esquerda,
  salvar à direita; rodapé igual ao de Instituições).
- **P35** Principal: A e B agora: semear a membership de teste e a regra "o
  Superadmin vê tudo"; criar o perfil/usuário Coelo (segue e é seguido por
  todos, logo e capa da marca, arrobas `coelo` e `coelo.me` reservados).
- **P36** Rodada 5 começa pela Estrutura (A), respeitando a hierarquia
  instituição → unidade → turma → atividade.
- **P37** limpeza: script único no fechamento da próxima rodada (A); o
  usuário `qa-r03` também é do Codex.
- **G-SUP** Suporte no composto: A+ (alinhar colunas das tabelas de Suporte
  e Em implantação como na de Instituições). **G-FORM** editor de Formulários
  1440: A.
- **WT** worktree quebrada da R03: removida pelo coordenador a pedido dele.

## Decisão 16 — o @ é a identidade pública de toda entidade (11/09/2026, 12:05)

Resposta do Owner a P40 e P41 (dúvidas da frente estrutura sobre o campo
Identificador de Unidades/Instituições). Ele não reconheceu a distinção entre
slug e handle: "já devemos entender que o @ é uma realidade".

- **Regra do @ (P40/P41, 11/09 12:05):** o @ é a referência única de toda
  entidade (usuário, instituição, unidade, turma, atividade) e "é uma
  realidade" do produto. A entidade nasce com um @ que faz sentido; o usuário
  pode mudar depois, com validação de disponibilidade enquanto digita, no
  máximo uma vez a cada 30 dias. Padrões: turma `@nomedaturma.nomedaunidade`,
  atividade no mesmo conceito dentro de instituição e unidade, unidade
  `@nomedaunidade.nomedainstituicao`. Não existe "slug técnico separado do
  @" para o Owner: o campo Identificador é o campo do @, mantém o ícone @ e
  mostra o padrão gerado como valor editável. Arrobas reservados: `coelo`,
  `coelo.me` e a lista que crescer (P35).

**Pessoas sem perfil também têm @ (12:15):** funcionários, responsáveis e crianças recebem @ mesmo sem perfil de acesso ao app; quem responde por eles pode ver e editar o @ (responsáveis editam o da criança), com a mesma validação de disponibilidade e a trava de 30 dias.

Consequências para a Etapa 2: (a) o padrão gerado pelo servidor continua
valendo como valor inicial, mas o cliente exibe e permite editar o @ na
criação e depois, com verificação de disponibilidade; (b) a troca é limitada a
uma a cada 30 dias por entidade (`handle_last_changed_at` já existe em
`institutions`; replicar nas demais); (c) os padrões hierárquicos
(`turma.unidade`, `unidade.instituicao`) entram no contrato de criação de
Unidades, Turmas e Atividades; (d) P42: os dados sintéticos da frente
estrutura só são apagados no fim da Etapa 2, junto com as demais instituições
sintéticas, por migration de limpeza com dump prévio.

## Decisão 17 — Fechamento da Rodada 5 e decisões do Owner da tarde de 11/09/2026

- **Produção recebeu 21 lotes (28 a 48) e 34 pacotes numa tarde**, todos com
  dump lógico prévio, preflight no espelho reconstruído na ordem real de
  aplicação e ledger inserido à mão; dois pacotes foram devolvidos por
  asserção vermelha no espelho e corrigidos antes de entrar. Cinco Edge
  Functions implantadas ou reimplantadas a partir de `dev` (`chat-media` nova;
  `form-operations`, `form-media`, `form-export-download` e `moments-media`
  estavam com versões de agosto em produção). Segredos sem custo criados pelo
  coordenador (P30): `CHAT_MEDIA_WORKER_SECRET` (+ Vault), chave HMAC do CPF
  no Vault; allowlists de origem alinhadas com as portas locais das frentes.
- **E2E passou de 43 para 103 ações** pela régua do MVP (rota normal, CRUD em
  produção, RLS, reload) em Estrutura, Acessos, Formulários/Cuidado/Rotina/
  Assiduidade, Acontece, Agenda/Avisos/Circulares, Auditoria, Planos e Suporte.
- **Correções de segurança encontradas e aplicadas na rodada:** perfil de
  instituição com `plan.change` criava plano da plataforma (lote 39);
  identidade interna escopada lia a Agenda de outra instituição pela membership
  espelhada sem escopo das pontes (lote 44, latente: 0 identidades escopadas em
  produção); grants CRUD de `authenticated` sem policy revogados (lote 30).
  A raiz da ponte (espelho sem escopo) fica para a revisão profunda com prova
  por família.
- **Aprovações visuais do Owner:** G-SUP (Suporte/Implantação alinhados como
  Instituições), Agenda P33/P34 (calendário iOS e rodapé do detalhe) e
  Importações no composto (uma exceção corrigida no mesmo dia). Registradas em
  `ownerVisualApproval`; não viram `verified`.
- **Decisões do Owner na tarde:**
  - usuários sintéticos **por grupo** na Rodada 6 (`qa-r06-<grupo>@coelo.me`,
    criados pela API de administração do Auth, com perfil interno, ponte de
    ator e membership nas instituições sintéticas, sem custo), porque a sessão
    única compartilhada do `qa-r03` derruba as demais frentes a cada Sair;
  - a lista de palavras proibidas como @ (e, talvez, na escrita) e a lista de @
    exclusivos do Owner serão definidas por ele no encerramento do MVP; até lá
    só `coelo` e `coelo.me` ficam reservados;
  - dados sintéticos de todas as rodadas permanecem em produção até o fim da
    Etapa 2 (P42), quando uma migration de limpeza com dump prévio os arquiva.
- **Regras operacionais registradas nas skills:** uma única frente por Edge
  Function e por família de RPC (G3 e G5 colidiram em `form-media`); provar
  pacotes com a ordem real de produção incluindo os lotes de outros grupos;
  pessoas de serviço nunca são destinatárias; `DELETE`/`UPDATE` em função
  sempre com `WHERE` (pg_safeupdate); célula de tabela alinhada pelo composto
  e regravação dos goldens afetados por quem muda o composto; Sair/sessões só
  no fim da rodada; um servidor de análise Dart por conversa consome ~800 MB.
- **Perguntas abertas P43 a P48** (sessões da Conta, Catálogo, exclusão de
  modelo de sistema, @ de usuários internos, fail-closed de tenant em
  Cardápios, papel do sincronizador do P35) e o A+ dos goldens
  `agenda_create_*` em
  `docs/reviews/etapa-2-operacao/next-round/R05-perguntas-ao-owner-20260911.md`.

## Decisão 18 — respostas do Owner ao artefato de aprovações da R05 (11/09/2026, 16:45)

Respondidas na página de aprovações (artefato 2150f92d, versão 2); anotadas
para a Rodada 6, não executadas pela coordenação da R05. Texto integral em
`coordenacao.json` → `respostasDoOwnerR05`.

- **Visual:** aprovados Avisos e Circulares (diretórios), Formulários,
  Usuários internos e Pessoas (composto), formulário de Instituições,
  Importações (card corrigido). A+ em Perfil do Principal (avatar abre o
  Agora do perfil com contorno em degradê laranja quando há Agora não visto;
  sombra do círculo como no menu flutuante; botão Acompanhar de volta), Para
  Você (degradê dos cards prejudica a leitura; clique do responsável sem
  destino por ora), Acontece (contêiner do feed sem o espaçamento e os cantos
  do padrão no mobile; foto esticada; separações sem capricho; conferir
  fontes e cores do design system), Criar evento (wizard como o de
  Instituições, sem fundo cinza), Lista da Agenda (toggle novo no mobile; no
  web volta o do R), Perfis de acesso e Rotina (card Criar sempre presente,
  inclusive vazio; sem dados de demonstração no app real; Rotina com
  duplicar e arquivar na tabela), composto base (sem fundo cinza; enriquecer
  a UI).
- **Publicadores do Principal reprovados (Acontece, Momentos, Agora):** o
  estilo de publicação é outro e não usa o wizard administrativo. Nasce a
  **família visual Publicação** na skill `coelo-ui`
  (`references/principal-visual-surfaces.md`), com as referências enviadas
  pelo Owner, cobrindo Agora, Acontece, Momentos, Circulares, Eventos e
  Lançar faltas; telas novas propostas no canvas "Publicar no Coelo" e
  **aprovadas pelo Owner às 17:19** (versão 4, com o shell real do
  Superadmin e a tela dentro do contêiner principal no web); referência em
  `docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/`.
  Aprovar a proposta não muda estado de ação; a reconstrução é da R06.
- **Produto:** P43 = B (tela mínima de Sessões no MVP com Edge Function);
  P44 = B (atualizar o Catálogo agora); P45 = B (modelo de sistema criado pelo
  Superadmin pode ser excluído, conforme hierarquia, como owner); P46 = A (@
  para usuários internos); P47 = A (remover o fail-closed de tenant em
  Cardápios); P48 = A (sincronizador distingue owner e operations); P49 = A
  (abas de estado no Suporte, persistir cards e tabela); P50 = B (tela de
  resposta à circular também no Superadmin: "mediante a hierarquia, como
  owner sempre pode tudo").
- **Regra reafirmada pelo Owner:** o Superadmin, como owner, pode tudo dentro
  da hierarquia; o card Criar aparece em todo diretório, em cards e tabela,
  mesmo sem dados; o app real não carrega dados de demonstração.

## Consequências

- O replay local com Docker deixa de ser porta obrigatória; continua útil para
  o ciclo rápido de pgTAP.
- Tempo gasto em manifestos com hash, recibos e consolidações longas deve ser
  cortado; o Git é o recibo.
- As três skills de revisão e os três rastreadores permanecem como direção e
  registro do que falta.


## Decisão 19 — Rodada 6: usuários sintéticos por grupo, cota curta e escopo da ponte de ator (11/09/2026, noite)

- **Usuários sintéticos por grupo, em vigor:** `qa-r06-<grupo>@coelo.me` (7)
  criados pela API de administração do Auth e semeados pelo lote 49 com
  identidade interna, Owner de plataforma, perfil, ponte de ator e membership
  owner nas instituições sintéticas `qa-r04-*`; credencial só em
  `Coelo-backups/qa-r06-<grupo>.env`. Valem para Claude e Codex (P37) e ficam
  até o fim da Etapa 2 (P42). Cada frente usa só o seu.
- **Regra de rodada com cota curta (ordem do Owner, 19:40):** corte rígido
  (2 h de frentes + 30 min de fechamento); a cada 30 minutos as frentes
  registram feito/pendente/commits e o coordenador integra, aplica deltas e
  atualiza md e percentual no mesmo ciclo; demandas ajustadas ao que cabe,
  sem perder nada feito ou pendente; Owner ausente não bloqueia (segue sem
  aprovação; dúvidas vão para a lista de perguntas).
- **Escopo da ponte de ator (segurança, lotes 50, 52 e 55):** identidade
  interna escopada em instituição nunca herda capacidade de plataforma; o
  sincronizador do Principal concede por papel interno (owner →
  `institution_admin`, operations → `institution_reader`, demais sem vínculo;
  P48 = A) sobre a fonte única de escopo, sem filtrar por status da
  instituição.
- **Respostas executadas nesta rodada:** P43 (sessões da Conta por RPC +
  GoTrue), P44 (Catálogo), P45 (modelo de sistema excluível conforme
  hierarquia), P46 (@ do usuário interno pela pessoa de serviço), P47
  (Cardápios sem fail-closed de tenant), P48, P49 (abas no Suporte), V-2, V-8,
  V-11, V-15, V-16, IMP-R05-2; parciais: V-1, V-3, publicadores da família
  Publicação (telas prontas, prova de mídia pendente), Lançar chamada (não
  iniciado), P50 (tela de resposta à circular: pendente).
- **Aberto ao Owner (R06-perguntas):** P51 SMTP próprio para e-mail de
  definição de senha do usuário interno; deploy de `internal-user-create`
  (bloqueado na sessão do coordenador); decisão do launcher "Mensagens" para
  regravar os 9 goldens de Atividades; lista de arrobas reservados (fim do
  MVP).

## Decisão 20 — encerramento R07: aprovações nominais, Circular e execução coordenada (12/09/2026)

Fonte: pedido do Owner no fechamento, confirmado pelo repasse de G8;
`docs/reviews/etapa-2-operacao/next-round/R07-decisoes-owner-20260912.md`
preserva a lista do artefato oficial, versão 1789217640-8613.

- Aprovações futuras usam nome do arquivo, referência R, render A, diferença,
  decisão A/A+/R, observação e versão salva. A é aprovação do estado visto;
  A+ pede ajuste e R mantém a referência. Nenhuma delas certifica persistência,
  backend ou E2E. Contar IDs únicos com A explícito mapeado, não imagens nem
  objetos `ownerVisualApproval` que contêm apenas R.
- P53=A: launcher atual aprovado. Criar modelo de Atividade migra ao rodapé
  canônico ancorado no MVP. Chamada compacta recebe revisão do tamanho do
  título e retorno curto conforme observações nominais, antes da regravação.
- Circulares permitem blocos de perguntas simples e mídia intercalados no
  texto, não restritos ao final. Reafirma os blocos ordenados da spec037.
  Os seis estados web R do compositor são corrigidos conforme o recorte
  indicado; aprovação de um compositor de teste não aprova outro host.
- C0 é o único integrador/publicador. Preparar a R08 toda no Codex, em janela
  de quatro horas de execução e trinta minutos de revisão/fechamento,
  com recebimento/ACK por revisão e publicação periódica em dev. Checkpoints
  agendados retomam frente parada com gate executável até o corte; não
  iniciam a R09 automaticamente nem superam ordem de parar do Owner.
- Um Chrome e um flutter test por vez na máquina; posse por PID/slot,
  nunca encerramento por nome genérico de processo. Preservar evidência
  ignorada antes de remover worktree integrada, mantendo as branches.

As decisões de layout do artefato não mudam os limites de conteúdo da spec037
nem ampliam o escopo de exportações, autenticação ou cobrança.
