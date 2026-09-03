---
title: "Mídia privada de produção no Cloudflare R2 e Stream"
source: "decisões explícitas do Owner Coelo em 2026-09-03; anexos de discovery R2/Stream; refinamento de hierarquia, formatos e limites em 2026-09-03"
status: "approved"
generated_at: "2026-09-03"
updated_at: "2026-09-03"
supersedes: "decisions/0030-mvp-private-media-supabase-storage.md"
---

# ADR 0032 — Mídia privada de produção no Cloudflare R2 e Stream

R2 é o storage principal de todos os binários privados novos do MVP (fotos,
vídeos, thumbnails, variantes, documentos e anexos de Chat/Formulários).
Supabase/Postgres continua como fonte oficial de identidade, tenant, ownership,
autorização, metadados, retenção e auditoria. Não há mídia existente a migrar.
Superadmin, Admin e Principal consomem a mesma plataforma, ativos e contratos;
o nome do app nunca entra na chave. A Etapa 2 prova o primeiro consumidor em
Superadmin sem duplicar arquitetura. O Site usa assets estáticos no build/CDN e
não lê mídia privada; mídia pública dinâmica futura exige bucket e fluxo de
publicação próprios.

## Ambientes e buckets

Todo recurso remoto atual é produção. Não presumir conta, projeto, bucket ou
library DEV/homologação. Testes locais e emuladores continuam obrigatórios antes
do remoto, mas qualquer criação, configuração, migration, Worker ou deploy
remoto usa gate e evidência de produção.

Não criar buckets por tenant, usuário, tela ou tipo de extensão. A topologia
contém três buckets privados com responsabilidades e credenciais separáveis:

- `coelo-media-prod`: imagens, áudio e masters de vídeo operacionais;
- `coelo-documents-prod`: documentos e evidências sensíveis, inclusive PDF;
- `coelo-transient-prod`: uploads ainda não finalizados, quarentena,
  processamento e exportações temporárias.

Em 2026-09-03 surgiram relatos conflitantes sobre a existência dos três
buckets. A E2E 3 deve confirmar conta, existência e estado em inventário
read-only. Se ausentes, o pacote nominal autorizado cria os três buckets
privados; se presentes, valida e configura sem recriar. Nunca esvaziar,
renomear ou apagar bucket nessa reconciliação.

Separar buckets permite least privilege e lifecycle sem dar ao processador de
imagens acesso a documentos de saúde, nem aplicar expiração de exportação a
mídia permanente. Nenhum dos três buckets é público.

## Catálogo e chave canônica

R2 não é o catálogo do produto. O Postgres mantém pelo menos:

- `media_assets`: ativo físico, escopo, classificação, MIME real, bytes,
  dimensões/duração, checksum, estado e retenção;
- `media_variants`: original Coelo, thumbnail, preview e versões derivadas;
- `media_bindings`: usos do mesmo ativo por entidade/finalidade, ordem, crop e
  texto alternativo;
- `media_delivery_instances`: cópias HOT no Stream e seu ciclo de vida;
- sessões de upload, jobs de processamento e eventos de acesso/auditoria.

Uma chave é opaca, imutável, emitida pelo servidor e nunca fonte de
autorização. Não contém nome, e-mail, CPF, nome de escola, turma, criança ou
arquivo enviado. Existe uma única hierarquia permanente, sem pasta global de
versão:

```text
<scope>/<scope_uuid>/<domain>/<entity_type>/<entity_uuid>/<purpose>/<asset_uuid>/<rendition>/<object_uuid>.<ext>
```

- `scope`: `platform`, `people` ou `tenants`;
- `domain`, `entity_type` e `purpose`: allowlists server-side;
- `rendition`: `original`, `variants/<profile>`, `thumbnail/<size>` ou
  `preview`;
- `object_uuid` é opaco; substituir conteúdo cria novo ativo/objeto. Versão e
  histórico ficam no Postgres, sem duplicar toda a árvore como `v2`/`v3`;
- relações atuais e autorização vivem em `media_bindings`, não são inferidas
  da chave.

Exemplos de produção:

```text
# identidade e perfis
people/<person_uuid>/identity/person/<person_uuid>/avatar/<asset_uuid>/original/<object_uuid>.jpg
tenants/<tenant_uuid>/profiles/principal-context/<context_uuid>/cover/<asset_uuid>/variants/desktop/<object_uuid>.webp

# estrutura e marca contextual
tenants/<tenant_uuid>/directory/institution/<institution_uuid>/logo/<asset_uuid>/original/<object_uuid>.png
tenants/<tenant_uuid>/directory/institution/<institution_uuid>/cover/<asset_uuid>/variants/desktop/<object_uuid>.webp
tenants/<tenant_uuid>/directory/unit/<unit_uuid>/logo/<asset_uuid>/original/<object_uuid>.png
tenants/<tenant_uuid>/directory/group/<group_uuid>/cover/<asset_uuid>/variants/desktop/<object_uuid>.webp
tenants/<tenant_uuid>/directory/activity/<activity_uuid>/gallery/<asset_uuid>/original/<object_uuid>.jpg

# locais e mapas
tenants/<tenant_uuid>/locations/location-map/<map_uuid>/map-general/<asset_uuid>/original/<object_uuid>.webp
tenants/<tenant_uuid>/locations/location/<location_uuid>/photo/<asset_uuid>/original/<object_uuid>.jpg

# comunicação e eventos
tenants/<tenant_uuid>/communication/happens-post/<post_uuid>/media/<asset_uuid>/original/<object_uuid>.jpg
tenants/<tenant_uuid>/communication/now-story/<story_uuid>/media/<asset_uuid>/original/<object_uuid>.mp4
tenants/<tenant_uuid>/communication/moment/<moment_uuid>/media/<asset_uuid>/original/<object_uuid>.mp4
tenants/<tenant_uuid>/communication/chat-message/<message_uuid>/attachment/<asset_uuid>/original/<object_uuid>.pdf
tenants/<tenant_uuid>/agenda/event/<event_uuid>/cover/<asset_uuid>/variants/desktop/<object_uuid>.webp
tenants/<tenant_uuid>/agenda/event/<event_uuid>/gallery/<asset_uuid>/original/<object_uuid>.jpg

# formulários e cuidado
tenants/<tenant_uuid>/forms/form/<form_uuid>/question-image/<asset_uuid>/original/<object_uuid>.webp
tenants/<tenant_uuid>/forms/form-response/<response_uuid>/answer-image/<asset_uuid>/original/<object_uuid>.jpg
tenants/<tenant_uuid>/care/health-record/<record_uuid>/evidence/<asset_uuid>/original/<object_uuid>.pdf
```

Documentos seguem a mesma chave no bucket `coelo-documents-prod`, conforme a
entidade e a finalidade: `document`, `attachment` ou `evidence`. Não existe uma
pasta global `pdf`, porque isso separaria o arquivo de seu escopo, retenção e
autorização. PDF nunca usa Stream.

No bucket transitório:

```text
tenants/<tenant_uuid>/uploads/<upload_session_uuid>/<asset_uuid>/<object_uuid>.<ext>
tenants/<tenant_uuid>/quarantine/<asset_uuid>/<object_uuid>.<ext>
tenants/<tenant_uuid>/processing/<job_uuid>/<asset_uuid>/<object_uuid>.<ext>
tenants/<tenant_uuid>/exports/forms/<export_job_uuid>/responses.xlsx
```

Stream não replica essa árvore. O identificador `stream_video_id` e os estados
HOT/WARM/COLD ficam em `media_delivery_instances`; o `asset_uuid` é a referência
canônica no Postgres e pode ser repetido apenas como metadata não autoritativa
do Stream.

## Formatos e limites de imagens e documentos

Extensão não prova formato. Cliente faz preflight e compressão para UX; o Media
Gateway relê bytes, MIME real, dimensões, pixels totais, checksum e política da
finalidade antes de finalizar. Upload direto concluído fora do contrato é
descartado. Metadados EXIF/GPS são removidos, salvo decisão explícita de produto.

