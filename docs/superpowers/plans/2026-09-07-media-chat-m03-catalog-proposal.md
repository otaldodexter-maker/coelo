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
  mensagem visível com arquivo incompleto. Não assumir remoção do binding ao
  apagar/arquivar mensagem: soft-delete não dispara cascade e o receipt de
  comando referencia messages com ON DELETE RESTRICT. Um comando futuro de
  desvinculação precisa preservar receipts e retenção; não faz parte desta
  primeira fatia. Cleanup confere TODOS os usos antes de remover um objeto.

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
| authenticated, JWT real | prepare_chat_images_v1(uuid request_id, uuid conversation_id, jsonb declared_inputs) | Derivar ator/escopo, reservar uma intenção/mensagem invisível compartilhada pelo lote e uma sessão/ativo por entrada; devolver IDs opacos |
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
operação não serve. Claim inicial retorna lease opaca com versão e prazo;
receipt persistido contém somente estado/IDs, nunca o token. Retry idêntico
com lease ativa devolve estado opaco `lease_active`, sem token ou execução
duplicada; claim não comprova que decoder iniciou. Nenhuma transação SQL fica
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

Não adotar a ordem anterior intenção → upload → ativo → contexto como protocolo
fechado. O parecer Engenheiro 2 de 22:32 BRT encontrou restrições parciais dos
writers que devem ser conciliadas antes de escolher a ordem total. O envio
textual existente começa por conversa antes de request/receipt; suspensão
interna bloqueia membership antes de auth_link. Advisory criado somente pelo
M03 não cerca revogadores. O protocolo abaixo é candidato, não garantia de
ausência de deadlock ou de atomicidade com o provedor Auth.

Complete exige versão/token/lease vigentes e hash exato de outputs; replay de
receipt também exige autorização atual. Escrita parcial no R2 nunca produz
ready: registrar os objetos reservados para cleanup repetível, sem expirar
masters amplamente. Send só consome conjunto integralmente ready, com bindings
atômicos e recibo distinto do hash textual v2 já existente.

Negativos adicionais: authenticated chamando complete; serviço sem ticket;
ticket/session/lease adulterados; revogação authorize→claim e claim→complete;
dois claims concorrentes; lease expirada; mesmo request com outputs divergentes;
R2 parcialmente gravado; send/discard concorrentes. Ainda não executados.

## Conciliação concorrente nominal — parecer de 22:32 BRT

Fontes locais conferidas: U=`20260901210000_superadmin_internal_users_directory.sql`
linhas 459–527 e 580–618; P=`20260811215451_access_profile_management_v2.sql`
linhas 721–738; C=`20260901101500_superadmin_internal_chat_v2.sql` linhas
90–98 e 284–317. Parecer completo preservado no main em
`docs/reviews/evidence/etapa-2/engenheiro-2/plano-e-revisoes-2026-09-07.md:285`.

### Resolver e fronteiras de autorização

Candidato privado `require_chat_image_upload_actor_v1(upload_session_id)`:
carregar somente as cinco âncoras persistidas (auth_user, auth_session,
internal_identity, internal_auth_link, internal_membership). Não selecionar a
membership ativa mais recente nem aceitar substituição de link para um upload
anterior. Derivar papel/escopo/capability atuais e a instituição da conversa;
conferir sessão exata, usuário confirmado e validade atual. O tipo de contexto
existente não traz versões; possui `resolved_institution_id`, mas o helper
vigente retorna NULL nesse campo. Derivar instituição pela conversa, sem
pressupor que o campo já foi resolvido.

O helper JWT vigente é STABLE e não bloqueia linhas; não transplantar sua
volatilidade nem fabricar JWT/GUC no executor privilegiado. A assinatura e
origem AAL do adaptador persistido dependem da revisão E2E1; preservar AAL1/AAL2.
Após qualquer espera por bloqueio, reler o estado sob snapshot apropriado e
conferir ticket/lease com clock_timestamp, não timestamp do início da transação.

