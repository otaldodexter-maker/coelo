---
name: coelo-backend
description: Use when a Coelo task involves backend, Supabase, Postgres, Auth, RLS, RPCs, Edge Functions, Realtime, Cloudflare R2, Stream, Workers, Media Gateway, migrations, remote persistence, backend security, or backend completion.
metadata:
  source: "AGENTS.md; decisions/0032-mvp-private-media-r2.md; docs/reviews/coelo-supabase-pendencias.md"
  status: "active"
  generated_at: "2026-09-09"
---

# Coelo Back-end

## Estado documental atual

A R10 foi encerrada. Para pend?ncias e avan?os vigentes, consultar
[fechamento R10](../../../docs/reviews/etapa-2-operacao/next-round/R10-fechamento.md),
[estado por tela e subtela](../../../docs/reviews/etapa-2-operacao/next-round/R10-estado-por-tela.md)
e o invent?rio/tr?s rastreadores sincronizados em `docs/reviews/`.
Notas de rodadas anteriores abaixo s?o hist?ricas; n?o trat?-las como falta
atual de implementa??o ou autoriza??o sem conferir o registro mais recente.
Uma consulta documental n?o reabre a rodada nem inicia R11 ou Etapa 3.

## Entrega atual e limite da Etapa 3

Na Etapa 2, fechar o backend das ações por contratos produtivos, persistência,
RLS e hierarquia, aplicando o autorizado pelo integrador; não esperar UI para
um aceite próprio BE já comprovado. Seguir protocolo vigente: R09 usa Astra
médio e reserva de consumo em `docs/reviews/etapa-2-operacao/next-round/R09-prompts.md`.
Não repetir auditoria ampla ou provas verdes sem mudança pertinente.

A [ADR 0035](../../../decisions/0035-etapa3-mvp-contextual-access-and-app-delivery.md)
registra a Etapa 3, ainda MVP, somente para proposta futura. Não criar SQL ou
deploy agora. Na abertura explícita, revisar o conjunto previsto para entregar
o app antes de propor: acesso de funcionário por plataforma/dias/horas/vigência
e afastamento, sempre no vínculo profissional da instituição/unidade que o
configurou. Não bloquear Auth global, @, papel familiar ou outros vínculos.
Impor as regras no servidor; popup é opcional e não controla permissão. Fuso,
precedência e identificação de plataforma exigem definição na futura spec.
Tour, home IA e Admin/Principal também pertencem à proposta, sem lojas agora.

> O caminho desta skill permanece `coelo-supabase/` por compatibilidade com
> documentos e prompts antigos. O nome e o contrato canônicos são **Coelo
> Back-end** (`coelo-backend`).

## Chamada padrão: resolver pendências

