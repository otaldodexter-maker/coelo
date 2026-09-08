---
title: "M03 — evolução nominal do catálogo e binding Chat"
source: "ADR 0032; crosswalk E2E3; migrations citadas; reserva local do Coordenador em 2026-09-07"
status: "proposed-technical-package; requires-review; no-migration"
generated_at: "2026-09-07"
---

# Escopo nominal

Primeira vertical: imagem de Chat no Superadmin, com catálogo compartilhado.
Não constitui conclusão da plataforma nem substitui Avisos, Convites, Circulares,
Acontece, Agora, Momentos, Para Você, Perfil ou cabeçalho global no escopo E2E3.
Somente proposta: nenhum SQL aplicado ou arquivo de migration criado aqui.

Evoluir `public.media_assets`, sem outro catálogo universal. Usar
`public.chat_attachment_metadata` como binding de mensagem para ativos novos,
sem duplicar localização física, checksum, status ou proprietário. Sessões e
variantes são auxiliares do mesmo ativo. As demais verticais permanecem no
crosswalk até pacotes de cutover próprios; não migrar objetos por inferência.

## Base e incompatibilidades verificadas

| Base local em packages/coelo_database/migrations | Contrato que permanece |
| --- | --- |
| 20260820182000_happens_publication_mvp.sql:40 | media_assets exige instituição/post/pessoa, status happens, MIME JPEG/PNG/WebP/MP4, UNIQUE(object_key), UNIQUE(post_id,upload_request_id) |
| Mesmo arquivo:60 | media_links é binding Acontece, FK asset RESTRICT, ordem 0–5; não reutilizar para Chat |
| 20260820182100_happens_media_security_closure.sql | finalize busca id+post e remove exige post draft; proprietário não pode virar NULL no ramo legado |
| 20260812000000_chat_production_contract.sql:14 | attachment metadata exige mensagem, pessoa e descritor físico completo; SELECT contextual atualmente concede todas as colunas |
| 20260901101500_superadmin_internal_chat_v2.sql:39 | mensagem possui autor person/internal, FKs e trigger identity/membership; não fabricar pessoa para ator interno |
| Mesmo arquivo:231/277 | thread v2 projeta metadata, não asset_id; send v2 tem três parâmetros e hash textual persistido |

Não existe tabela `public.tenants` nesta cadeia inspecionada. Para Chat,
o escopo institucional deriva de mensagem → conversa → institution_id.
Não adicionar FK imaginária nem aceitar tenant informado pelo cliente.
`tenants/<scope_uuid>` no path é nomenclatura da ADR, não nova autoridade.

## DDL candidato A: discriminar sem alterar o ramo legado

Na mesma transação de evolução de `public.media_assets`:

- Adicionar `catalog_kind text NOT NULL DEFAULT 'happens_legacy'`, allowlist
  `happens_legacy/shared`; ramo não pode ser alterado após INSERT.
- Relaxar `post_id`, `owner_person_id` e `byte_size` junto ao CHECK discriminado.
  Ramo legado exige ambos NOT NULL; ramo shared exige ambos NULL. Manter FK
  post com CASCADE: shared nunca aponta para post, logo não herda esse cascade.
- `institution_id` continua NOT NULL nesta primeira vertical. Identidade global
  e platform são extensões futuras do mesmo catálogo, não implementadas aqui.
- Adicionar `scope_kind`, `domain`, `entity_type`, `entity_id`, `purpose` text/UUID
  conforme tipo. Shared exige exatamente `tenants`, `communication`,
  `chat-message`, UUID reservado pelo servidor e `image`. A matriz é ampliada
  nominalmente por finalidade, não com texto livre ou nome de app.
- Adicionar `created_by_internal_identity_id` e
  `created_by_internal_membership_id`, FKs RESTRICT para as estruturas
  internas existentes. Shared da primeira vertical exige ambos; legacy exige
  ambos NULL. Trigger confere identity/membership; são proveniência, nunca
  autorização nem novo ownership. A instituição/conversa e capabilities são
  revalidadas pelo gateway em cada operação.
- Manter status enum atual: pending até finalização, ready após prova completa,
  quarantined/deleted. Encoding/processamento pertence a sessão/job, não
  inventar `ready` paralelo na metadata. Não alterar enum nesta fatia imagem.
- Reusar bucket_id/object_key como localização do master Coelo final reservada
  pelo servidor; objeto ainda pode não existir enquanto pending. Upload bruto
  transitório pertence à sessão, não substituir o master pelo bruto.
- Shared exige provider=r2, bucket=coelo-media-prod e MIME JPEG/PNG/WebP.
  Enquanto pending, byte_size/checksum/dimensões finais permanecem NULL;
  dados declarados ficam na sessão. Ready exige checksum SHA256,
  dimensões positivas e bytes finais até 4 MiB
  e maior lado até 2560 px para foto comum. Entrada até 10 MiB/36 MP validada
  no processamento; não confundir byte_size declarado com prova de conteúdo.