### Restrições e ordem candidata de M03

| Recurso / writer existente | Restrição para complete, send e discard |
| --- | --- |
| Conversa / envio textual C | Adquirir conversa antes do request/receipt de Chat; nenhum caminho M03 pode adquirir receipt textual e depois esperar conversa |
| Membership e auth_link / suspensão U | Membership original antes de auth_link original; bloqueio de leitura conflitante com UPDATE de status, não apenas KEY SHARE |
| Profile interno e scopes / edição U | M03 não precisa ler nem bloquear profile pessoal; membership cerca esse writer nominal de scopes. Não adicionar profile depois de membership |
| Role/grants / atualização P | Bloqueio conflitante no role antes da leitura final dos grants cerca P nominal; não prova exclusão de todo INSERT/DML filho nem protege predicado ausente universalmente |
| Contexto infantil / trigger | Não acrescentar lock infantil após conversa; autorização interna não depende de participante infantil |
| Auth users/sessions / GoTrue | Parecer nominal posterior identifica users antes de sessions, com FOR SHARE conflitante; versão remota e composição recovery/E1 continuam gates, não substituídos por advisory Coelo |

Ordem candidata atualizada após parecer GoTrue: resolver referências sem
autorizar por elas → auth.users → auth.sessions → conversa → intenção
idempotente nominal → sessões de upload por UUID → ativos por UUID →
membership → auth_link → role → permission → grant → revalidação final →
mutação e receipt → auditoria. AMR/proveniência ainda dependem do contrato E1;
não adicionar lock AMR depois de sessions, pois os writers MFA podem adquirir
AMR antes da sessão. Qualquer inversão identificada é bloqueante. Leitura
inicial é apenas descoberta; conferir novamente todas as referências depois
de bloquear, sem permitir troca do conjunto descoberto. A imutabilidade das
âncoras e da conversa na sessão deve ser constraint/trigger, não convenção.

Namespaces de intenção/receipt de upload/claim/complete/discard não reutilizam
o hash textual v2. O novo send deve fechar assinatura e idempotência por ator,
request, conversa, texto e conjunto ordenado de uploads. Se consumir receipt
compartilhado de Chat, seguir conversa → request → receipt; não chamar o envio
textual com anexos depois de já persistir uma mensagem vazia. Mapear os recursos
comuns reais antes de concluir se existe ciclo de deadlock. Não adquirir os
advisories de governança last-owner/realm sem necessidade demonstrada.

### Linearização dos três comandos

- Complete: transação curta, lease/token/versão e autorização atuais, outputs
  exatos para os objetos reservados, ready + receipt + auditoria atômicos. Não
  faz decode/R2 mantendo locks. Replay reautoriza antes de devolver receipt.
- Send: mesma disciplina de sessão/ativo, conjunto inteiro ready e pertencente
  à reserva da mensagem/conversa/ator, então mensagem + bindings + consumed_at
  + receipt atômicos. Ready prévio não autoriza envio após revogação.
- Discard autenticado: só reserva ainda não consumida e sem bindings. No mesmo
  protocolo, marcar descarte e invalidar lease antes de agendar cleanup. Se
  send venceu, discard nega e não desvincula mensagem. Se discard venceu,
  complete/send negam; outputs externos tardios não podem virar ready. Um
  delete físico R2 ocorre fora da transação, com rechecagem de usos e objetos
  nominais; falha é repetível. Rechecagem seguida de delete não basta: estado
  persistido de descarte deve impedir qualquer novo binding durante todo o
  delete externo, inclusive por futuro comando de reuso. Esse comando não
  pode reativar um ativo cujo cleanup já foi autorizado. Política/assinatura do cleanup de sistema após
  expiração precisa pacote próprio, não reutiliza sessão humana expirada.