Invocar `$coelo-backend` para trabalhar no projeto significa **executar a
resolução das pendências Backend da Etapa 2**, conforme o
[ciclo de resolução](../coelo-flutter-supabase-review/references/review-scope.md#ciclo-de-resolução-de-pendências).
Usar o recorte informado; sem recorte novo, retomar o pacote da subtela pendente
do último checkpoint ou selecionar a próxima ação executável do inventário.
Informar a escolha e corrigir/testar localmente dentro do escopo autorizado,
sem exigir nova confirmação para esse trabalho. Pedido explícito de explicação,
diagnóstico/review somente leitura ou manutenção da skill segue esse pedido.

Levar implementação e pgTAP local até verde e então **aplicar o pacote no
Supabase de produção** na ordem da fila, conforme a ADR 0034: o integrador tem
autorização permanente para migrations forward-only quando o pgTAP local passou
e o backup por ponto no tempo está ligado. Não pedir autorização por pacote.
Só recursos Cloudflare fora do pacote autorizado na Decisão 5 da ADR 0034
(CORS, lifecycle do transitório, token R2 mínimo, migração das três funções
de mídia, spike) ainda exigem decisão nominal. O MVP roda no nível gratuito do
R2; Stream só no Agora por até 24 h. Documentação e plano sozinhos não resolvem a pendência. Backend `done`
no MVP exige o pacote aplicado e o RLS negando outro tenant; ausência de
Front-end não impede concluir o backend da ação.

## Princípio e limite

Tratar o backend Coelo como a soma dos provedores realmente usados pela ação:

- **Supabase/Postgres:** identidade, sessão, dados relacionais, vínculos,
  autorização, RLS, metadados, auditoria, RPCs, Edge Functions e Realtime;
- **Cloudflare R2:** origem privada dos binários novos do MVP;
- **Cloudflare Stream:** cópia privada e removível para vídeo HOT somente onde
  a política do produto exigir;
- **Media Gateway server-side:** fronteira que reautoriza o ator e coordena
  Supabase e Cloudflare sem expor segredo ao cliente.

Uma ação sem mídia não precisa de Cloudflare. Uma ação com mídia ou exportação
não pode ser `done` apenas porque o Supabase está verde.

## Etapa 2 por tela e subtela

O consumidor atual é **apps/superadmin**, inclusive o menu Coelo (Principal).
Admin, Principal e Site não entram no recorte. Identificar em abertura,
checkpoint e entrega **Etapa 2 → app → menu → tela → subtela → action_id →
provedores**. Ligar cada pacote backend às ações que desbloqueia; infraestrutura
compartilhada aparece como dependência, sem multiplicar a mesma entrega.
Usar o [contrato de métricas e testes](../../../docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md).

## Leitura por recorte

Confirmar a base integrada e o handoff antes de reutilizar estado local; seguir
a retomada entre worktrees e o limite de repetição de testes do contrato comum.
Ler `AGENTS.md` e o [contrato de recorte](../coelo-flutter-supabase-review/references/review-scope.md).
Para backend, usar `docs/reviews/coelo-supabase-pendencias.md`; a leitura integral
é obrigatória na auditoria/conclusão ampla, e o recorte usa as linhas afetadas
com cabeçalho e dependências. Consultar specs e ADRs da ação; mídia começa na
ADR 0032. Não buscar credenciais ou acessar produção para explicar uma regra.

- Supabase: carregar a skill oficial disponível; aplicar boas práticas Postgres
  quando houver SQL/schema/RLS/desempenho. Conferir documentação primária atual
  para APIs/comportamentos temporais utilizados.
- Cloudflare: carregar a skill específica quando o provedor estiver em escopo;
  `wrangler` para CLI/config/deploy e Workers para código do Worker. Gerenciamento
  de vários serviços pode usar `cloudflare-manager`; não carregar tudo por nome.
  Usar o plugin oficial instalado e descobrir seus MCPs antes de declarar
  ferramenta indisponível. `cloudflare_api` oferece `docs`, `search` e `execute`:
  consultar documentação/schema antes da operação. MCP atende operações de
  conta/recursos; Wrangler e scripts reais do projeto atendem build/deploy de
  código. A [skill manager local](../cloudflare-manager/SKILL.md) detalha esse
  caminho sem exigir scripts ausentes, Bun ou chave global em `.env`.
  Ferramenta disponível não comprova permissão na conta; conferir somente o
  acesso necessário. Com pacote nominal já autorizado, implantar e verificar
  dentro desse escopo; ausência de acesso requer bloqueio concreto, não outro
  ciclo de testes locais sem mudança. Não transferir deploy ao Owner por padrão.
- `coelo-frontend-backend` somente quando a alteração ou conclusão atravessar
  cliente e backend; backend isolado não ativa uma revisão de Front-end.
- Usar `rtk` nos comandos e `coelo-knowledge` no gate de conhecimento durável.
  Reutilizar contexto já lido; dependências não reiniciam a cadeia de skills.

Review, auditoria e diagnóstico sem pedido de correção são somente leitura.
Correção local solicitada segue o recorte autorizado. Criar, corrigir e testar
migrations localmente segue o contrato/spec aprovado da ação; uma decisão de
produto ainda aberta não é suprida por esta regra. O projeto Supabase `coelo`
é produção e não tem clientes reais em 10/09/2026. Pela ADR 0034, migrations
forward-only são aplicadas pelo integrador sem autorização por pacote quando o
pgTAP local passou, a fila serializada foi respeitada e o backup por ponto no
tempo está ligado. Deploy de Edge Function acompanha a migration que o exige.
Segredos, buckets e Workers do Cloudflare fora do pacote da Decisão 5 (ADR 0034) ainda exigem autorização nominal.
Registrar no rastreador o que ficou aberto depois da aplicação; o Owner revisa
em ciclo semanal ou quinzenal.

## MFA fora do MVP e permissões por perfil (ADR 0034, Decisão 12)

Decisão do Owner em 10/09/2026: **nenhuma capacidade exige segundo fator no
MVP**, inclusive escrita em dado de criança; `requires_mfa` é falso em todo o
catálogo e nenhuma função nega por AAL2 (migration única do coordenador
alinha as que ainda negam; pacotes novos nascem sem exigência). A ADR 0019
volta depois do MVP. Também por decisão dele, **toda família obedece a
perfis e permissões**, de plataforma ou de instituição: nada é Owner-only
por desenho; `has_platform_permission` passa a considerar membership de
instituição.

## Sessão de teste em produção (ADR 0034, Decisão 10 / P17)

Existe um usuário sintético de Superadmin (`qa-r03@coelo.me`), Owner de
plataforma no realm interno v2, AAL1. A credencial vive só em
`C:/Users/adrie/Documents/Coelo-backups/qa-r03.env` (fora do Git); nunca no
chat, no JSON de comunicação nem em commit. Regras: criar usuário de teste
sempre pela API de administração do Auth (insert manual em `auth.users` quebra
o login); o guard do realm interno impede o mesmo auth user no realm
people-based; escrever só dado sintético e apagar na mesma sessão; ao fim da
rodada o coordenador remove o usuário e o que ele criou. Decisão do Owner de
11/09/2026 (P37): o mesmo usuário é usado pelas conversas Codex para
verificar; a credencial chega a elas pelo arquivo, nunca pelo chat. A
instituição sintética `9f040000-0000-4000-8000-000000000010` pode ser usada
para teste e validação; ao finalizar, perguntar ao Owner se ele quer apagar
(P25). A limpeza dos dados sintéticos é um script único, provado no espelho,
rodado no fechamento da rodada seguinte à demonstração (P37, opção A).

## Decisões do Owner de 11/09/2026 (respostas à Rodada 4, ADR 0034 Decisão 15)

- **Regra do @ (ADR 0034 Decisão 16) (P40/P41, 11/09 12:05):** o @ é a referência única de toda
  entidade (usuário, instituição, unidade, turma, atividade) e "é uma
  realidade" do produto. A entidade nasce com um @ que faz sentido; o usuário
  pode mudar depois, com validação de disponibilidade enquanto digita, no
  máximo uma vez a cada 30 dias. Padrões: turma `@nomedaturma.nomedaunidade`,
  atividade no mesmo conceito dentro de instituição e unidade, unidade
  `@nomedaunidade.nomedainstituicao`. Não existe "slug técnico separado do
  @" para o Owner: o campo Identificador é o campo do @, mantém o ícone @ e
  mostra o padrão gerado como valor editável. Arrobas reservados: `coelo`,
  `coelo.me` e a lista que crescer (P35).
  Back-end: geração do padrão por hierarquia na criação, unicidade global,
  verificação de disponibilidade por RPC, `handle_last_changed_at` e a trava
  de 30 dias em unidades, turmas, atividades e pessoas. Pessoas sem login
  (funcionários, responsáveis, crianças) também têm @; a edição do @ de uma
  criança é autorizada aos seus responsáveis e à instituição, com auditoria.
- **Lista de arrobas reservados fica para o encerramento do MVP (Owner,
  11/09/2026 15:20):** hoje só `coelo` e `coelo.me` estão reservados
  (`public.reserved_handles`, lote 38). No fechamento formal do MVP, perguntar
  ao Owner duas listas: palavras proibidas como @ para qualquer usuário (e se a
  proibição vale também para a escrita) e palavras que só o Owner pode usar
  como @. Não ampliar a lista antes; ao receber, entra por migration
  idempotente com flag "somente Owner" e na validação do cliente.
- **Segredos sem custo não pedem autorização (P30):** token, chave, segredo
  de Edge Function, valor no Vault e similares que não gerem custo são criados
  e gravados no secret store pelo agente; o valor nunca aparece em chat,
  commit, log ou JSON. Suspeita de vazamento vira item na seção de pendências
  abaixo, com o roteiro de redefinição, para o Owner rotacionar ao fim do
  projeto; cada tipo de chave criada ganha ali o roteiro de como gerá-la,
  porque o Owner quer aprender. Recursos com custo (Stream, PITR, planos
  pagos) continuam nominais.
- **Perfis padrão do sistema (P31):** existem modelos de sistema de perfil e
  permissão para Superadmin, Admin e Principal (Administrador da instituição,
  Coordenação, Professor(a), Secretaria e os que forem necessários), com
  hierarquia, RLS e o que cada um vê, lê, acessa e edita por tela e subtela.
  Só o Owner e a IA com autorização dele alteram modelos de sistema; a
  unidade usa o padrão ou cria perfil do zero ou a partir de um modelo, sem
  editar o modelo. Professores são atrelados a turmas e atividades e podem
  ter papéis diferentes em turmas de unidades diferentes. Pacote 171600
  aplicado como primeiro conjunto.
- **Segurança infantil e Medicação (P32, opção B agora):** o Superadmin com
  `child_safety.manage` também decide, com auditoria (pacote 171800). Regra
  alvo, a construir: quando um responsável cadastra ou retira alguém, a
  unidade, toda a hierarquia da criança (professores, coordenação, direção)
  e os demais responsáveis são notificados no sino; a unidade ou instituição
  define, numa tela de políticas macro do app, se a alteração exige aceite
  para liberar, aceite só na inclusão, só na exclusão ou outras variações.
  Mesmo conceito para Medicação, incluindo a opção de não acompanhar
  medicação. Essa tela de políticas é a primeira do gênero e cresce depois.
- **Owner de instituição e de unidade fazem tudo dentro do seu contexto
  (P23);** o restante é liberado em Perfis e permissões. P22 (ponte de ator)
  e P24 (grupos do chat com qualquer perfil e responsáveis; os dois modelos
  no MVP) confirmados.
- **Principal (P35):** regra de produto: o Superadmin entra no app vendo
  tudo. Semear já a membership da pessoa de serviço de `qa-r03` para a prova
  e criar o perfil/usuário **Coelo** (o app): segue todos e é seguido por
  todos, logo com fundo laranja e coelho branco, capa no padrão da marca
  ("Coelo é..."), e ninguém pode usar os arrobas `coelo` e `coelo.me` (lista
  reservada cresce depois). O Owner publicará dicas do app por ele.
- **Hierarquia (P36):** não existe unidade sem instituição, turma sem
  unidade, atividade fora de unidade ou instituição; atividade é sempre
  dentro de uma ou mais turmas, nunca solta. Migrations e RLS novas respeitam
  isso.

## Pendências de segurança que só o Owner executa (registradas em 10/09/2026)

Remover cada item no mesmo turno em que a verificação confirmar o efeito.

1. **Token R2 de escopo mínimo (ADR 0034, Decisão 5 e 8/P2). FEITO em
   10/09/2026 18:12:** o Owner criou o token de conta `coelo-edge-functions-r2`
   (Object Read & Write, três buckets, sem expiração) e o coordenador gravou
   `COELO_R2_ENDPOINT`, `COELO_R2_REGION`, `COELO_R2_ACCESS_KEY_ID` e
   `COELO_R2_SECRET_ACCESS_KEY` nos secrets das Edge Functions a partir de um
   arquivo local depois apagado; spike sintético R2-T001/T002/T003/T004/T007
   PASS contra `coelo-transient-prod`. Os valores mascarados que o Owner colou
   no chat não são o segredo; se algum dia o valor real aparecer em chat, o
   token é rotacionado no mesmo painel. Roteiro original, para rotação: painel Cloudflare →
   R2 Object Storage → *Manage R2 API Tokens* → *Create API token* → nome
   `coelo-edge-functions-r2`, permissão **Object Read & Write**, *Specify
   bucket(s)* com `coelo-media-prod`, `coelo-documents-prod` e
   `coelo-transient-prod`, sem TTL, sem filtro de IP → *Create*. Na tela
   seguinte copiar *Access Key ID* e *Secret Access Key* (só aparecem uma vez)
   e, no PowerShell do próprio Owner, rodar:

   ```powershell
   supabase secrets set --workdir packages/coelo_database `
     COELO_R2_ENDPOINT=https://2363eb1eadce9b73279d3c8ce46eb424.r2.cloudflarestorage.com `
     COELO_R2_REGION=auto `
     COELO_R2_ACCESS_KEY_ID=<Access Key ID> `
     COELO_R2_SECRET_ACCESS_KEY=<Secret Access Key>
   ```

   Verificação pelo coordenador: `supabase secrets list` mostra os quatro
   nomes; depois `deno run --allow-env --allow-net
   packages/coelo_database/scripts/r2-spike-synthetic.ts` com os mesmos valores
   no ambiente do processo (nunca em arquivo versionado). Efeito: deploy de
   `happens-media`, `now-media` e `moments-media` e conclusão do spike.
   **Feito:** `moments-media` v1 e `circular-media` v5 em 10/09 à tarde;
   `happens-media` e `now-media` em 10/09 22:24 (lote 9), depois das
   migrations `20260910190600` (Agora) e `190700` (Acontece) que passaram o
   provedor padrão para `r2`.
1b. **Stream (ADR 0034, Decisão 11).** Token de conta
   `coelo-edge-functions-stream` (Stream Read+Edit) gravado como
   `COELO_STREAM_API_TOKEN` com `COELO_CLOUDFLARE_ACCOUNT_ID` em 10/09/2026;
   provado por listagem real do Stream às 19:05. Token de deploy
   `coelo-deploy-apps` (Pages + Workers Scripts) provado por `wrangler
   whoami` e guardado só no ambiente do usuário Windows
   (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`). Lição: a página de
   sucesso da Cloudflare entrega o valor em "Seu token de API" com 53
   caracteres; o "ID do token" (32) não serve.
