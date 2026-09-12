---
source: "Gate nominal C0 R08 G3; docs/knowledge/team/superadmin-forms-production.md; docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md; RPCs existentes de respostas e form-media"
status: "local-green; composição normal e E2E pendentes C0/G0"
generated_at: "2026-09-12"
---

# Segredo de edição da resposta anônima

Recorte: `apps/superadmin -> Formulários -> Responder/Editar resposta -> forms.respond/forms.upload/forms.resolve-file`. Subaceite anônimo, sem criar novo action_id ou aumentar denominador. Base `origin/dev 2441725d5` materializada; commits anteriores do ramo de resposta R2: `dfe013cc5` e `f0c7269fd`.

## Resultado local

- O dispositivo gera 32 bytes com `Random.secure`, codifica em base64url sem padding (43 caracteres), grava via `SharedPreferencesAsync` e relê antes de abrir o rascunho. Falha de leitura/escrita/confirmacão bloqueia a abertura com mensagem e retry; segredo armazenado inválido não é substituído. Não há fallback efêmero.
- A partição local usa projeto + conta, com chave de ocorrência separada. Identificadores são usados somente para isolar o armazenamento local; não contribuem para a entropia nem são anexados ao segredo ou enviados no payload de mídia. A conta seguinte no mesmo navegador não descobre automaticamente a edição anônima da conta anterior.
- Aberturas concorrentes no mesmo runtime aguardam a mesma gravação. O segredo persistido é reutilizado em retry e após remontar a página. Outra instância de API/store/ocorrência invalida callbacks anteriores; o estado da página solta suas referências ao sair.
- `openResponseDraft`, autosave, submit e edit recebem `editSecret` nos DTOs existentes. A resposta anônima é reaberta pelo comando autorizado mesmo se a projeção contiver um rascunho; o cliente não associa automaticamente um novo segredo a conteúdo projetado.
- A Galeria anônima encaminha o segredo em prepare/finalize/discard. PUT segue somente `upload_url/required_headers`; o segredo e o JWT não entram no PUT.
- `FormsAnonymousImageReader` usa `action: download` existente, em POST autenticado, e exige o original explicitamente. A URL temporária tem TTL de até 60 segundos, contado conservadoramente desde o despacho; o viewer mantém expiração e purge da sessão. Não usa o ramo privilegiado de leitura interna como alternativa à autorização pelo segredo.
- A UI explica que a edição permanece naquele dispositivo e que apagar os dados locais impede recuperá-la. O segredo não é exibido, colocado em rota/URL, evidência ou log. Nenhum segredo real foi gerado por estes testes; fixtures são sintéticas.

O backend continua responsável por elegibilidade, escopo, posse do segredo, estado da ocorrência e separação entre participação e resposta. Nenhuma autenticação alternativa, vínculo pessoal na resposta, migration ou grant foi criado. Foto/câmera continua um gate separado.

## Composição para C0

Importar `features/forms/data/forms_anonymous_edit_secret_store.dart` e construir **uma instância estável por contexto da API/conta**, fora de `build`:

```dart
final anonymousEditSecrets = SharedPreferencesFormsAnonymousEditSecretStore(
  projectId: projectOriginOrId,
  accountId: authenticatedUserId,
);
```

Passar na rota normal:

```dart
FormResponsePage(
  api: formsApi,
  occurrenceId: occurrenceId,
  mediaSession: formsMediaScope?.current,
  mediaReader: formsMediaReader,
  anonymousEditSecrets: anonymousEditSecrets,
)
```

Não criar o store a cada rebuild: identidade nova reinicia a carga para impedir reaproveitamento entre contextos. Trocar junto com o contexto autenticado. O `SupabaseFormsApi` implementa `FormsAnonymousImageApi`, portanto a página obtém o leitor anônimo da mesma composição autorizada. Rotas `/dev` permanecem separadas. Sem store, a resposta anônima apresenta indisponibilidade honesta; identificada continua operando.

## Verificação

Slot Flutter nominal C0, concurrency 1, liberado ao terminar; nenhum processo retido.

- Primeira execução `2260`, log `07-anonymous-tests.log`: interrompida no primeiro teste ao identificar callback `whenComplete` retornando o próprio Future removido do mapa. Corrigido com callback sem retorno. Não conta como teste aprovado/falho; não houve RED de asserção concluído nesta execução.
- GREEN `64926`, log `07-anonymous-tests-final.log`: **293 casos únicos aprovados / 0 falhos**, seis arquivos: store 7, reader 40, upload 17, resposta 154, viewer 21, API 54. São 18 casos novos; os demais se sobrepõem aos pacotes anteriores e não devem ser somados.
- `07-anonymous-analyze.log`: warning de mutabilidade do fake, corrigido sem alterar código produtivo. `07-anonymous-analyze-final.log`: **0 apontamentos**.
- `git diff --check`: sem erros. Não foi executado E2E UI nem storage real de navegador neste pacote.

C0 informou form-media v17 ativa; G0 prepara smoke API de answer-image. Esse recebimento não é prova executada por G3 nem equivale à rota normal Flutter. A fixture remota, persistência/reload reais e negativo de acesso serão registradas pelo executor do runtime.

## Memória e limites

Fonte aprovada de anonimato permanece válida. Delta para o escritor central: implementação agora dispõe de guarda local particionada por projeto/conta e usa o segredo nos comandos e na mídia anônima. Somente C0 publica a projeção canônica após compor a rota. Não há decisão nova de produto, regra clínica, retenção ou autoridade. A garantia de concorrência testada é do mesmo runtime; sessões de navegador concorrentes não foram certificadas neste gate MVP.