Revogação que efetivamente conclui primeiro deve impedir complete/send.
Se complete vence as barreiras e confirma primeiro, ready precede a revogação;
não apagar esse histórico retroativamente. Decisão de recorte recebida do
Coordenador em 2026-09-07: complete/send exigem autorização ATUAL após locks,
cinco âncoras originais exatas e lease/expiração válidas. Não acrescentar
invalidação histórica permanente suspend→reactivate sem geração monotônica
aprovada; tampouco alegar detecção de transição que o modelo não registra.
A validade técnica da origem AAL/sessão permanece sujeita à revisão E2E1.

### Matriz local de duas conexões — preparada, NÃO executada

Todas as linhas usam fixtures sintéticas e duas conexões A/B, com barreiras
determinísticas e timeouts limitados. Não usar sleep como prova de ordenação.
Eng1 continua único operador do perfil/replay; esta proposta não cria runner.

| Corrida | Ordem A vence / ordem B vence | Oráculos obrigatórios |
| --- | --- | --- |
| Revogar sessão, auth_link ou membership × complete/send | Revogador confirma antes da checagem final / comando segura barreira antes do revogador | Negação sem novo efeito na primeira; efeito anterior à revogação na segunda; nenhum ator/link substituído |
| Trocar papel ou reduzir escopo × complete/send | Writer U confirma antes / depois das barreiras M03 | Reavaliar contexto original e instituição real; não usar snapshot de grant |
| Grant deny/revoke ou role inativo × complete/send | Writer P confirma antes / depois | Capability atual; provar writer nominal e documentar limite do DML fora dele |
| Conversa read-only × complete/send | Lifecycle confirma antes / comando segura conversa antes | Nenhum envio após mudança vencedora; ausência de inversão com linha infantil |
| Lease expira durante espera | A mantém lock até prazo passar, B retoma | B usa relógio atual e não torna ready; receipt não revive lease |
| Dois claims do mesmo request | A confirma / A aborta | Uma lease utilizável, replay exato; payload divergente nega |
| Dois completes / complete × discard | A confirma / B confirma primeiro | Uma transição válida; outputs divergentes negados; descarte invalida lease |
| Send × discard | Send confirma / discard confirma | No primeiro, binding e receipt preservados; no segundo, zero mensagem/binding |
| Replay após revogação ou substituição de membership | Novo contexto ativo diferente do original | Sem receipt autorizado por identidade substituta e sem nova escrita |
| R2 parcial ou tardio após descarte | Saída incompleta / saída chega após invalidar lease | Zero ready indevido; cleanup somente objetos reservados e sem usos |
| Cleanup autorizado × tentativa de novo binding | Delete R2 pendente com ativo descartado | Inserção/reuso negados durante e após o delete; não deixar binding apontar para objeto removido |

Para cada execução futura observar SQLSTATE/envelope, status do ativo/sessão,
mensagem, binding, consumed_at, receipt, auditoria e ausência de deadlock. Antes
de rodar, fechar fixtures nominais Auth, nomes de RPC e hashes do pacote. Não
contabilizar esta matriz como testes ou prova de concorrência executados.

## DDL nominal do lote — candidato para review, não migration

Decisão técnica do Coordenador em 2026-09-07: prepare **em lote**, uma intenção
imutável e um `reserved_message_id` servidor para todas as entradas. Não
aceitar message/actor/institution IDs do cliente. Prepare singular foi
substituído, pois reservas independentes não poderiam compor a mesma mensagem.

Busca de E2E3 e busca independente Eng2 (evidência main, seção 445) não
encontraram máximo numérico aprovado de anexos por mensagem no Chat. Não
transferir quatro de Circulares ou seis de Acontece. A ausência do máximo
impede habilitar prepare produtivo; o CHECK `expected_count > 0` abaixo é
integridade estrutural, **não** autorização para lote ilimitado. O comando
precisa do máximo aprovado antes de existir como endpoint habilitado.

DDL das auxiliares fechado abaixo para revisão de nomes/tipos/FKs. Depende
do ramo shared do catálogo A/B descrito acima; não aplicar isoladamente.
Não cria outro catálogo universal nem altera Auth. Nenhum SQL foi executado.