- Imagem de usuário aceita JPEG, PNG e WebP. HEIC/HEIF de celular é aceito como
  origem somente se convertido para master Coelo JPEG/WebP antes da
  finalização. SVG de usuário e GIF animado são recusados no MVP.
- Avatar/logo: origem até 8 MiB e 25 MP, mínimo 256 x 256; master até
  1024 x 1024 e 2 MiB; variantes 64, 128, 256 e 512 px. Transparência de logo
  pode preservar PNG/WebP; avatar é recortado em 1:1.
- Capa panorâmica: origem até 12 MiB e 36 MP, mínimo 1200 x 400; crop 3:1;
  master até 2400 x 800 e 3 MiB, com variantes responsivas. O Perfil Principal
  possui capa; a conta Superadmin atual possui avatar, mas não ganha capa por
  inferência.
- Foto comum (Acontece, evento, resposta, rotina e local): origem até 10 MiB e
  36 MP; master até 2560 px no maior lado e 4 MiB, além de thumbnail/preview.
- Mapa/planta: origem até 20 MiB e 64 MP; master até 6000 px no maior lado e
  8 MiB, com preview e variantes para zoom sem baixar o master na abertura.
- PDF: até 25 MiB e 200 páginas por padrão. Validar assinatura real, estrutura,
  conteúdo ativo, malware e política da superfície; viewer e download sempre
  reautorizados. Limite específico menor pode ser aplicado por domínio/plano.

Os limites são validados antes do envio quando o cliente puder medir e
obrigatoriamente de novo no servidor. Variantes preferem WebP; JPEG permanece
fallback para compatibilidade e PNG é preservado quando transparência ou
legibilidade exigir. O master é o arquivo Coelo normalizado, não o bruto 4K da
câmera, salvo documento/evidência cuja integridade exija preservar o original.

## Escopo e segurança

R2 Standard no piloto (10 GB-month, 1M Class A e 10M Class B incluídos; egress
direto gratuito). Infrequent Access fica para depois. O master sempre é salvo
primeiro no R2. A política de distribuição é por produto:

- **Agora:** promover vídeo para Stream por até 24 horas quando a publicação
  exigir reprodução adaptativa; enquanto a cópia codifica, tocar o MP4 do R2 ou
  mostrar estado de processamento. Ao expirar, remover somente Stream e manter
  o master no R2.
- **Momentos:** R2 é padrão; Stream apenas para conteúdo novo/popular ou que
  ultrapasse um limiar de tráfego medido. A janela inicial não é fixada em 30
  dias; será decidida após métricas do piloto. Pode promover novamente depois.
- **Acontece:** fotos e vídeos curtos começam no R2; Stream somente se métricas
  de tamanho, compatibilidade ou tráfego justificarem. Não usar Stream para
  todo o feed.
- **Chat:** anexos e vídeos ficam no R2; Stream não é requisito do MVP.

Video Transformations, tiering automático e transcoding complexo ficam para
spikes posteriores. Import/export geral é adiado; somente
`forms.responses.export` exporta um arquivo Excel com as respostas do
formulário; a exportação geral do Superadmin continua adiada.
No Superadmin, os botões de importação/exportação permanecem visíveis por
composição e descoberta, mas não abrem picker, não geram arquivo e informam a
indisponibilidade de forma honesta.

Flutter chama Media Gateway server-side (Edge Function Supabase inicialmente).
O gateway valida sessão, tenant, capability, audiência, MIME, tamanho e
checksum, emite presigned PUT/GET curto, finaliza, limpa órfãos e audita.
Nenhuma chave R2 ou `service_role` entra no cliente; bucket privado, CORS
restrito e negativos cross-tenant/IDOR/revogado/expirado fail-closed.

Esta ADR supersede ADR 0030. A Etapa 2 deve implementar o contrato em produção,
em pacotes forward-only pequenos, serializados pelo Coordenador, depois de
teste local, revisão, secret scan, inventário read-only e plano de recuperação.
Não autoriza exclusão destrutiva, bucket público, uso do token já exposto nem
mudança remota sem registrar o pacote nominal e sua evidência.