1c. **Revisar o token de usuário "Cloudflare Agent Token - 2026-09-03"**
   (25 permissões, todas as contas e zonas): reduzir ou revogar (P20).
1d. **DNS de `coelo.me`:** zona criada na Cloudflare em 10/09 (id
   `358365d64558c2cfd4f5aff62498f6ec`), pendente até o Owner trocar os
   nameservers na HostGator por `armando.ns.cloudflare.com` e
   `rosa.ns.cloudflare.com`; antes, copiar MX/A existentes se houver e-mail ou
   site. Registros dos apps entram com o deploy, com token próprio de
   Pages/Workers e DNS, nunca o token de mídia.
1e. **Cloudflare Access na frente do Superadmin (decisão futura, P21).** Em
   10/09/2026 o Owner pediu para registrar: proteger `superadmin.coelo.me`
   (e depois `admin.coelo.me`) com Cloudflare Access (Zero Trust, gratuito até
   50 usuários) como segunda barreira antes do login do app. Exige política de
   quem entra (e-mails do Owner e da equipe), token próprio com `Access: Apps`
   e não substitui Auth, RLS nem MFA. **Decisão do Owner (10/09/2026,
   noite): ligar depois do MVP.** Não bloqueia a Etapa 2; volta à fila na
   revisão profunda de segurança, quando o Superadmin tiver clientes reais.
3. **Chave HMAC do catálogo de identidade `coelo_person_identity_hmac_v1`
   (Vault, criada em 11/09/2026 pela migration `20260911210000`).** Guarda o
   HMAC-SHA256 do CPF em `app_private.person_identity_identifiers`
   (`hmac_key_version = 1`); gerada no próprio banco
   (`encode(extensions.gen_random_bytes(32),'hex')`), nunca passou por chat,
   commit, log ou JSON. Rotação só por suspeita de vazamento: criar a versão 2
   com `select vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),
   'coelo_person_identity_hmac_v2','HMAC v2')` via `supabase db query --linked`
   e publicar migration que faça `person_identity_hmac_v1` ler a v2 e gravar
   `hmac_key_version = 2`; as linhas v1 ficam válidas só para a máscara (o
   CPF não é guardado). Como gerar chave assim: sempre no banco, com
   `vault.create_secret`, nunca em arquivo.
4. **Segredos de worker das Edge Functions de mídia (11/09/2026).**
   `CHAT_MEDIA_WORKER_SECRET` (secret + Vault `chat_media_worker_secret`) foi
   gerado localmente com `openssl rand -hex 32`, gravado a partir de
   `Coelo-backups/chat-media-worker-secret.env` e nunca impresso. Rotação:
   gerar novo hex, `supabase secrets set CHAT_MEDIA_WORKER_SECRET=...` e
   `select vault.update_secret(id, '<novo>')` na mesma linha do Vault. As
   URLs `chat_media_worker_url`, `form_media_worker_url` e
   `forms_media_worker_url` no Vault não são segredos. Os workers de
   Formulários usam o Bearer `forms_worker_bearer_token` já existente.