- Acrescentar width/height inteiros; constraints shared condicionais envoltas
  em `(... ) IS TRUE`, com testes NULL explícitos. Ramo legacy preserva seus
  limites anteriores, incluindo byte_size NOT NULL no CHECK de ramo, sem ser
  forçado a ter dimensões históricas. Não gravar estimativa como tamanho final.
- Preservar original_name/upload_request_id legados. Em shared, original_name
  recebe nome sanitizado de apresentação, não path; request_id canônico de
  sessão preenche upload_request_id. A constraint única por post continua
  somente legado; sessão fornece unicidade real para shared com post NULL.
- Não remover UNIQUE(object_key) nesta primeira fatia: todas as chaves novas
  contêm UUIDs de ativo/objeto. Troca para unicidade provider/bucket/key pode
  ocorrer nominalmente se necessária; não relaxar sem teste/crosswalk.

Constraint nominal: `media_assets_catalog_shape_check`; trigger imutabilidade
`media_assets_catalog_identity_guard`; trigger de proveniência
`media_assets_internal_creator_guard`. Identificadores das constraints
existentes devem ser resolvidos por catálogo antes do DDL, sem adivinhar nomes
gerados para DROP. Não remover check global MIME: a primeira fatia é subconjunto.

## DDL candidato B: Chat binding, não segundo descritor físico

- Adicionar `media_asset_id uuid NULL REFERENCES public.media_assets(id)
  ON DELETE RESTRICT`; wire usa `asset_id`, Dart usa `ChatAttachment.assetId`.
  `ChatAttachment.id` continua metadata.id, inclusive no ramo canônico.
- Acrescentar `display_order smallint` para novo ramo, com unicidade por
  mensagem/ordem somente quando media_asset_id NOT NULL. Não impor UNIQUE
  global no ativo: múltiplos bindings não significam cópia de binário.
- Relaxar NOT NULL de provider/object_key/content_type/byte_size/sha256/
  upload_status/created_by_person_id junto a
  `chat_attachment_metadata_catalog_shape_check`. Ramo legado (asset NULL)
  exige valores anteriores completos e explicitamente NOT NULL. O CHECK total
  usa `(... ) IS TRUE`, impedindo aceitação por UNKNOWN. Ramo canônico exige esses campos NULL;
  file_name/message_id permanecem binding/apresentação. Defaults legados não
  devem preencher o ramo novo: writer fornece NULL explicitamente.
- Trigger `chat_attachment_metadata_asset_scope_guard` exige ativo shared,
  domínio/finalidade corretos, ready, instituição da conversa real igual à do
  ativo e mensagem correspondente à reserva consumida. A sessão preserva o
  message UUID e consumed_at mesmo após exclusão do binding: ausência de
  bindings não devolve autorização nem torna o ativo "novo". Criação de uso adicional exige comando nominal autorizado; um
  simples INSERT privilegiado não é política de reuso.
- Nenhum cliente pode escrever diretamente. Ativo precisa de sessão do ator
  e conversa, integralmente finalizada. Atomicidade send+binding impede
  mensagem visível com arquivo incompleto. Delete de mensagem remove binding,
  não objeto; cleanup confere TODOS os usos e retenção antes de remover.

Metadata física dos anexos novos vem do JOIN autorizado ao catálogo no RPC.
Ramo legacy continua com sua projeção existente. Nunca retornar bucket/key
ou credenciais nos envelopes. `load_happens_draft` ainda tem key histórica;
isso é dívida da sua vertical, não prova de conformidade global.

## Auxiliares e sequência de upload a fechar antes de implementar

Nomes candidatos `app_private.media_upload_sessions` e
`app_private.media_variants`; RLS/FORCE, sem grants de tabela para
anon/authenticated/service_role. Acesso por RPC nominal mínimo, não bypass
genérico. Antes de criar, confirmar não existência equivalente no catálogo.

Sessão precisa conter asset FK, request UUID/hash por ator, conversa FK,
message UUID reservado, ator/auth-link/membership/session reais, objeto
transitório opaco, MIME/bytes/checksum declarados, expiração e estado.
Variantes precisam de asset FK, perfil/rendição allowlisted, localização
física opaca, MIME/checksum/bytes/dimensões verificados e unicidade por ativo/
perfil; não carregar nova entidade proprietária.

1. Prepare com JWT real reautoriza chat.internal.send e conversa, seguindo
   a política AAL vigente do helper interno (adiamento MFA existente, sem
   inventar exigência diferente nesta vertical).
2. Reserva UUID de mensagem sem INSERT visível e ativo pending; idempotência
   por ator/request com hash completo de intenção. Nenhuma chave cliente.
