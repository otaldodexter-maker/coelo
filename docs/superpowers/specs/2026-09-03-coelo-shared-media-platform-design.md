---
title: "Plataforma compartilhada de mídia do Coelo"
source: "decisões explícitas do Owner em 2026-09-03; decisions/0032-mvp-private-media-r2.md; discovery Cloudflare R2/Stream; arquitetura do monorepo"
status: "approved-design"
generated_at: "2026-09-03"
updated_at: "2026-09-03"
---

# Plataforma compartilhada de mídia do Coelo

## Objetivo

Definir uma única plataforma de mídia e documentos que possa ser consumida por
Superadmin, Admin e Principal sem duplicar objetos, regras de autorização,
gateways ou código de domínio. O Site permanece separado da mídia privada e usa
o caminho público somente quando existir publicação pública explícita.

Todo recurso Supabase ou Cloudflare remoto do Coelo é produção. A Etapa 2
implementa e prova a primeira vertical por `apps/superadmin`, mas contratos,
packages e backend não podem depender do nome desse app.

Há relatos conflitantes de 2026-09-03 sobre a existência de
`coelo-media-prod`, `coelo-documents-prod` e `coelo-transient-prod`. A E2E 3
confirma primeiro a conta e o estado em inventário read-only. Se ausentes, cria
os três no pacote nominal autorizado; se presentes, valida/configura sem
recriar. Agentes nunca os renomeiam, esvaziam ou removem nessa reconciliação.

## Alternativas consideradas

1. Um bucket privado único: simples, porém mistura credenciais, retenções,
   documentos sensíveis, temporários e mídia operacional.
2. Buckets por app ou tela: isola superficialmente, mas duplica arquivos e
   cria crescimento descontrolado de recursos, policies e integrações.
3. Buckets compartilhados por responsabilidade: separa mídia, documentos e
   temporários sem atrelar o objeto ao consumidor. Esta é a decisão aprovada.

## Princípios invariantes

- Nenhuma chave contém `superadmin`, `admin`, `principal` ou `site`.
- Um ativo físico pode ter vários usos por `media_binding`, sem cópia binária.
- Supabase/Postgres é o plano de controle: identidade, relações, autorização,
  RLS, catálogo, retenção, auditoria e idempotência.
- Cloudflare é o plano de dados: R2 privado para binários e Stream somente para
  uma cópia HOT de vídeo.
- Apps enviam intenção e `asset_id`; não escolhem bucket/object key e não
  recebem segredo.
- Chave R2 não autoriza. Toda emissão de upload, preview, reprodução ou download
  revalida ator, tenant, entidade, finalidade e audiência.
- Não existem raízes globais `v1`, `v2` ou árvores recriadas. Mudança de arquivo
  cria novo ativo/objeto; versão e histórico ficam no Postgres.
- Nomes, e-mail, CPF, criança, escola, turma e nome original não entram na chave.

## Topologia de produção

### `coelo-media-prod`

Bucket privado para avatar, capa, logo, imagens, áudio, master de vídeo,
thumbnails, previews e variantes operacionais.

### `coelo-documents-prod`

Bucket privado com credencial separável para PDF, documentos e evidências
sensíveis de pessoas, saúde, segurança, atendimento, eventos, circular e chat.
Processadores de imagem não recebem acesso a este bucket.

### `coelo-transient-prod`

Bucket privado para upload ainda não finalizado, quarentena, arquivos de
processamento e exportações XLSX temporárias. Lifecycle por prefixo:

- upload incompleto: expirar após 1 dia;
- quarentena sem promoção: expirar após 2 dias;
- trabalho de processamento: expirar após 3 dias;
- exportação de Formulários: expirar após 1 dia;
- multipart incompleto: abortar no menor prazo suportado e nunca depois de 7
  dias.

Nenhuma lifecycle ampla se aplica a masters ou documentos permanentes. A
retenção do conteúdo final é definida por produto/LGPD e não é inferida pelo
bucket.

### Site público

Assets estáticos do Site ficam no build do Astro e no CDN da hospedagem. O Site
não lê os três buckets privados. Se houver mídia pública dinâmica no futuro,
criar `coelo-public-prod` somente após spec própria; publicar significa copiar
uma variante sanitizada e aprovada, nunca tornar o master privado público.

## Chave única e permanente

```text
<scope>/<scope_uuid>/<domain>/<entity_type>/<entity_uuid>/<purpose>/<asset_uuid>/<rendition>/<object_uuid>.<ext>
```

- `scope`: `people` para identidade global ou `tenants` para dado contextual;
- `scope_uuid`: pessoa global ou tenant;
- `domain`: área funcional estável;
- `entity_type` e `entity_uuid`: proprietário lógico inicial;
- `purpose`: avatar, cover, gallery, attachment, evidence e demais usos
  allowlisted;
- `asset_uuid`: identidade estável exposta aos contratos autorizados;
- `rendition`: `original`, `variants/<profile>`, `thumbnail/<size>` ou
  `preview`;