2. **Troca da senha do banco de produção (ADR 0034, Decisão 8/P14).** Motivo:
   `supabase db dump --dry-run` imprimiu a credencial do papel efêmero do
   pooler numa saída de ferramenta em 10/09/2026. Roteiro: painel Supabase →
   projeto `coelo` → *Project Settings* → *Database* → *Database password* →
   *Reset database password* → gerar senha nova e guardá-la só no gerenciador
   de senhas. Nada no repositório usa a senha (o CLI autentica pelo token de
   acesso e cria o papel efêmero a cada comando), então não há arquivo a
   atualizar. Verificação: `supabase db query --linked` continua funcionando
   e `supabase secrets list` mostra `SUPABASE_DB_URL` com data nova só se a
   plataforma o regenerar. Regra permanente: não usar `--dry-run` em sessão
   de agente.

## Segurança de credenciais

- Nunca colocar `service_role`, secret key, token Cloudflare, credencial R2,
  signing key ou segredo de Worker em Flutter, Astro, Git, asset, log ou evidência.
  Não embutir, versionar, registrar ou persistir URLs temporárias como parâmetros
  permanentes. O cliente privado pode consumir URL curta em runtime emitida
  pelo gateway após reautorização, limitada a ator/recurso/operação/TTL. Site
  não recebe mídia privada. Expiração exige nova autorização no servidor.
- Guardar segredos somente no secret store do ambiente. Arquivos locais de
  segredo ficam ignorados; exemplos contêm apenas nomes e valores fictícios.
- Token que apareceu em conversa, anexo, log ou diff é comprometido: não usar,
  não testar, não copiar e não pedir novamente em chat; solicitar rotação e
  provisão de menor privilégio diretamente no secret store.
- Presigned URL é credencial temporária: operação, objeto, MIME e TTL mínimos;
  CORS não substitui autorização.

## Comunicação e progresso

Traduzir na primeira ocorrência: Auth (entrada/sessão), RLS (segurança por
linha), RPC (função do banco), Edge Function/Worker (função no servidor),
`fail-closed` (nega por segurança), `local-green` (prova local),
`remote-green` (provedores remotos aplicáveis comprovados) e `done` (fim do
backend da ação).

Calcular por `action_id` aplicável reconciliado, separando recorte, tela/subtela
e geral conhecido da Etapa 2. Famílias e gates são coberturas separadas, nunca
somados a ações. Preservar avanço local válido e distinguir `done` de E2E.
Reutilizar o snapshot integrado datado para informar E2E conhecido, sem
certificar Front-end numa tarefa Backend. Se faltarem horários/evidências, usar
`não calculável ainda` e registrar o próximo dado necessário.

Checkpoint curto, no máximo quatro linhas:

```text
Etapa 2 | apps/superadmin | menu > tela > subtela | action_ids
Aplicado em produção: migrations ...; pgTAP P/F; done C/N.
Aberto: ... (o que falta e quem desbloqueia).
Próximo passo: ...
```

Não montar manifestos com hash de arquivo, recibos de recibo nem contagens
P/F/B/S/U por lote: o commit no Git e o log do pgTAP são a evidência.

### Limite de `done` do Back-end

No MVP (ADR 0034), `done` exige, sem Front-end:

1. migration aplicada em produção, com RLS deny-by-default, grants mínimos e
   caminho server-side que valida sessão, ator, capacidade e tenant;
2. persistência real e reload por cliente de teste;
3. pgTAP do pacote verde, incluindo negação de outro tenant;
4. rastreador atualizado com o que ficou aberto.

Ficam para a revisão profunda de segurança, registrados mas sem bloquear
`done`: concorrência com duas sessões e revogação durante espera, IDOR/BOLA por
ação, auditoria com retry, Advisors e cleanup de órfãos.

Para mídia/exportação, acrescentar: objeto R2 privado real, metadados
consistentes no Supabase, URL curta após reautorização, expiração/revogação,
retenção e limpeza de órfãos. Para vídeo HOT, acrescentar Stream privado,
estado de processamento, playback autorizado, fallback R2, retry e remoção da
cópia Stream sem remover o master R2.

## Contrato de abertura

Usar o contrato de recorte: inferir o escopo já solicitado, informar pendências,
ordem, parada, evidência e estimativa fundamentada. Não perguntar tempo por
padrão, nem confundir duração com qualidade ou autorização. Ajustar o recorte
quando houver limite informado, preservando segurança e os gates da conclusão.

## Políticas vigentes de mídia e exportação

- Usar os buckets privados de produção definidos na ADR 0032:
  `coelo-media-prod`, `coelo-documents-prod` e `coelo-transient-prod`. Os três
  existem na conta Cloudflare desde 03/09/2026 (conferido via MCP
  `cloudflare-api` em 10/09). Desde 10/09 (tarde) os três têm CORS restrito
  às origens `superadmin`, `admin` e `app.coelo.me` (GET, PUT, HEAD) e o
  transitório expira objetos com 7 dias. Stream e Workers estão vazios; a
  sessão OAuth do MCP não cria tokens de API, então o token R2 nasce no
  painel pelo Owner. O gateway de
  mídia roda em Edge Functions do Supabase e acessa o R2 pela API S3 com token
  de escopo mínimo guardado nos secrets das Edge Functions, nunca em Git.
- A plataforma é compartilhada por Superadmin, Admin e Principal. Não criar
  bucket, chave, gateway ou catálogo por app; a Etapa 2 conecta somente
  Superadmin, preservando contratos em `coelo_domain`/`coelo_api` para os
  consumidores posteriores. Site não acessa mídia privada.
- A chave R2 única e estável é emitida pelo servidor, sem PII e sem árvore
  global `v1`/`v2`:
  `<scope>/<scope_uuid>/<domain>/<entity_type>/<entity_uuid>/<purpose>/<asset_uuid>/<rendition>/<object_uuid>.<ext>`.
  Substituição cria novo ativo/objeto; versão e histórico ficam no Postgres.
  Postgres mantém ativos, variantes, bindings, entregas Stream, uploads, jobs e
  auditoria; a chave nunca decide autorização.
- Perfil/avatar, capas, logos, eventos, mapas, fotos de local, imagens de
  perguntas/respostas e anexos pertencem à entidade/finalidade correspondente.
  PDF fica em `coelo-documents-prod`, nunca no Stream. Temporários, quarentena,
  processamento e XLSX ficam em `coelo-transient-prod` com lifecycle.
- Aceitar imagem JPEG/PNG/WebP; HEIC/HEIF somente após conversão. Validar MIME
  real, bytes, dimensões, pixels, checksum e política da finalidade no servidor.
  SVG de usuário e GIF animado ficam recusados no MVP. Aplicar os limites por
  finalidade da ADR 0032 e remover EXIF/GPS por padrão.
- **Família nova de mídia segue o padrão de Circulares** (`20260909212000`,
  repetido em `20260910190600` Agora e `190700` Acontece): `storage_provider`
  com default `r2`, `bucket_id` sem default e escolhido pela RPC conforme o
  MIME, chave opaca
  `tenants/<institution>/<domínio>/<entidade>/<id>/<finalidade>/<asset>/original/<uuid>.<ext>`,
  restrições `NOT VALID` condicionadas ao acervo legado, `finalize` sem
  consultar `storage.objects` quando o provedor é R2 (a prova é o checksum
  medido pelo gateway) e todo descritor devolvido ao gateway carrega
  `storage_provider`. Nenhum bucket novo no Supabase Storage. Substituição de
  ativo gera chave nova; o objeto anterior fica órfão até o coletor da família
  (Momentos tem o seu; Agora e Acontece ainda não).