3. PUT temporário no transitório via gateway/credencial server-side.
4. Finalize reautoriza, decodifica/limita pixels/normaliza/remove EXIF/GPS,
   gera master+preview e persiste metadados verificados. Decoder/limites de
   CPU/memória/dependência ainda precisam pacote nominal revisado.
5. Send publica mensagem e binding na mesma transação; reserva consumida uma
   vez e retry retorna receipt sem duplicar. Asset ready isolado não é público.
6. Read reautoriza mensagem ativa, conversa/ator/capability/audiência e ativo
   ready; resposta opaca para MediaReader. Nenhuma URL física em thread DTO.
7. Discard/cleanup não remove ativo com usos. Expiração é de transitório/ticket,
   não retenção inventada do master. Falha de delete é repetível e auditada.

As assinaturas RPC, hashes e locks deste fluxo são o próximo review técnico;
este documento não se apresenta como DDL executável completo.

## Boundary nominal de finalize para review

Precedente local: `20260821112822_moments_publication_mvp.sql:554–680`
separa authorize autenticado de finalize privilegiado com ticket opaco. Reusar
o princípio, não sua identidade people nem sua verificação baseada em tamanho
declarado/HEAD. Nenhum claim JWT sintético para representar ator interno.

Assinaturas candidatas (nomes ainda sujeitos à reserva de migration):

| Executor | RPC candidata | Responsabilidade |
| --- | --- | --- |
| authenticated, JWT real | prepare_chat_image_v1(uuid request_id, uuid conversation_id, jsonb declared_input) | Derivar ator/escopo, reservar ativo/sessão/mensagem invisível; devolver IDs opacos |
| authenticated, JWT real | authorize_chat_image_finalize_v1(uuid upload_session_id) | Reautorizar; emitir ticket de operação vinculado à sessão/ator reais |
| service_role somente | claim_chat_image_finalize_v1(uuid request_id, uuid upload_session_id, uuid ticket) | Consumir autorização, revalidar contexto persistido, reservar lease e devolver localizadores físicos somente ao gateway |
| service_role somente | complete_chat_image_finalize_v1(uuid request_id, uuid upload_session_id, uuid lease_token, jsonb verified_outputs) | Revalidar contexto/lease, gravar provas verificadas e tornar ready atomicamente |

Prepare aceita apenas nome de apresentação/MIME/bytes/checksum declarados e
limitados; nunca bucket, key, owner ou instituição autoritativa. O gateway
encaminha o bearer real para as RPCs autenticadas. O cliente não pode chamar
complete com dimensões/checksum inventados: ACL exclusiva do executor servidor,
sem grants de escrita na tabela. O gateway calcula outputs dos bytes relidos e
normalizados, nunca copia campos finais do corpo do cliente.

Ticket aleatório: armazenar somente hash, operação, upload_session, IDs reais
de identity/auth-link/membership/auth-session, expiração e consumo. Claim e
complete conferem correspondência integral; ticket roubado de outro ativo ou
operação não serve. Claim retorna lease opaca com versão, prazo e receipt;
retry idêntico não inicia outro processamento. Nenhuma transação SQL fica
aberta enquanto o decoder/R2 executa.
Lease expirada nunca é devolvida como utilizável: retry do claim informa
expired; nova tentativa exige nova autorização e nova chave de claim. A versão
é vinculada inequivocamente ao lease_token persistido e conferida em complete,
sem aceitar versão implícita do cliente.

No consumo privilegiado, um helper privado nominal deriva o contexto da sessão
de upload persistida. Revalida auth session existente/não expirada, usuário,
auth-link e membership correspondentes ativos, papel, permissão e escopo atuais,
mais conversa ativa/não-read-only. IDs livres do gateway não autorizam. A
referência de política é require_superadmin_internal_context(text), inclusive
`20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql`; extrair
núcleo comum ou mudar helper compartilhado exige reserva/review com E2E1.
Não reintroduzir MFA por inferência: o helper vigente aceita aal1/aal2.

Lock order a fechar com os writers de revogação de E2E1: intenção idempotente →
sessões de upload em ordem UUID → ativos em ordem UUID → contexto autorizado
em ordem fixa → receipt/audit. Send/finalize/discard devem compartilhar a mesma
ordem; um SELECT isolado não resolve revogação concorrente. Revalidação final
com locks compatíveis impede ready após revogação vencedora. O protocolo ainda
não está fechado enquanto essa compatibilidade não for provada.

Complete exige versão/token/lease vigentes e hash exato de outputs; replay de
receipt também exige autorização atual. Escrita parcial no R2 nunca produz
ready: registrar os objetos reservados para cleanup repetível, sem expirar
masters amplamente. Send só consome conjunto integralmente ready, com bindings
atômicos e recibo distinto do hash textual v2 já existente.