- `object_uuid`: nome opaco do objeto físico.

`platform` pode ser usado sem PII para ativos dinâmicos oficiais do Coelo; os
assets estáticos preferem o bundle do app/site.

## Matriz de domínios e finalidades

| Domínio | Entidades | Finalidades principais | Bucket |
| --- | --- | --- | --- |
| `identity` | pessoa/perfil/contexto | avatar, cover | media |
| `directory` | instituição, unidade, turma, atividade | logo, avatar, cover, gallery | media |
| `locations` | mapa, local | map-general, photo, gallery | media |
| `communication` | Acontece, Agora, Momentos, Circular, Aviso | media, cover-frame, audio, gallery | media |
| `chat` | mensagem | image, video, audio | media |
| `chat` | mensagem | attachment/document | documents |
| `agenda` | evento | cover, gallery | media |
| `agenda` | evento | attachment/document | documents |
| `forms` | formulário/pergunta | question-image | media |
| `forms` | resposta | answer-image | media |
| `care` | saúde, segurança, assiduidade | evidence-image | media |
| `care` | saúde, segurança, assiduidade | evidence/document | documents |
| `care` | rotina, cardápio | photo, image, gallery | media |
| `support` | ticket | screenshot | media |
| `support` | ticket | attachment/document | documents |
| `exports` | job de formulário | responses.xlsx | transient |

Tipo de pergunta Documento/PDF permanece fora do MVP de Formulários. A matriz
não autoriza um tipo de mídia numa superfície que não o tenha em sua spec.

## Exemplos

```text
people/<person_uuid>/identity/person/<person_uuid>/avatar/<asset_uuid>/original/<object_uuid>.jpg
tenants/<tenant_uuid>/identity/principal-context/<context_uuid>/cover/<asset_uuid>/variants/desktop/<object_uuid>.webp
tenants/<tenant_uuid>/directory/institution/<institution_uuid>/logo/<asset_uuid>/original/<object_uuid>.png
tenants/<tenant_uuid>/locations/location-map/<map_uuid>/map-general/<asset_uuid>/original/<object_uuid>.webp
tenants/<tenant_uuid>/locations/location/<location_uuid>/photo/<asset_uuid>/original/<object_uuid>.jpg
tenants/<tenant_uuid>/communication/now-story/<story_uuid>/media/<asset_uuid>/original/<object_uuid>.mp4
tenants/<tenant_uuid>/chat/chat-message/<message_uuid>/attachment/<asset_uuid>/original/<object_uuid>.pdf
tenants/<tenant_uuid>/agenda/event/<event_uuid>/gallery/<asset_uuid>/original/<object_uuid>.jpg
tenants/<tenant_uuid>/forms/form-response/<response_uuid>/answer-image/<asset_uuid>/original/<object_uuid>.jpg
tenants/<tenant_uuid>/care/health-record/<record_uuid>/evidence/<asset_uuid>/original/<object_uuid>.pdf
```

## Catálogo lógico no Postgres

O modelo compartilhado possui os seguintes contratos lógicos:

- `media_assets`: ativo físico, escopo, classificação, MIME, bytes,
  dimensões/duração, checksum, estado e retenção;
- `media_variants`: original Coelo, thumbnail, preview e derivados;
- `media_bindings`: entidade consumidora, finalidade, ordem, crop, alt text e
  vigência;
- `media_delivery_instances`: `stream_video_id`, HOT/WARM/COLD, status,
  promoção, acesso e expiração;
- `media_upload_sessions`: intenção, limites, objeto esperado, prazo e estado;
- `media_processing_jobs`: validação, normalização, thumbnail, scan e cleanup;
- `media_access_events`: emissão, consumo, negação, revogação e auditoria.

Esses nomes descrevem o modelo lógico. O repositório já contém
`public.media_assets`, `now_media_assets`, `moments_media_assets`,
`circular_media_assets`, `form_assets`, `meal_plan_image_assets` e metadados de
Chat. Antes da migration, fazer crosswalk completo e escolher evolução
forward-only. Não criar um segundo catálogo universal, não renomear/apagar
tabelas em produção e não deixar dois sistemas de ownership concorrentes.

## Contrato compartilhado dos apps

- Reusar `coelo_domain` para tipos puros e políticas que não dependem de UI.
- Reusar/evoluir `coelo_api` para `MediaGateway`, DTOs de intenção, upload,
  finalização, leitura e revogação.
- UI específica permanece em `coelo_ui_superadmin`, `coelo_ui_admin` ou
  `coelo_ui_principal`; widget não decide autorização nem path.
- Composition roots de cada app injetam a mesma implementação produtiva.
- `/dev` usa gateway fake determinístico e nunca chama Supabase/Cloudflare.
- A Etapa 2 altera somente Superadmin e packages/backend usados por ele; Admin,
  Principal e Site serão consumidores posteriores sem exigir nova arquitetura.

## Fluxo de upload