- **Agora:** master no R2; Stream HOT por até 24 h quando necessário. Após a
  janela, apagar somente a cópia Stream. Em produção desde o lote 9 (fundação
  `190300`, audiência `190400`, expiração `190500`, R2 `190600`); a
  expiração ainda depende de agendador (pg_cron ou worker), que não existe.
- **Momentos:** R2 por padrão; Stream apenas por publicação nova/popular ou
  tráfego medido, sem janela fixa arbitrária; permitir nova promoção.
- **Acontece:** R2 por padrão; Stream somente por necessidade medida.
- **Chat:** R2; Stream não é requisito do MVP.
- **Formulários:** `forms.responses.export` gera um arquivo XLSX com as
  respostas do formulário. Não gerar uma exportação por resposta e não
  inventar CSV, ZIP ou PDF. O artefato fica privado no R2.
- Demais importações/exportações reais do Superadmin ficam pós-MVP; botões
  permanecem visíveis e honestamente indisponíveis.

## Execução e evidência

Para cada item de implementação autorizado (diagnóstico permanece leitura):

1. reproduzir o defeito ou definir o critério verificável da funcionalidade;
   nomear ator, tenant, recurso, capability e provedores;
2. rastrear schema, migration, grants, RLS, RPC/Edge/Worker, R2 e Stream;
3. escrever o teste antes da correção e provar sucesso e negativas;
4. aplicar forward-only em produção na ordem da fila, com backup por ponto no
   tempo ligado (ADR 0034);
5. provar o pacote no remoto com dados sintéticos minimizados e cleanup;
6. atualizar o rastreador no mesmo turno com ação, estado, evidência, bloqueio
   e ETA.

Regras medidas na Rodada 3 (10/09/2026) que valem daqui em diante:

- O ledger `supabase_migrations.schema_migrations` de produção não espelha os
  arquivos locais (51 versões só remotas, 121 só locais). Aplicabilidade de um
  pacote é decidida por **presença de objeto** em `pg_proc`/`pg_class`, com
  `supabase db query --linked` somente leitura, nunca pelo carimbo. O mapa por
  migration fica em `docs/reviews/evidence/etapa-2/r03-coordenacao/`.
- Conferir `supabase backups list` antes de aplicar: em 10/09 o projeto estava
  com `pitr_enabled: false`, o que retém a fila até decisão do Owner. Registrar
  `blocked-environment` com a capacidade exata ausente, nunca `remote-green`.
- Migration só pode ser corrigida no arquivo quando seus objetos estão
  ausentes em produção; presença parcial exige migration nova forward-only.
- "pgTAP verde" só vale com o perfil de replay declarado (manifesto
  FoundationOnly, perfil nominal ou projeto descartável com a lista de
  migrations); o replay integral da cadeia não reproduz produção.
- Nunca usar `supabase db dump --dry-run` em sessão de agente: imprime a
  credencial do pooler de produção na saída.
- A janela de replay local (mutex do harness e porta 54322) é reservada no
  próprio JSON do grupo antes do uso; quem não reservar usa projeto descartável
  próprio em outras portas.

Regras medidas na Rodada 4 (noite de 10→11/09/2026, ADR 0034 Decisão 13):

- Produção não recebeu as migrations em ordem de carimbo. O espelho local só
  reproduz produção seguindo
  `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`:
  `db reset` com só a baseline em `supabase/migrations/` (baseline + seed) e
  depois `psql` de cada arquivo na ordem do lote. `db reset` com `migrations/`
  inteira falha em `20260910170100` e `170800`. O coordenador mantém esse
  arquivo a cada lote.
- `supabase db query --linked -f` executa o arquivo inteiro numa transação:
  `ALTER TYPE ... ADD VALUE` vai em arquivo próprio anterior (erro 55P04 se
  não). O ledger é preenchido à mão (`version`, `name`) no mesmo lote.
- Preflight de vários grupos no mesmo espelho, em sequência: um trigger
  defeituoso de um pacote (caso do 220400 na primeira versão) derruba os
  pgTAP dos demais; a primeira falha inesperada em outra família é sinal para
  reconstruir o espelho antes de devolver o pacote.
- MFA fora do MVP: `requires_mfa` falso em todo o catálogo e
  `app_private.has_mfa_aal2()` aceita `aal1`; pacote novo nasce sem exigência
  de AAL2.
- Ator do Superadmin: os usuários existem só no realm interno v2; RPCs
  baseadas em `current_person_id()`/`has_platform_permission` só os alcançam
  pela ponte de ator (`20260910220400`: pessoa de serviço + membership
  espelhada por trigger + fallback em `current_person_id()`). Pacote novo do
  Superadmin prefere `require_superadmin_internal_context`.
- Dado sintético em produção entra por RPC da rota normal ou por migration
  idempotente com pgTAP (caso do perfil interno de `qa-r03`, 171200), nunca
  por `insert` direto.
- Anon perdeu todos os grants diretos (240500, 190900) e authenticated perdeu
  TRUNCATE/REFERENCES/TRIGGER (240600); os grants CRUD de authenticated sem
  policy correspondente estão levantados como pendência de revisão profunda.
  A causa raiz era o privilégio padrão do Supabase (`ALTER DEFAULT PRIVILEGES
  FOR ROLE postgres IN SCHEMA public GRANT ... TO anon`): as migrations
  revogavam de `PUBLIC` e o grant explícito a `anon` sobrevivia. `190900`
  revogou o padrão; função nova só chega a `anon` por grant explícito na
  própria migration. Doze funções `SECURITY INVOKER` de `public` continuam
  executáveis por `anon` (guardadas por RLS) e ficam para a revisão profunda.
- Presença do nome não prova o corpo: `list_visible_happens_feed` constava
  1/1 no mapa por migration, mas o corpo em produção não tinha o predicado de
  retirada nem `can_withdraw`. Para migration que só faz `create or replace
  function`, a aplicabilidade se decide comparando `pg_get_functiondef` em
  produção com o texto esperado, não pela existência em `pg_proc`.
- pgTAP histórico quebra de dois jeitos: literal com aspas duplas em
  `position("...")` vira identificador e derruba o arquivo inteiro (28 erros
  em `now_publication_mvp_test`); asserções por substring de
  `pg_get_functiondef` caem a cada hardening (o feed do Agora trocou
  `now_viewer_has_context` por `now_viewer_role_class`). Preferir asserções
  comportamentais com fixture e ator autenticado, e helper `security definer`
  em `pg_temp` para ler o id de um ativo antes de trocar de papel.
- Memória da máquina: no máximo dois Chrome/`flutter run` por conversa, um
  `flutter test` por vez, fechar Chromes e `dart` ao fim de cada prova. Em
  11/09 às 00:27 a máquina reiniciou por esgotamento e todas as conversas
  caíram; o dump de um lote ficou vazio e teve de ser refeito.
