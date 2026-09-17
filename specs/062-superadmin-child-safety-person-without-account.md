---
title: "Pessoa autorizada sem conta no wizard de Segurança da criança (B6)"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md (B6, owner.r12-18); decisions/0032-mvp-private-media-r2.md (bucket coelo-documents-prod, chave canônica); specs/061-superadmin-child-safety-person-search.md (B5 antecede o cadastro); specs/030-superadmin-child-safety-production.md; docs/security/auth-multitenant-permissions.md §8 (CPF e deduplicação); docs/security/lgpd-security-media.md; dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.authorized_people (document_fingerprint/document_last4, índice único authorized_people_document_fingerprint_uidx por instituição), app_private.child_safety_request_authorization, app_private.child_safety_receipt/store_receipt, app_private.person_identity_hmac_v1, app_private.cpf_digits_valid_v1, public.authorize_moments_media_finalize (tickets de finalize), Edge now-media/moments-media"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Pessoa autorizada sem conta (B6, `owner.r12-18`)

## Objetivo e decisão de produto

Quando a busca B5 não encontra a pessoa, o wizard permite cadastrar uma
**pessoa autorizada sem conta**: ela não usa o app, fica autorizada apenas no
contexto pedido pelo responsável (criança + unidade daquela solicitação) e é
visível só para esse escopo (instituição). CPF é obrigatório e é a chave de
deduplicação; a imagem do documento é obrigatória no MVP e vive em R2 privado
(ADR 0032). A pessoa pode virar conta depois (o vínculo é por
`authorized_people.person_id`, hoje nulo). Decisão do Owner na ADR 0041 B6.

## Modelo de dados

- `public.authorized_people` (existente) recebe a pessoa sem conta com
  `person_id null`, `document_type='cpf'`, `document_fingerprint` = HMAC do
  CPF normalizado (mesma chave `person_identity_hmac_v1` das identidades com
  conta, para dedupe e futura conversão), `document_last4`; **o CPF nunca é
  gravado em claro nem de forma reversível**: a restrição
  `authorized_people_document_check` passa a exigir só `fingerprint + type`
  (ciphertext opcional). Dedupe: índice único existente
  `(institution_id, document_fingerprint)` entre não arquivados.
- Colunas novas em `authorized_people`: `contact_phone_hash`,
  `contact_phone_last4`, `contact_email_hash`, `contact_email_masked`
  (contato opcional, minimizado; nunca o valor inteiro).
- `public.authorized_person_documents` (nova): um documento por pessoa sem
  conta em R2 privado — `storage_provider='r2'`, `bucket_id='coelo-documents-prod'`,
  chave opaca `tenants/<instituição>/child_safety/authorized_person/<pessoa>/identity-document/<doc>/original/<uuid>.<ext>`,
  MIME `image/jpeg|image/png|image/webp|application/pdf`, até 10 MiB,
  `status pending|ready|superseded`, checksum, ator, carimbo. RLS habilitada e
  forçada, sem grants e sem policies (deny-by-default); só RPCs leem/escrevem.
- `app_private.child_safety_person_document_finalize_tickets`: bilhete de
  finalize consumido uma vez pelo gateway (padrão dos Momentos).

## RPCs

| RPC (`public.*`, wrapper `security definer`) | Ator | Efeito |
|---|---|---|
| `child_safety_register_person_without_account_v1(p_request_id, p_payload)` | administrador do contexto (`child_safety_can_administer`) ou responsável com `manage_authorized_people` | valida contexto (criança + unidade ativos), nome (3–120), CPF (11 dígitos válidos, máscara ignorada), celular/e-mail opcionais; se já existe **pessoa com conta** com esse CPF → `22023 PERSON_HAS_ACCOUNT` (usar B5); se já existe pessoa sem conta com o CPF na instituição → devolve a existente (`existing:true`), sem duplicar; senão cria. Idempotente por `request_id` (recibo). Auditado. Resultado: `authorized_person_id`, `display_name`, `cpf_masked` (`***.***.***-NN`), `has_account:false`, `existing`, `document_status`. |
| `child_safety_person_document_prepare_v1(p_request_id, p_authorized_person_id, p_mime_type, p_byte_size)` | quem pode registrar (acima) ou o responsável dono (`owner_guardian_person_id`) | cria documento `pending` com chave opaca; devolve descritor (`document_id`, `storage_provider`, `bucket_id`, `object_key`, `mime_type`, `byte_size`); recibo idempotente. |
| `child_safety_person_document_authorize_finalize_v1(p_document_id)` | criador do documento | bilhete de finalize (2 min) + descritor. |
| `child_safety_person_document_finalize_v1(p_document_id, p_finalize_ticket, p_byte_size, p_mime_type, p_checksum_sha256)` | **service_role** (gateway) | consome o bilhete, exige bytes/MIME iguais ao declarado, marca `ready`, supera documentos `ready` anteriores da mesma pessoa; auditado. |
| `child_safety_person_document_read_v1(p_document_id)` | `child_safety.read` de plataforma na instituição, `authorized_people.manage` no contexto ou responsável dono | descritor para URL assinada de 60 s; auditado. Nunca devolve URL pública. |