```sql
create table app_private.media_upload_intents (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  conversation_id uuid not null references public.conversations(id) on delete restrict,
  reserved_message_id uuid not null unique,
  auth_user_id uuid not null,
  auth_session_id uuid not null,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  internal_auth_link_id uuid not null
    references app_private.superadmin_internal_auth_links(id) on delete restrict,
  internal_membership_id uuid not null
    references app_private.superadmin_internal_memberships(id) on delete restrict,
  expected_count integer not null check (expected_count > 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (internal_identity_id, request_id)
);

create table app_private.media_upload_sessions (
  id uuid primary key default gen_random_uuid(),
  intent_id uuid not null references app_private.media_upload_intents(id) on delete restrict,
  media_asset_id uuid not null unique references public.media_assets(id) on delete restrict,
  display_order integer not null check (display_order >= 0),
  declared_name text not null check (
    char_length(declared_name) between 1 and 255
    and btrim(declared_name) <> '' and declared_name !~ '[[:cntrl:]]'
  ),
  declared_mime_type text not null check (declared_mime_type in (
    'image/jpeg','image/png','image/webp','image/heic','image/heif'
  )),
  declared_byte_size bigint not null check (
    declared_byte_size > 0 and declared_byte_size <= 10485760
  ),
  declared_sha256 bytea not null check (octet_length(declared_sha256) = 32),
  transient_bucket text not null check (transient_bucket = 'coelo-transient-prod'),
  transient_object_key text not null unique check (
    btrim(transient_object_key) <> '' and transient_object_key !~ '[[:cntrl:]]'
  ),
  preview_bucket text not null check (preview_bucket = 'coelo-media-prod'),
  preview_object_key text not null unique check (
    btrim(preview_object_key) <> '' and preview_object_key !~ '[[:cntrl:]]'
  ),
  state text not null default 'prepared' check (state in (
    'prepared','leased','ready','consumed','discarded'
  )),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  lease_token_hash bytea,
  lease_version bigint,
  lease_expires_at timestamptz,
  claim_request_id uuid,
  consumed_at timestamptz,
  discarded_at timestamptz,
  unique (intent_id, display_order),
  check (expires_at > created_at),
  check ((
    (lease_token_hash is null and lease_version is null
      and lease_expires_at is null and claim_request_id is null)
    or (octet_length(lease_token_hash) = 32 and lease_version > 0
      and lease_expires_at > created_at and lease_expires_at <= expires_at
      and claim_request_id is not null)
  ) is true),
  check ((state <> 'leased' or (
    lease_token_hash is not null and lease_version = version
    and lease_expires_at is not null and claim_request_id is not null
  )) is true),
  check (state <> 'discarded' or lease_token_hash is null),
  check ((
    (state = 'consumed') = (consumed_at is not null)
    and (state = 'discarded') = (discarded_at is not null)
    and not (consumed_at is not null and discarded_at is not null)
    and (consumed_at is null or consumed_at >= created_at)
    and (discarded_at is null or discarded_at >= created_at)
  ) is true)
);

create table app_private.media_upload_finalize_tickets (
  token_hash bytea primary key check (octet_length(token_hash) = 32),
  upload_session_id uuid not null
    references app_private.media_upload_sessions(id) on delete restrict,
  operation text not null check (operation = 'chat_image_finalize'),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  check (expires_at > created_at),
  check (consumed_at is null or consumed_at >= created_at)
);

create table app_private.media_upload_command_receipts (
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  operation text not null check (operation in ('prepare','claim','complete','send','discard')),
  request_id uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  intent_id uuid not null references app_private.media_upload_intents(id) on delete restrict,
  response jsonb not null check ((jsonb_typeof(response) = 'object'
    and response - array['state','intent_id','upload_session_ids',
      'asset_ids','message_id','version']::text[] = '{}'::jsonb) is true),
  created_at timestamptz not null default clock_timestamp(),
  primary key (internal_identity_id, operation, request_id)
);

create table app_private.media_variants (
  id uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  rendition text not null check (rendition = 'preview'),
  storage_provider text not null check (storage_provider = 'r2'),
  bucket_id text not null check (bucket_id = 'coelo-media-prod'),
  object_key text not null check (btrim(object_key) <> '' and object_key !~ '[[:cntrl:]]'),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp')),
  byte_size bigint not null check (byte_size > 0 and byte_size <= 4194304),
  checksum_sha256 text not null check (checksum_sha256 ~ '^[0-9a-f]{64}$'),
  width integer not null check (width > 0 and width <= 2560),
  height integer not null check (height > 0 and height <= 2560),
  created_at timestamptz not null default clock_timestamp(),
  unique (media_asset_id, rendition),
  unique (storage_provider, bucket_id, object_key)
);

alter table app_private.media_upload_intents enable row level security;
alter table app_private.media_upload_intents force row level security;
alter table app_private.media_upload_sessions enable row level security;
alter table app_private.media_upload_sessions force row level security;
alter table app_private.media_upload_finalize_tickets enable row level security;
alter table app_private.media_upload_finalize_tickets force row level security;
alter table app_private.media_upload_command_receipts enable row level security;
alter table app_private.media_upload_command_receipts force row level security;
alter table app_private.media_variants enable row level security;
alter table app_private.media_variants force row level security;
revoke all on app_private.media_upload_intents, app_private.media_upload_sessions,
  app_private.media_upload_finalize_tickets, app_private.media_upload_command_receipts,
  app_private.media_variants from public, anon, authenticated, service_role;
```