- Chat do Superadmin (administrativo e Principal) roda no realm interno v2
  em produção desde o lote 9: 12 RPCs `superadmin_chat_*_v2` (`inbox`,
  `unread_total`, `thread`, `send_message`, `edit_message`, `revoke_message`,
  `mark_read`, `realtime_refresh`, `set_pinned`, `set_flag`, `create_group`,
  `group_members`), capacidades `chat.internal.read` (owner, operations),
  `chat.internal.send` e `chat.internal.manage` (owner), envelope spec-039
  `{ok, data, error{code, message, http_status, correlation_id}}`, códigos
  `CHAT_*`/`SAI_*`; outro tenant responde `CHAT_NOT_FOUND` (não enumera).
  Contrato completo em `comunicacao/realm-interno.json` → `contrato`.
  `chat.attach` continua sem função de escrita em `chat_attachment_metadata`
  e sem Edge Function `chat-media`: depende do gateway de mídia comum.
- Reescrever migration histórica sobre a baseline exige, além dos labels
  `NOT NULL`: `app_private.audit_append_superadmin_internal` com 13
  argumentos (o histórico chamava com um 14º `jsonb` que produção não tem),
  `requires_mfa=false` e sessões `aal1` nas fixtures. As suítes históricas
  `superadmin_internal_chat_v2_test`, `..._receipts_edit_revoke_test` e
  `..._preferences_test` não valem sobre a baseline; as `*_baseline_test.sql`
  as substituem.
- `ALTER DEFAULT PRIVILEGES ... REVOKE ... FROM anon` não protege função
  nova: testado no descartável, função criada depois continua executável por
  `anon` via `PUBLIC` (`proacl` nulo). A única proteção é o
  `revoke all on function ... from public, anon, authenticated, service_role`
  explícito antes do `grant execute` mínimo, em cada função de cada pacote.
- Prova em produção de uma família de RPCs: script Deno que entra por senha
  com `qa-r03` (GoTrue) e chama as RPCs por PostgREST com
  `Prefer: params=single-object`, credenciais só no ambiente do processo
  (`Invoke-ChatInternalProductionProof.sh` lê `Coelo-backups/qa-r03.env` e a
  chave anon do CLI em memória), saída só `PASS|FAIL|SKIP` por caso e modo
  `--read-only` para reconferir sem escrever na conversa de outra frente.
  Padrão reutilizável em
  `packages/coelo_database/scripts/chat-internal-production-proof.ts`.
- Dado sintético que gerou auditoria não pode ser apagado: `audit.audit_logs`
  (append-only) referencia `institution_id`, pessoa, membership e identidade
  interna por FK. A limpeza arquiva (`status=archived`, `deleted_at`, nome
  marcado "QA ...") em vez de `delete`, e a fixture reativa ao ser reaplicada.
  Fixture e limpeza nascem em par, com ids fixos por prefixo do grupo,
  registrados no JSON e no inventário de P37.
- Não há `psql` na máquina: usar o do container
  (`docker exec -i supabase_db_<project_id> psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f -`)
  para aplicar pacotes e rodar pgTAP no descartável (`-qtA`, contando `ok`
  e `not ok`).

Regras medidas na Rodada 5 (11/09/2026, tarde):

- Worktree nova não herda o vínculo do CLI com o projeto: `supabase ... --linked`
  falha com `LegacyProjectNotLinkedError` até copiar
  `packages/coelo_database/supabase/.temp/` (ignorado pelo Git) de um checkout
  já vinculado, ou rodar `supabase link --project-ref evvbomzejfijozbtgvpt`.
  Conferir com `supabase migration list --linked` antes do primeiro lote.
- Cada conversa Claude com o MCP `dart` ligado sobe um servidor de análise
  (`dartaotruntime`, 700 a 900 MB); com oito conversas a máquina ficou com
  0,02 GB livres às 12:20 sem nenhum Chrome pesado. Frentes de backend puro não
  precisam desse MCP; o coordenador avisa o Owner em uma linha quando a RAM
  livre cai abaixo de 1 GB e não mata processo de outra conversa.

- **Provar com a ordem real de produção, não só com a fila do grupo.** O
  pgTAP do P32 passou no descartável da frente e falhou no espelho do
  coordenador porque, entre os pacotes do grupo, entraram a ponte do Principal
  (`20260911130000`) e `person_handles`. Antes de entregar, `git fetch` e
  aplicar no descartável as migrations que outros grupos publicaram em
  `migrations/` depois da abertura, na ordem do arquivo. A fixture de teste
  precisa ser idempotente diante dos gatilhos de espelho da ponte (membership
  com `not exists`), senão quebra na ordem real (caso do 190000).
- **Pessoas de serviço não são destinatárias nem "equipe".** As pontes
  `220400` (Superadmin) e `130000` (Principal) espelham identidades internas
  como `people.person_type = 'service'` com membership na instituição. Toda
  consulta que enumera equipe da unidade/instituição para notificar, listar ou
  contar filtra `person_type = 'adult'`.
- **Identidade interna escopada em instituição (achado de segurança, lote
  44).** O espelho da ponte grava a membership escopada como
  `platform_membership` sem escopo; qualquer helper que consulte
  `has_platform_permission` antes do realm interno concede capacidade de
  plataforma a uma identidade escopada. Corrigido na Agenda
  (`20260911211200`: com vínculo interno ativo só a membership interna de
  plataforma decide); latente em produção (0 identidades escopadas em
  11/09). Pendência de revisão profunda: provar por família (Rotina, Cuidado,
  Assiduidade, Cardápios, Suporte) e corrigir a raiz na ponte.
- **RPC people-based que resolve o ator por `person_auth_links` diretamente**
  (caso de `app_private.circular_actor`) ignora a pessoa de serviço e nega o
  Superadmin com `active_membership_required`. Resolver por
  `app_private.current_person_id()` (lote 41).
- **"Presente em produção" mede objeto e forma.** A migration histórica de
  R2 de Circulares constava presente (funções existiam) mas o corpo de
  `prepare_circular_media_upload` não conhecia `storage_provider`; a
  reaplicação idempotente entrou como `20260911190200`. Conferir
  `pg_get_functiondef` pelo trecho que distingue a versão.
- **pg_safeupdate do PostgREST:** `DELETE`/`UPDATE` sem `WHERE` dentro de
  função (mesmo em tabela temporária) falha com 21000 pela API e passa no
  pgTAP via psql. Regra: sempre `where true`; a prova precisa de
  `load 'safeupdate'` como `supabase_admin` (hotfix `20260911170200`, que
  bloqueava vínculos de criança desde o lote 12).
- **Grants sem policy: revogar presence-based** (`20260911210100`): calcular
  na aplicação a lista de tabelas com RLS ligada, grant a `authenticated` e
  sem policy para o comando; revogar; exigir zero ao final; só NOTICE para
  tabela com RLS desligada; nunca lista fixa (o local concede mais que a
  produção). Escopo restrito a `public/app_private/audit/analytics`
  (`storage`/`realtime` são do Supabase).
- **Arquivos no R2 seguem o contrato em três tempos** (chat `210200`,
  Formulários `210300`/`210800`): `prepare` (authenticated, registro
  `pending` com chave opaca e ticket de 30 min), `authorize_finalize` +
  `finalize` (service_role pela Edge Function após HEAD/sha256/dimensões),
  `authorize_read` (TTL 300 s, auditado) e `expire` (cron). Uma única frente
  escreve cada Edge Function: em 11/09 G3 e G5 escreveram `form-media` em
  paralelo e a reconciliação custou uma hora.