`child_safety_request_authorization` (forward-only, corpo do dump de 17/09
+ um ramo): o payload aceita `authorized_person_id` no lugar de `person_id`.
Nesse ramo a pessoa precisa ser da instituição do contexto, ativa, sem conta,
visível ao ator (administrativo ou dono) e **com documento `ready`**; caso
contrário `22023 PERSON_DOCUMENT_REQUIRED` / `P0002`. O restante (relação,
capacidades, validade, notificação, auditoria, recibo) é idêntico.

## Media Gateway

Edge `child-safety-media` (modelo `now-media`, ramo R2): `prepare` → RPC de
prepare com o JWT do usuário → PUT assinado (300 s) com cabeçalhos exigidos;
`finalize` → RPC de bilhete → `HEAD` + leitura dos bytes no R2 → assinatura
real do arquivo (JPEG/PNG/WebP/PDF) → RPC de finalize com `service_role`;
`read` → RPC de leitura → GET assinado (60 s). Credenciais R2 só no servidor
(`COELO_R2_*`); CORS por `CHILD_SAFETY_MEDIA_ALLOWED_ORIGINS` (ou
`COELO_ALLOWED_ORIGINS`). Sem URL pública, sem base64 pela função, sem chave
no cliente além do `document_id`.

## Frontend (Superadmin)

- Na etapa "Pessoa autorizada", quando a busca B5 devolve vazio, aparece
  "Cadastrar pessoa sem conta": nome completo, CPF (máscara livre), celular e
  e-mail opcionais → "Cadastrar" chama o RPC; o resultado mostra nome,
  `***.***.***-NN` e "sem conta"; a pessoa fica selecionada
  (`authorizedPersonId` no comando; `personId` vazio).
- Em seguida "Enviar documento" abre o seletor (JPEG/PNG/WebP/PDF ≤ 10 MiB) e
  passa pelo gateway (prepare → PUT → finalize); "Documento enviado" libera o
  Continuar. Sem documento `ready` o wizard não avança (mesma regra do
  servidor).
- Se o servidor responder `PERSON_HAS_ACCOUNT`, a tela orienta a buscar pelo
  CPF completo (B5).
- Detalhe da criança: autorização de pessoa sem conta mostra "sem conta"
  (`has_app_account=false`, derivado de `person_id` nulo).

## Critérios de aceite e testes

- pgTAP: dedupe por CPF (segundo cadastro devolve a mesma pessoa; CPF com
  conta → `PERSON_HAS_ACCOUNT`), CPF inválido recusado, contexto fora do
  escopo do ator → `P0002`, RLS forçada e sem grants na tabela de documentos,
  descritor sem URL, finalize só com bilhete válido e `service_role`,
  `request_authorization` recusa pessoa sem documento e aceita com documento
  `ready`, leitura negada a ator alheio, auditoria gravada.
- Edge: `deno test` local (contratos do handler); deploy por
  `supabase functions deploy child-safety-media`.
- Flutter: fluxo cadastrar → enviar documento → continuar; erro
  `PERSON_HAS_ACCOUNT`; comando de salvamento com `authorized_person_id`.
- Rota real (`qa-r06-acessos`): cadastro pela tela, upload real via
  `cdp_filechooser.dart`, reload do detalhe mostrando a autorização pendente
  "sem conta", negativa cross-tenant (prepare/read com pessoa de outra
  instituição → 403/P0002) → `owner.r12-18` done.