1. App informa entidade, finalidade, formato, bytes, dimensões/duração e
   checksum pretendidos.
2. Backend reautoriza e cria sessão idempotente com limite server-derived.
3. Media Gateway emite upload curto para um objeto opaco de produção.
4. Objeto não finalizado permanece invisível ao produto.
5. Worker/Edge relê cabeçalho e conteúdo, valida MIME real, bytes,
   dimensões/pixels/duração, checksum, malware e política da finalidade.
6. Normaliza o master Coelo, remove EXIF/GPS, gera variantes e registra chaves.
7. Transação final vincula o ativo à entidade e grava auditoria.
8. Falha, abandono ou revogação agenda cleanup idempotente.

## Fluxo de leitura

1. App lista entidades por RPC/repository autorizado e recebe `asset_id`, nunca
   object key.
2. App pede a rendição adequada ao tamanho da tela.
3. Backend reautoriza e emite capability/ticket curto para um objeto e operação.
4. Media Gateway entrega variante/preview; documentos sensíveis não usam cache
   compartilhado e exigem reautorização mais estrita.
5. Revogação impede nova emissão e invalida/expira tickets conforme contrato.

Feed e galerias carregam thumbnail/preview primeiro, prefetch limitado e master
somente quando aberto. O app mantém cache local limitado por bytes e remove-o
no logout, revogação ou troca de contexto sensível. O cache local é temporário, mínimo e escopado por sessão/realm; o gateway expõe o hook de invalidação e o fluxo de Auth o aciona.

## Formatos e limites

Extensão não prova formato. Cliente valida para feedback e o servidor valida de
novo antes da finalização.

| Finalidade | Entrada | Limite de origem | Master Coelo |
| --- | --- | --- | --- |
| avatar/logo | JPEG, PNG, WebP; HEIC convertido | 8 MiB, 25 MP, mínimo 256 x 256 | 1:1, até 1024 x 1024 e 2 MiB; 64/128/256/512 |
| capa | JPEG, PNG, WebP; HEIC convertido | 12 MiB, 36 MP, mínimo 1200 x 400 | 3:1, até 2400 x 800 e 3 MiB |
| foto comum | JPEG, PNG, WebP; HEIC convertido | 10 MiB, 36 MP | maior lado até 2560 px e 4 MiB |
| mapa/planta | JPEG, PNG, WebP | 20 MiB, 64 MP | maior lado até 6000 px e 8 MiB + zoom/preview |
| PDF | PDF real | 25 MiB e 200 páginas | original íntegro, scan e viewer protegido |

SVG enviado por usuário e GIF animado ficam recusados no MVP. WebP é preferido
para variantes; JPEG é fallback e PNG preserva transparência/legibilidade.

## Vídeo e Stream

- R2 guarda o master Coelo normalizado antes de qualquer promoção.
- Agora pode usar Stream HOT por até 24 horas; expiração remove somente Stream.
- Momentos usa Stream quando novo/popular ou após limiar medido, sem janela fixa
  inventada, e pode ser promovido novamente.
- Acontece usa R2 por padrão; Stream depende de métrica.
- Chat permanece R2 no MVP.
- Stream não tem pastas. `stream_video_id` é uma entrega associada ao
  `asset_uuid`; metadata do Stream ajuda operação, mas não é autoridade.

## Segurança e produção

- Buckets privados; CORS mínimo; URLs/tickets são bearer secrets de curta vida.
- `service_role`, token Cloudflare, credencial R2 e signing key ficam apenas no
  secret store de produção.
- O token exposto anteriormente está comprometido e não pode ser usado.
- Testar tenant A/B, ID adulterado, vínculo revogado, ticket expirado/reusado,
  finalidade trocada, MIME falso, excesso de bytes/pixels, malware, upload
  incompleto e cleanup.
- Aplicações remotas são forward-only, pequenas, revisadas, serializadas pelo
  Coordenador e acompanhadas de evidência e plano de recuperação.
- Nenhuma exclusão ampla, mudança de bucket público ou lifecycle global é
  permitida.

## Gates de conclusão

- Front-end `verified`: fim do cliente real, estados, validação, progresso,
  retry, preview/player, responsividade, acessibilidade e cache/logout.
- Back-end `done`: catálogo, RLS/grants, Media Gateway, R2/Stream aplicável,
  validação, negativos, auditoria, observabilidade, lifecycle e cleanup em
  produção.
- `verified-e2e`: app real → backend → Cloudflare → retorno da mídia/estado →
  persistência/reload, permitido/negado/revogado e tenant A/B.

## Fora de escopo desta decisão

- Tornar mídia privada pública para acelerar o Site.
- Criar bucket por app, tela, tenant, instituição ou tipo de extensão.
- Implementar import/export geral do Superadmin.
- Adicionar Documento/PDF como pergunta de Formulários.
- Fixar janela de Stream de Momentos/Acontece sem métricas.
- Alterar `apps/admin`, `apps/principal` ou `apps/site` na Etapa 2 atual.
