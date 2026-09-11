---
title: "Deltas propostos às skills — realm-interno, Rodada 5"
grupo: "realm-interno"
source: "candidatos/realm-interno/20260911210000..210500; handoff.md"
generated_at: "2026-09-11"
status: "proposta ao coordenador (escritor central das skills)"
---

# Deltas propostos às skills (R05, realm-interno)

O coordenador aplica nos `SKILL.md` de destino; a frente não edita skills.

## `coelo-backend` (`.agents/skills/coelo-supabase/SKILL.md`)

### Seção "Pendências de segurança que só o Owner executa" — item novo 3

**3. Chave HMAC do catálogo de identidade (`coelo_person_identity_hmac_v1`,
Vault, criada em 11/09/2026 pela migration `20260911210000`).** Guarda o
HMAC-SHA256 do CPF em `app_private.person_identity_identifiers`
(`hmac_key_version = 1`); o valor foi gerado no próprio banco
(`encode(extensions.gen_random_bytes(32),'hex')`) e nunca passou por chat,
commit, log ou JSON. Rotação (só se houver suspeita de vazamento; ela
invalida a busca por CPF das linhas antigas até um re-hash): criar a versão 2
com `select vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),
'coelo_person_identity_hmac_v2','HMAC v2')` via `supabase db query --linked`,
publicar uma migration que faça `app_private.person_identity_hmac_v1` ler a
versão 2 e gravar `hmac_key_version = 2`, e re-hashear não é possível (o CPF
não é guardado): as linhas v1 ficam válidas só para exibição da máscara. Como
gerar uma chave assim para outros catálogos: sempre no banco, com
`vault.create_secret`, nunca em arquivo.

### Seção "Execução e evidência" — regras novas

- **Provar com a ordem real de produção, não só com a fila do grupo.** Em
  11/09 o pgTAP do pacote P32 passou no descartável da frente (baseline +
  `ordem-de-aplicacao-producao.txt` + candidatos do grupo) e falhou no espelho
  do coordenador, porque entre os pacotes do grupo entraram a ponte do
  Principal (`20260911130000`) e `person_handles`. Antes de entregar, fazer
  `git fetch` e aplicar no descartável as migrations que outros grupos
  publicaram em `migrations/` depois da abertura, na ordem do arquivo.
- **Pessoas de serviço não são destinatárias.** As pontes `20260910220400`
  (Superadmin) e `20260911130000` (Principal) espelham identidades internas
  como `people.person_type = 'service'` com memberships na instituição. Toda
  consulta que enumera "equipe da unidade/instituição" para notificar, listar
  ou contar deve filtrar `person_type = 'adult'` (ou excluir `service`).
- **Grants sem policy: revogar presence-based.** O padrão do pacote
  `20260911210100` (calcular no momento da aplicação a lista de tabelas com
  RLS ligada, grant a `authenticated` e sem policy para o comando; revogar;
  exigir zero ao final; só NOTICE para tabela com RLS desligada) substitui
  listas fixas de tabelas, que divergem entre local e produção (os
  privilégios padrão do Supabase local concedem mais que a produção).
- **Anexos e arquivos no R2 seguem o mesmo contrato em três tempos:**
  `prepare` (authenticated: cria o registro `pending` com chave opaca
  `tenants/<inst>/<dominio>/<entidade>/<id>/<finalidade>/<asset>/original/<uuid>.<ext>`,
  ticket privado de 30 min, hash+tamanho anunciados), `authorize_finalize`
  (authenticated, só o dono do ticket) + `finalize` (service_role, pela Edge
  Function após HEAD/sha256/dimensões; divergência → `failed`/`deleted` +
  fila de limpeza), `authorize_read` (authenticated, escopo, só `ready`,
  auditado, TTL 300 s) e `expire` (service_role, cron). Mensagem/asset ficam
  invisíveis (`draft`/`pending`) até o `finalize`. Implementado em
  `20260911210200` (chat) e `20260911210300` (Formulários, question-image).
- **Constraint trigger diferido para regra de hierarquia.** P36 ("atividade
  ativa exige turma ativa") segue o padrão de `requires_unit`: `create
  constraint trigger ... deferrable initially deferred` em ambas as tabelas
  (definição e vínculo), mensagem estável para o cliente mapear e NOTICE das
  linhas que já violam (não bloqueia a aplicação).

### Seção "Comunicação e progresso" — nota

- A sobrecarga de 14 argumentos de `audit_append_superadmin_internal`
  (`p_after_json jsonb`, criada em `180060`) coexiste com a de 13; a resolução
  é por contagem de argumentos e nenhum papel de cliente executa nenhuma. Ao
  escrever RPC nova, usar a de 13 salvo quando houver `after_json` a guardar.

## `coelo-frontend-backend` (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`)

- **institutions.edit:** o cliente passa a fazer duas chamadas: `edit_core_v2`
  (ROOT+ADDRESS) e `superadmin_institution_contacts_edit_v1`
  (documento/contato/representantes/administradores), ambas com o mesmo
  `expected_version` encadeado (a segunda usa a versão devolvida pela
  primeira). O reload lê `representatives`/`administrators` do `detail_v2`
  com contatos **mascarados** (LGPD): o formulário mostra a máscara e só envia
  o campo se o usuário digitar um valor novo. `administrators[].handle` é
  `null` até o @ das pessoas existir.
- **chat.attach e forms.upload:** E2E só depois da Edge Function
  (`chat-media`, `form-media` em R2) e do cron de expire; até lá ficam
  `local-green` no backend com contrato publicado.
- **P36 no cliente:** o assistente de Atividades precisa vincular ao menos uma
  turma antes de publicar; mapear 23514 `activity must retain at least one
  active group link` para a mensagem da tela.

## `coelo-frontend` (`.agents/skills/coelo-flutter-review/SKILL.md`)

- Tela de políticas macro da unidade (P32): dois seletores (Segurança
  infantil: aceitar para liberar / só inclusão / só exclusão; Medicação: os
  mesmos + não acompanhar) e três chaves de notificação; `get` devolve
  `is_default` para a tela mostrar "padrão da plataforma" antes da primeira
  gravação. Sem chat em telas de edição.
