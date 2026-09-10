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

## Fato registrado pela coordenação da Rodada 3 (10/09/2026)

O projeto `coelo` de produção respondeu `pitr_enabled: false` em 10/09/2026.
A condição 3 da Decisão 1 não está satisfeita e a fila SQL ficou retida até o
Owner responder à pergunta P1 de
`docs/reviews/etapa-2-operacao/next-round/R03-perguntas-ao-owner-20260910.md`.
A resposta entra aqui como Decisão 8.

## Consequências

- O replay local com Docker deixa de ser porta obrigatória; continua útil para
  o ciclo rápido de pgTAP.
- Tempo gasto em manifestos com hash, recibos e consolidações longas deve ser
  cortado; o Git é o recibo.
- As três skills de revisão e os três rastreadores permanecem como direção e
  registro do que falta.