Master reside em media_assets; sessão reserva `preview_bucket/object_key`
imutáveis ANTES do claim, e `media_variants` guarda somente preview nesta
fatia. O teto 4 MiB/2560 é envelope máximo de foto, não perfil visual novo.
Formato/dimensões precisos da rendição continuam vinculados ao decoder aprovado.
Não há FK sessão→Auth: logout não pode ser impedido por RESTRICT nem adquirir
uploads via CASCADE/SET NULL depois de auth.sessions. UUIDs originais são
imutáveis e revalidados no servidor; não é permissão concedida pelo registro.
`reserved_message_id` não referencia mensagem inexistente. Não há FK reversa
obrigatória ativo→upload que criaria ciclo de inserção.

Triggers nominais obrigatórios no mesmo futuro pacote, antes de qualquer grant
de execução (ainda não implementados):

- `media_upload_intent_immutable_guard`: rejeitar UPDATE das cinco âncoras,
  conversa, request/hash, message reservado, expected_count e created_at.
- `media_upload_session_identity_guard`: imutáveis intent/asset/ordem,
  declarações/localizadores transitório e preview/reserva/expiração original; transições de estado e
  lease exclusivamente por comandos, versão crescente, descartado terminal.
- `media_upload_batch_shape_guard`: constraint trigger DEFERRABLE INITIALLY
  DEFERRED verifica no commit exatamente expected_count sessões, ordem contígua
  0..N-1, todos ativos shared da mesma instituição/mensagem/ator. Nunca recontar
  após descartar removendo sessão: proveniência e ordem são preservadas.
- `media_upload_ready_proof_guard`: ready/consumed exige master e preview
  verificados correlacionados aos objetos reservados; variante preview deve
  ter bucket/key iguais aos campos imutáveis da sessão. Claim retorna somente
  essas reservas; verified_outputs não define retroativamente uma chave.
  Confirmar objetos master/preview distintos pela hierarquia/UUIDs reservados.
  Não aceita provas
  declaradas. Binding exige reserva consumed no mesmo commit e ativo não
  descartado. Constraints diferidas evitam dependência circular de ordem de
  INSERT mensagem/binding/consumed, mas não dispensam validação final.

