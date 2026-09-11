---
name: coelo-backend
description: Use when a Coelo task involves backend, Supabase, Postgres, Auth, RLS, RPCs, Edge Functions, Realtime, Cloudflare R2, Stream, Workers, Media Gateway, migrations, remote persistence, backend security, or backend completion.
metadata:
  source: "AGENTS.md; decisions/0032-mvp-private-media-r2.md; docs/reviews/coelo-supabase-pendencias.md"
  status: "active"
  generated_at: "2026-09-09"
---

# Coelo Back-end

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
rodada o coordenador remove o usuário e o que ele criou.

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
- **Agora:** master no R2; Stream HOT por até 24 h quando necessário. Após a
  janela, apagar somente a cópia Stream.
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
- Memória da máquina: no máximo dois Chrome/`flutter run` por conversa, um
  `flutter test` por vez, fechar Chromes e `dart` ao fim de cada prova. Em
  11/09 às 00:27 a máquina reiniciou por esgotamento e todas as conversas
  caíram; o dump de um lote ficou vazio e teve de ser refeito.

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