Negativos adicionais: authenticated chamando complete; serviço sem ticket;
ticket/session/lease adulterados; revogação authorize→claim e claim→complete;
dois claims concorrentes; lease expirada; mesmo request com outputs divergentes;
R2 parcialmente gravado; send/discard concorrentes. Ainda não executados.

## Decoder: recomendação técnica pendente de decisão nominal

Recomendação de review: Images binding como processador auxiliar, lendo stream
privado e devolvendo bytes normalizados para R2. Não usar Images hosted/storage,
URL pública, cache público ou redirecionamento ao bruto em caso de falha.
Nenhuma configuração, dependência, custo ou recurso foi ativado.

- Binding aceita stream, informa formato/dimensões via info e processa via
  input/transform/output. Info/HEAD/magic bytes não comprovam decode completo.
  Emulação local é baixa fidelidade; produção exige teste nominal autorizado
  de alta fidelidade. [Cloudflare binding](https://developers.cloudflare.com/images/optimization/binding/)
- WebP/PNG descartam metadata segundo documentação; JPEG exige metadata:none.
  Orientação e perfil de cor são aplicados antes do descarte. Provar por
  inspeção independente de fixtures EXIF/GPS/XMP/ICC, não só por flag booleana.
  [Cloudflare metadata](https://developers.cloudflare.com/images/optimization/features/#metadata)
- Decoder WASM RGBA integral de 36 MP precisa de 144 MB só para pixels, acima
  dos 128 MB por isolate Worker; buffers/encoder ampliam consumo. Inferência
  técnica: essa abordagem ingênua não suporta os limites aprovados. Não reduzir
  limites Coelo silenciosamente para acomodá-la.
  [Cloudflare memória](https://developers.cloudflare.com/workers/platform/limits/#memory)

Antes do uso: fechar habilitação/custo nominal com Coordenador, limites exatos
de bytes do serviço versus MiB Coelo, contagem de pixels/frames, arquivos
truncados/disfarçados, transparência/orientação, limite de saída/checksum e
fixtures reais. anim:false normaliza, não prova rejeição de GIF animado;
allowlist deve rejeitar GIF/SVG reais antes. Política para outras animações não
pode ser inventada. Decoder/scan são controles diferentes. A recomendação não
conclui M03 nem autoriza teste remoto, --remote ou billing.

## Compatibilidade e segurança bloqueantes

Preservar `superadmin_chat_send_message_v2(uuid,text,uuid)` e receipts textuais.
Não trocar seu hash por hash com anexos vazios e invalidar retries existentes.
Novo envio com mídia deve usar endpoint explícito sem overload ambíguo,
consumindo o mesmo writer privado/catálogo; definir versão/assinatura antes do
cutover. Não habilitar attachmentIds no adapter textual antecipadamente.

SELECT integral da metadata contextual é legado exigido pelos RPCs invoker
dos outros consumidores. Não revogar globalmente sem pacote compatível.
Ramo novo não armazena segredos/chaves nessa tabela; catálogo permanece sem
SELECT cliente. Preservar grants não basta: campos físicos NULL no ramo novo
quebrariam a projeção direta de chat_thread_page. É gate obrigatório adaptar
a projeção contextual por helper server-side nominal que reautoriza a conversa
e devolve somente descritor público de binding/arquivo; não conceder SELECT
integral ao catálogo para facilitar JOIN. Fechar essa assinatura, negativos
e compatibilidade antes de permitir qualquer INSERT shared produtivo.
Testar interno e pessoa contextual diretamente. Uma eventual
correção global dos grants deve ser coordenada com E2E1, não modificar apps
Admin/Principal fora do escopo para acomodar o DDL.

Filtros explícitos `catalog_kind='happens_legacy'` e comparação
`IS DISTINCT FROM` em finalização/remoção Acontece são defesa complementar
nominal; não editar migration histórica. Shared com post não pode existir.

## REDs obrigatórios para proposta de migration

Ainda NÃO executados: legacy sem post/owner; shared com post/pessoa ou campo
obrigatório NULL; issuer/membership inconsistente; MIME/status/tamanho fora de
classe; caminho adulterado; ready sem checksum/dimensões; cross-institution
binding; ativo inexistente/não-ready; mesmo objeto duplicado; idempotência
igual/conflitante; Acontece finalize/remove recebendo asset Chat; SELECT direto
por anon/authenticated/internal; mutate direto negado; revogação antes de
finalize/read; mensagem apagada não elimina ativo utilizado; replay textual
anterior ao pacote; duas sessões disputando send/finalize/discard.

Revisão independente → nomes/DDL/assinaturas fechados → RED em perfil local
exclusivo Eng1 → migration forward-only → GREEN/negativas → review → lease
remoto nominal. Nenhum passo deste plano concede lease remoto.