Índices de FK necessários: intenção por conversation/auth-link/membership;
sessão por intent já coberto UNIQUE; ticket por upload_session/expires_at;
receipt por intent; variante por asset já coberto UNIQUE. Sem índice em URL,
nome de pessoa ou payload. Resolver nomes de constraints globais existentes
antes dos ALTERs A/B; não gerar DROP a partir de suposição.

### Contratos de lote, hashes e replay

Além das quatro assinaturas da tabela de boundary:

```text
public.send_chat_images_v1(
  p_request_id uuid, p_conversation_id uuid,
  p_body_text text, p_upload_session_ids uuid[]
) returns jsonb                 -- authenticated/JWT real
public.discard_chat_image_v1(
  p_request_id uuid, p_upload_session_id uuid
) returns jsonb                 -- authenticated/JWT real
app_private.require_chat_image_upload_actor_v1(
  p_upload_session_id uuid
) returns app_private.superadmin_internal_context
```

Helper privado sem EXECUTE cliente/serviço. Descobre âncoras sem bloquear
upload primeiro, adquire a ordem nominal e revalida todas. AAL persistido da
linha exata aceita apenas aal1/aal2, negando NULL/aal3; não equivale ao JWT
antigo. users.email_confirmed_at, deleted_at, banned_until e sessão.user_id/
not_after são condições atuais após locks. Ban mantém sessão no GoTrue; testar
somente existência de session seria insuficiente. Recovery/proveniência é
dimensão separada ainda sob E1; não copiar IsRecovery upstream ou inventar
negação geral de OTP/MagicLink. AMR ausente/ambíguo não autoriza por AAL.

Prepare hash inclui versão de contrato, conversation e array ordenado completo
de declarações normalizadas, com JSONB canônico server-side; identidade vem do
contexto. Nulo/array vazio, entrada não-objeto, campos extras, declarações
inválidas e ordem/cardinalidade fora da intenção são negados antes de reservar.
Replay divergente conflita. Send hash inclui versão, conversation, texto
normalizado pela regra textual existente e uploads na ordem de apresentação;
**locks ordenam UUIDs**, hash não reordena a intenção do usuário. Após locks,
send reautoriza e confere hash/receipt: replay permitido devolve o resultado
antes do teste de não-consumido, pois o envio anterior já consumiu a reserva.
Somente send NOVO sem receipt requer todo lote não descartado/consumido e ready;
nenhum subset silencioso. A política
de substituir um item descartado exige nova intenção, sem reciclar asset.

Receipts contêm só IDs/estado/versão, nunca URL/ticket/token de lease ou nome de
arquivo. Decisão nominal do Coordenador: hash não permite recuperar token
original; replay do claim retorna `lease_active`/ocupado, sem segredo, sem
disparar decoder e sem alegar processamento iniciado. Perda de resposta não
autoriza rotação antecipada. Após expiração, reaquisição exige autorização
atual e nova tentativa ligada à MESMA intenção/reserved_message_id, não nova
mensagem. Dono legítimo pode concluir antes; replay reautoriza e devolve o
resultado permitido. Complete replay confirma resultado após auth/hash e antes
de exigir lease ainda ativa; não recria lease. Sem polling automático. O
receipt textual v2 permanece intocado.

Negativos obrigatórios antes do endpoint: resposta de claim perdida com lease
ativa não emite token/não roda decoder; reaquisição antes da expiração nega;
depois do prazo e após autorização atual emite nova lease/versão na mesma
intenção; complete da lease anterior nega após reaquisição; complete vencedor
antes do prazo permite replay autorizado sem nova escrita; revogação durante
espera nega reaquisição e replay; bytes/outputs divergentes conflitam. Estes
casos ainda não foram executados.

### Statements da matriz de duas conexões

Peças para o harness exclusivo Eng1, IDs sintéticos predefinidos, **não
executadas**. Abrir A com BEGIN, executar statement, manter transação; iniciar B
no comando nominal; observar espera pelo lock por inspeção de pg_locks/
pg_stat_activity sob usuário técnico local; COMMIT/ROLLBACK A, então oráculos.
Repetir invertendo vencedor. Timeouts limitados; sem sleep como prova.