- **Constraint trigger diferido para regra de hierarquia** (P36,
  `20260911210400`): `deferrable initially deferred` nas duas tabelas
  (definição e vínculo), mensagem estável (`P36_ACTIVITY_REQUIRES_GROUP`) e
  NOTICE das linhas que já violam.
- **`has_platform_permission(text)` depois do P7 conta membership de
  instituição**: catálogo de plataforma (Planos) e RPC sem instituição usam
  `has_scoped_platform_permission(p, null)` (`20260911200000`; perfil de
  instituição com `plan.change` criava plano da plataforma).
- **Sessão de teste compartilhada:** `account.logout`, `account.sessions` e
  o Sair do shell revogam todas as sessões do `qa-r03` no servidor e derrubam
  as outras frentes (`SAI_SESSION_INVALID`). Não é "sessão única por
  usuário" (2 sessões coexistiram em produção). Provas de Sair só no fim da
  rodada, com aviso; nas demais, fechar a aba.
- **`db query -f` interrompido no meio de um lote:** cada arquivo é uma
  transação; retomar conferindo por objeto (`pg_proc`/`pg_class`) quais já
  entraram antes de reaplicar e inserir o ledger.
- **Edge Function nova precisa de deploy + secrets + Vault no mesmo turno**
  (chat-media: `CHAT_MEDIA_WORKER_SECRET`, `CHAT_MEDIA_ALLOWED_ORIGINS`,
  Vault `chat_media_worker_url/secret`); a lista de origens dos secrets não é
  legível pelo CLI (só o hash), então ao regravar `COELO_ALLOWED_ORIGINS`
  escrever a lista completa (três origens `coelo.me` + portas locais das
  frentes).

Regras medidas pelo grupo estrutura na Rodada 4 (21 pacotes, 180000..180350):

