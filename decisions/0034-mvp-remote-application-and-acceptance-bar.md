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

## Consequências

- O replay local com Docker deixa de ser porta obrigatória; continua útil para
  o ciclo rápido de pgTAP.
- Tempo gasto em manifestos com hash, recibos e consolidações longas deve ser
  cortado; o Git é o recibo.
- As três skills de revisão e os três rastreadores permanecem como direção e
  registro do que falta.