| A mantém após statement | B / oráculo após commit A |
| --- | --- |
| `delete from auth.sessions where id = :session_id` | complete/send negam sessão ausente, sem ready/mensagem/receipt de sucesso |
| `update auth.users set banned_until = clock_timestamp() + interval '1 hour' where id = :user_id` | complete/send negam apesar da sessão existente |
| `update auth.users set deleted_at = clock_timestamp() where id = :user_id`, seguido de DELETE sessions | complete nega; nenhuma inversão users→sessions |
| `update public.conversations set is_read_only = true where id = :conversation_id` | send nega sem binding/mensagem |
| writer U `superadmin_internal_user_change_status(...)`, argumentos exatos do catálogo | complete/send reavaliam membership e auth_link originais, sem substituição |
| writer P `access_profile_update_v2(...)`, argumentos exatos do catálogo | complete/send reavaliam role/permission/grant; DML direto permission.status tem negativo separado |
| complete com lease válida antes da transição ready | discard espera; inversão do vencedor impede ready tardio ou mantém efeito anterior válido |
| send com IDs de duas sessões em ordem inversa à conexão B | locks por UUID eliminam inversão do conjunto; um envio atômico e replay/payload divergente distinguíveis |

Esses DMLs modelam efeitos de GoTrue, não execução HTTP do provedor. Não
contabilizar como verificação de todos writers MFA/refresh/downgrade. O gate
E1 de AMR/proveniência ainda pode exigir ajustar a ordem antes do runner.

Revisão independente do delta nominal: reserva de preview, ordem de replay
send e integridade de lease corrigidas; sem novo bloqueante documental.
Não é aprovação de migration executável. Máximo de anexos, helper E1,
decoder e concorrência executada permanecem gates. Memória no-op para o DDL:
candidato técnico não promovido como comportamento produtivo aprovado.

## Decoder: recomendação técnica pendente de decisão nominal

Recomendação de review: Images binding como processador auxiliar, lendo stream
privado e devolvendo bytes normalizados para R2. Não usar Images hosted/storage,
URL pública, cache público ou redirecionamento ao bruto em caso de falha.
Nenhuma configuração, dependência, custo ou recurso foi ativado.

- Binding aceita stream, informa formato/dimensões via info e processa via
  input/transform/output. Info/HEAD/magic bytes não comprovam decode completo.
  Emulação local é baixa fidelidade; produção exige teste nominal autorizado
  de alta fidelidade. [Cloudflare binding](https://developers.cloudflare.com/images/optimization/binding/)
- WebP/PNG descartam metadata segundo documentação geral. JPEG exige
  metadata:none na API geral, mas esse campo NÃO consta de ImageTransform ou
  ImageOutputOptions do binding: não forçar o campo JavaScript nem afirmar
  JPEG saneado pelo binding. Avaliar saída WebP/PNG permitida pela ADR.
  Orientação e perfil de cor são aplicados antes do descarte. Provar por
  inspeção independente de fixtures EXIF/GPS/XMP/ICC, não só por flag booleana.
  [Cloudflare metadata](https://developers.cloudflare.com/images/optimization/features/#metadata)
  e [tipos oficiais do binding](https://github.com/cloudflare/workerd/blob/main/types/defines/images.d.ts).
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

Parecer adicional Engenheiro 2 recebido em 2026-09-07 22:11 BRT distingue
explicitamente cf.image/API geral do binding. Seu inventário GET não comprovou
entitlement: consulta de plano falhou por autenticação. Pricing e tutorial R2
também divergem em pré-requisito Free/Paid. Nenhuma franquia/plano habilitado
está garantido; a decisão nominal continua aberta. Limites do fornecedor (20 MB,
lado/pixels/formato) devem ser reconciliados sem reduzir os da ADR por inferência.

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