- Migration histórica pode nunca ter aplicado em lugar nenhum: a de
  Avaliações (`20260901182838`) tinha um parêntese a menos em
  `superadmin_assessment_context_options` ("unexpected end of function
  definition") e ambiguidade variável × coluna em
  `assessment_v2_save_configuration` (resolvida com `#variable_conflict
  use_variable`). Recarimbar exige aplicar no espelho antes de entregar.
- "Fixture ausente" pode ser cadeia ausente: `activity_v2_denied_envelope`
  não existia porque nenhuma das onze migrations de Atividades v2 estava em
  produção (0 objetos na baseline). Medir presença por objeto de toda a cadeia
  antes de diagnosticar um pacote isolado.
- `app_private.audit_append_superadmin_internal` tem 13 argumentos em
  produção; a sobrecarga de 14 (metadado `jsonb`) só existe depois de 180060.
  Preflights que exigem 14 abortam; o metadado do override de reserva saiu
  (o `reason_code` já carrega o fato).
- 180060 faz `create or replace` em três funções compartilhadas que existem
  em produção com outro corpo (`audit_activity_change`,
  `has_activity_capability`, `audit_mask_payload`): pendência de code review
  pós-MVP, registrada por action_id.
- pgTAP 1.3 do projeto descartável não tem `has_fk`/`has_check` com quatro
  argumentos: afirmar por `pg_constraint` (`contype`, `conname`, `conrelid`).
- Fixtures na forma de produção: `units` usa `unit_type_id` → `unit_types`,
  `handle` NOT NULL com `^[a-z0-9][a-z0-9._]{1,28}[a-z0-9]$` e
  `units_plan_inheritance_check` (`inherit_plan=false` quando há
  `plan_override_id`); `plans.description` exige ≥ 1 caractere; o handle de
  instituição segue `^[a-z0-9][a-z0-9._-]{2,29}$` pelo trigger; `insert`
  direto em `activity_definitions` exige o marcador interno da cadeia v2
  (`app_private.activity_v2_internal_marker`) com `created_by_person_id`
  nulo, senão `guard_activity_v2_actor_provenance` nega.
- AAL1: `require_superadmin_internal_context` devolve `requires_mfa` no
  contexto mas nunca negou AAL1, e o lote 8 zerou `requires_mfa`. Asserções
  que esperavam `SAI_MFA_REQUIRED` do Owner em AAL1 afirmam o comportamento do
  MVP (nove suítes ajustadas na R04, com comentário no próprio teste);
  negativas cross-tenant, anon, sessão expirada e permissão revogada ficam.
- Padrão de RPC de criação no realm interno v2
  (`superadmin_institution_create_v2`, 180340): reutiliza o validador
  ROOT+ADDRESS do edit_core, exige escopo de plataforma, cria sempre em
  `draft`, recibo por `request_id`, replay devolve o recibo sem novo evento de
  auditoria, helpers privados sem grant a cliente.
- Catálogo de produção nasceu sem `institution_types` (0), com 1 `unit_type`
  e 0 `plans`; nenhum caminho de criar instituição funciona sem tipo ativo.
  Dado de catálogo entra por migration idempotente por `code` (180320), nunca
  por `insert` manual.
- Grants padrão do schema `public`: `activity_locations` e
  `activity_templates` tinham ALL para `anon`/`authenticated`; o pacote que
  toca a tabela revoga a escrita e mantém só o SELECT governado por policy
  (230013, 180090).
- Espelho por grupo em portas próprias (613xx) com `preflight.sh` e um mapa
  suíte → migration: cada suíte roda depois da última migration que ela cobre
  (as de Atividades v2 só depois de 180080; a de Avaliações depende do
  marcador da cadeia v2). Prova integral = espelho novo + lotes por `psql` +
  candidatos na ordem dos carimbos, repetida a cada candidato novo.

Priorizar o primeiro gate backend que permite fechar a subtela selecionada,
reutilizando readers, migrations e provas já válidas. Pacote verde vai para
produção no mesmo turno; não acumular fila de candidatos. Só Cloudflare pode
ficar aguardando decisão nominal, e nesse caso registrar o responsável pelo
desbloqueio e continuar as ações independentes.

Não habilitar RLS em lote sem policies e testes: a auditoria remota registrou
achados de RLS em `app_private`; consultar a evidência datada e o rastreador
atual para a quantidade e estado. Não tratar contagem histórica como fato vivo.
Não aplicar cauda de migrations em lote diante do drift de ledger.

Pacote revisável não é pacote aplicável: exercer a aplicação sobre a base
nominal, incluindo constraints e defaults vigentes, além das guardas de
dependência. Ao inserir ou atualizar `platform_permissions`, fornecer
`module_label`, `screen_label` e `action_label`. A migration
`20260811215451` acrescenta esses campos e os torna `NOT NULL`; o bridge
temporário do replay local e a remoção de defaults em `20260831130726`
precisam ser considerados ao verificar omissões históricas. Um teste com
defaults ou constraints relaxados não comprova aplicação do pacote nominal.
Esta regra incorpora a revisão L02/R02 e preserva a distinção entre fonte,
preflight local e produção; não autoriza editar migrations já aplicadas.

## Estados e encerramento

- `pending-verification`: certificado atual ainda ausente; não significa inexistência
  de implementação. Consultar as evidências históricas antes de refazer código;
- `audited`: inventariado e aberto;
- `fail-closed`: seguro, porém indisponível;
- `blocked-decision`/`blocked-environment`: depende de decisão ou ambiente;
- `local-green`: provas locais verdes;
- `remote-green`: todos os provedores remotos aplicáveis e negativas verdes;
- `done`: todos os gates do backend da unidade comprovados;
- `regressed`: evidência anterior deixou de valer.

Supabase verde sem R2/Stream aplicável não é `done`; R2 verde sem RLS,
autorização e metadados também não é. No encerramento, diferenciar atividade
concluída, unidade Backend `done` e produto ainda pendente.

## Regras da Rodada 6 (11/09/2026, noite)

- **Usuários sintéticos por grupo (ADR 0034 Decisão 17/19):** além de
  `qa-r03`, existem `qa-r06-estrutura`, `qa-r06-acessos`,
  `qa-r06-formularios`, `qa-r06-principal`, `qa-r06-realm`,
  `qa-r06-publicacoes` e `qa-r06-operacoes` (`@coelo.me`), criados pela API de
  administração do Auth e semeados pelo lote 49
  (`20260911230100_qa_r06_group_users_seed_v1`: identidade interna, Owner de
  plataforma, perfil, ponte de ator, membership owner nas `qa-r04-*`).
  Credencial só em `C:/Users/adrie/Documents/Coelo-backups/qa-r06-<grupo>.env`
  (`QA_EMAIL`/`QA_PASSWORD`); cada frente, Claude ou Codex, usa só o seu, e
  "Sair" de uma não derruba as outras. Roteiro de criação: script local que
  lê a chave `service_role` pelo CLI (`supabase projects api-keys`), chama
  `POST /auth/v1/admin/users` com `email_confirm`, gera senha aleatória e
  grava só o `.env`; nunca `insert` em `auth.users`. A semente SQL é
  idempotente por e-mail e, no espelho sem auth users, é no-op.
- **Identidade interna escopada nunca herda capacidade de plataforma** (lotes
  50 e 52, `20260912210000` + `210100`): `has_platform_permission(text)` com
  um argumento devolve `false` para membership espelhada com escopo de
  instituição; só `has_platform_permission(text, uuid)` com a instituição
  certa concede. O sincronizador "Superadmin vê tudo" (130000) é escopado
  pela fonte única `app_private.superadmin_internal_actor_scope_targets()`
  (plataforma → todas as instituições, inclusive em rascunho; instituição →
  só a própria). Pacote que mude o papel concedido pelo sync (P48, lote 55)
  altera só o papel, nunca a fonte do escopo. Lição do lote 50: o filtro
  "só instituições ativas" desativou as memberships de `qa-r04-escola`
  (rascunho) e exigiu hotfix; escopo não filtra por status.
- **Pacote marcado "pronto" não muda de conteúdo:** se a frente corrigir o
  arquivo depois de marcá-lo pronto, nasce um pacote novo (hotfix) com
  carimbo próprio; o coordenador aplica o que leu na revisão do ACK.
- **Pacote que toca função de outra frente nasce sobre o corpo mais novo em
  produção** e roda a suíte da outra frente no preflight (o 130400 da G4 foi
  retido por derrubar `internal_actor_scope_root_v1_test` e reescrito).
- **Ambiguidade variável × coluna em plpgsql:** `superadmin_assessment_configuration_read`
  (180350) e `form_save_draft` (230004) respondiam 42702 em produção. Regra:
  função com `search_path=''` nunca declara variável homônima de coluna usada
  em `select … into` ou em predicados; usar `#variable_conflict use_variable`
  ou prefixar (`next_…`) e aliasar a tabela.
- **Conta:** `superadmin_account_sessions_list_v1` lista só as sessões do
  próprio `auth.uid()`; revogar as outras é `signOut(scope: others)` do GoTrue
  (auditado em `auth.audit_log_entries`), sem Edge Function nem
  `service_role` (P43, lote 50).
- **Usuário interno novo** (170800, lote 55): `superadmin_internal_user_create_authorize_v1`
  (operador) + `superadmin_internal_user_create_for_worker_v1` (`service_role`)
  com a Edge Function `internal-user-create` fazendo `auth.admin.createUser`.
  A função foi implantada pela coordenação da R07 em 11/09/2026 após registrar
  `[functions.internal-user-create] verify_jwt = false` no `config.toml`
  (OPTIONS sem JWT; o POST reautoriza pelo RPC), usando
  `supabase functions deploy internal-user-create --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database`.
  O e-mail de definição de senha depende de SMTP próprio (P51): o SMTP padrão
  do Supabase só entrega a membros do time.
- **CORS do R2:** os três buckets aceitam `https://{superadmin,admin,app}.coelo.me`
  e `localhost`/`127.0.0.1` nas portas 3000, 3009, 3010, 3014, 3016, 3018 e
  3020 (regra `coelo-apps-signed-put-get`, reescrita pelo MCP da Cloudflare
  em 11/09 21:35). Frente que precisar de outra porta usa uma da lista.
- **Regressão comparada:** para pacote transversal, rodar todas as suítes,
  reverter as funções tocadas no mesmo descartável, reexecutar só as
  vermelhas e exigir resultado idêntico (padrão de
  `evidence/etapa-2/r06-realm-interno/regressao-pgtap-2026-09-11.md`).
- **180060 fechado sem decisão de produto:** `has_activity_capability` exigir
  `instructor` não muda comportamento (a tabela de turma só recebe
  `instructor`; admins vivem em `activity_admin_assignments`).
- Detalhe por frente em `docs/reviews/evidence/etapa-2/r06-*/skills-deltas*.md`
  e em `acessos-pessoas.json` → `PROPOSTA_DE_ATUALIZACAO_DAS_SKILLS_R06`.

## Pendências vigentes — Etapa 2 após R07

Fonte vigente: `docs/reviews/etapa-2-operacao/next-round/R07-fechamento.md`
e `R08-backlog.md` no mesmo diretório; substituem gates R01–R06 superados.
Decisões visuais/de conteúdo: `R07-decisoes-owner-20260912.md`, ADR0034 Decisão20.

- Próximo lote SQL56; espelho/Docker não verificado após o incidente R07.
  Sem pgTAP e dump do lote, não aplicar SQL novo em produção.
- internal-user-create v3 e circular-media v13 foram implantadas; falta o
  fluxo funcional pela UI, não outro deploy genérico. OPTIONS precisa ser
  medido: resposta204 não tem corpo; cliente Supabase usa x-client-info.
  CORS do bucket não prova CORS da Edge Function. Origem3014 foi medida.
- Pendentes: cliente de mídia, expiração agendada Agora, RLS transversal e
  resíduos de cuidado/concorrência de @ discriminados na varredura R01–R07.
  180060 está resolvido quanto à decisão de papel; CHECK é revisão separada.
- Segredos permanecem somente no cofre/arquivo privado; skill registra nomes
  e roteiro, nunca valores. Credencial QA exposta exige recibo de rotação.
- Recibos por revisão/SHA distinguem teste relatado, execução local, deploy,
  SQL aplicado e BE done; contagem local não certifica produção.
