---
source: "R08-prompts.md; R08-plano.md; R08-backlog.md; execucao G4"
status: "em execucao; primeiro pacote local verificado"
generated_at: "2026-09-12"
---

# R08 G4 — Principal, Chat e Sistema

Host: `apps/superadmin`. Worktree `e2-r08-principal-chat-sistema`, branch
`work/etapa2-r08-principal-chat-sistema`, base `6d6cbef32`.
T0 C0: 10:52:16 -03; corte 14:52:16; handoff final ate 15:02:16.

Objetivo: publicar PNG privado em Acontece/Agora/Momentos e provar leitura,
reload e remocao; seguir Cardapios lote55, Chat, Perfil/Para Voce e erros.
Autoria de happens-media/now-media/moments-media. Circular e G6; deploy,
SQL de producao, inventario e rastreadores sao C0. V-1 residual e revisao
profunda historica continuam pos-MVP. Nenhuma alteracao no checkout principal.

## Pacote 1 — preflight de Momentos

Etapa 2 → apps/superadmin → Coelo (Principal) → Momentos → Publicar/ler
midia → `momentos.create`, `momentos.publish`, `momentos.view`.

O handler de `moments-media` omitia `x-client-info` de
`Access-Control-Allow-Headers`. Acontece e Agora ja incluem esse cabecalho.
A falta explica um bloqueio de preflight de clientes Supabase; ainda nao
comprova ser a unica causa da falha historica do navegador.

Correcao: adicionar o cabecalho a allowlist existente, preservando origens
permitidas e toda autorizacao. Sem nova dependencia ou alteracao de contrato SQL.
Teste executa o handler real capturado de `Deno.serve`, sem servidor, rede ou
credenciais. Confere todos os cabecalhos solicitados e nega origem externa.

Prova local em Windows/Deno, 12/09 aproximadamente 10:57 -03:

- Antes: `deno test --allow-env --allow-read cors_test.ts`: 0 PASS / 1 FAIL,
  assercao `x-client-info` false versus true.
- Depois: `deno test --allow-env --allow-read`: 27 PASS / 0 FAIL,
  cobrindo CORS, contratos, assinaturas, R2 e validacao dos bytes.
- Aviso da dependencia: `punycode` deprecated; nenhum erro de tipo ou teste.
- Naquele pacote G4: deploy e preflight remoto ainda nao executados.
- C0 confirmou depois moments-media v10 ACTIVE e preflight 3014/producao200,
  externo403; prova propria em `r08-coordenacao/moments-media-preflight.md`.
- CRUD UI, leitura, reload e remocao do PNG continuam nao executados R08.

Deploy solicitado a C0: `moments-media`, fonte deste pacote. Depois medir
OPTIONS na origem `http://127.0.0.1:3014` incluindo `x-client-info` e seguir
prepare → PUT → finalize → publicar → leitura → reload → remocao.
Nenhum delta FE/BE/E2E proposto por este teste local isolado.

Fonte tecnica consultada: [CORS Supabase](https://supabase.com/docs/guides/functions/cors).

## Proximos gates

1. Prova real dos publicadores quando G0/C0 liberarem runtime/Chrome.
2. Cliente `chat.attach`: inspecionar contrato existente com G5 e implementar
   prepare/PUT/finalize/read no consumidor Flutter.
3. Cardapios list/create/edit/publish na fila de navegador, contrato lote55.
4. Perfil/Para Voce e erros conforme primeiro gate; sem inventar fluxo 409/500.
5. G5/C0 verificam disparador efetivo de expiracao Agora (H09).

Memoria: regras de produto preservadas; nenhum conhecimento novo de produto
aprovado neste pacote. Projecao final pertence a C0; no-op por enquanto.


## Pacote 2 — consumidor de anexos do Chat local-green

apps/superadmin → Conversas → conversa → anexar/abrir arquivo → `chat.attach`.
Sem mudar o comando de texto v2, o repositorio implementa o contrato opcional
ChatAttachmentRepository: prepare autorizado, PUT com cliente HTTP isolado,
finalize e leitura reautorizada por attachment_id. Uma repeticao apos resposta
perdida usa a mesma request_id; se o ticket estiver consumido, somente leitura
autorizada do binding confirma que ficou pronto. PUT falho nunca finaliza.

O dialogo mantem o arquivo no retry e envia uma mensagem separada; texto do
composer fica preservado. Imagens usam o viewer existente com TTL/purge e
PDFs usam abertura explicita apos autorizacao. Troca de conversa/repositorio
invalida resultados e fecha dialogos da origem. Sem URL publica ou segredo.

Divergencia a decidir pelo C0 antes de certificar: spec028 descreve assetId
canonico; o contrato SQL aplicado e chat-media usam attachment_id real e nao
retornam assetId. G5 confirmou e C0 autorizou preparar leitura explicita do
binding, preservando assetId nulo. Nenhuma tabela, gateway ou ID foi inventado.

C0 confirmou chat-media v4 ACTIVE, Deno6/6 e preflight 3014/producao200 e
externo403. Fonte C0: `r08-coordenacao/chat-media-preflight.md`.

Verificacao local em preparo: pub get sem upgrade; analyze inicial focal sem
issues. Apos acrescentar teste de fluxo da pagina, analyze apontou1warning
no tipo de retorno do fakeFilePicker; corrigido, rerun ainda nao executado.
Testes novos escritos antes da implementacao, mas RED nao executado devido ao
slot global; nao registrar TDD completo. Flutter test ainda nao executado.
Arquivos WIP locais nao representam entrega integrada nem aceite FE/BE/E2E.

H09: G5 publicou candidato76aed97cb com cron5min/sweep500. Ainda sem pgTAP
nem aplicacao; C0 precisa medir cron.job e aplicar no lote autorizado. O
candidato muda estado expirado, preserva master R2; filtro de leitura sozinho
nao prova agendamento. Nenhuma promocao de status proposta por G4.


## Conciliacao focal de Perfil (H02/H03)

Inspecao estatica R08 na base6d6cbef32+1d09cb3c8, sem novo aceite visual/E2E:

- `principal_profile_route_page.dart:206` e`:219` constroem feeds de Acontece
  e Momentos com institution/unit/group do runtime autorizado; dependem dos
  repositorios injetados. Em`:272` o host produtivo injeta os feeds e Sobre.
- `principal_profile_preview_page.dart:13` enumera quatro abas;`:947`,`:954`,
  `:961`,`:968` apresentam Acontece/Momentos/Circulares/Sobre com keys propias.
  O nome Preview nao significa que este componente esteja ausente da producao.
- `PrincipalProfileContentTabs` antigo sem consumidor pertence ao recorte G6;
  nao foi removido nem substituido. Destino recomendado: preservar ate G6/C0
  reconciliar referencias, sem duplicar a composicao que ja existe.
- `packages/coelo_domain/lib/src/profile_about/profile_about.dart:446` possui
  ProfileAboutOfficialUpdateRequest e as decisoes aboutOnly/aboutAndOfficial,
  mas nenhum consumidor produtivo foi localizado. O save de Sobre nao prova
  atualizacao de cadastro oficial. C0 recebeu a lacuna para decisao vigente.
- H05/H06/H13 continuam conciliacao contratual com Owner/C0; sem alterar
  denominador de recibos, permissao de revogar ou destino de CTA por inferencia.

A ausencia de um consumidor legado foi conciliada com o host atual; nao se
conclui que as quatro abas estao certificadas sem prova da rota normal.

Checkpoint documental11:27: codigo do pacote2 permanece WIP local; somente
JSON e este handoff estao no commit de checkpoint. Nao integrar como feature.


### Verificacao do pacote 2 (apos checkpoint documental)

Em12/09, slotG4 concedido pelo C0 as11:28 e devolvido imediatamente apos terminar:

- `flutter test --no-pub --concurrency=1` nos quatro arquivos listados no
  log `chat-client-flutter-test.log`: **56 PASS / 0 FAIL / 0 SKIP**, exit0.
  Sao11casos novos e45regressoes existentes, sem somar reruns.
- Inclui prepare/PUT/finalize, falhaPUT, replaypronto/naopronto, limiteimagem,
  leitura binding, purge pendente, dialogoretry, contexto substituido,
 375px/texto200% e fluxo pagina que envia uma vez/rele/preserva rascunho.
- Analise final: `dart analyze lib/features/chat` e os mesmos quatro testes:
  **No issues found**, exit0. O warning do callback FilePicker foi resolvido.
- `git diff --check`: exit0. Nenhuma dependencia/lock alterada.
- Testes sao locais com gateways/repositorios simulados; nao houve envio de
  dados reais por estes testes. PDF tem abertura explicita implementada,
  mas nao foi exercitado no navegador. Sem aceite visual ou E2E novo.

O codigo antes WIP agora acompanha este pacote publicavel. Proposta de delta
somente FE `chat.attach`: blocked-environment → local-green; backend e E2E
mantidos. Aplicacao pelo escritor central C0, apos sua revisao. Primeiro gate
atual: integrar e provar arquivo real na rota normal, reautorizacao/reload e
negativa de escopo, com a divergencia spec028 conciliada pelo C0.


## Pacote 3 — controle do PUT assinado solicitado pelo C0

apps/superadmin → Conversas/anexar; Coelo(Principal) → publicar Acontece,
Agora e Momentos → transferencia de arquivo. Revisao C0 localizou redirect
implicito no cliente. O assinador R2 atual retorna content-type em required_headers.

Os quatro adaptadores agora usam Request PUT com followRedirects=false,
headers assinados sem sobrescrever MIME e Response.fromStream. MIME diferente
da assinatura recusa a transferencia antes do PUT; redirect307 nao chega a
finalize/publicar. A correlacao de IDs nos envelopes e o retry foram preservados.
O mapeamento lowercase de chat-media foi confirmado com recusas422 readonly e
permission_denied. Nenhum gateway, bucket, policy ou dependencia criado.

SlotC0 11:50, devolvido imediatamente apos terminar:

- Quatro arquivos repository: **28 PASS / 0 FAIL / 0 SKIP**, exit0.
- Sao11casos novos e17existentes;6dos existentesChat ja pertencem aos56 do
  pacote2. Nao somar56+28 como testes distintos.
- Log commitado: `signed-put-flutter-test.log`.
- Analyze final dos quatro adaptadores e quatro testes: **No issues found**,
  exit0. Sem reexecucao visual ou novoE2E.

Proximo gate independente em WIP separado: PrincipalChatPage nao renderizava
attachments recebidos. Preparado compartilhamento do ciclo de leitura/purge
com molduras visuais separadas; nenhumwidgetadministrativo noPrincipal.
Esse WIP nao acompanha o commit do controlePUT e ainda nao foi testado.

C0 informou schedulerH09 succeeded14:35/14:40UTC em producao. Resultado e
publicacao final desse aceite pertencem aC0/G5; G4 nao executou cron nem UI.

## Pacote 4 — anexos recebidos no Chat do Principal

apps/superadmin → Coelo (Principal) → Conversas → mensagem recebida →
chat.attach (subaceite de leitura). A mensagem com arquivo e texto vazio nao
renderizava o anexo. PrincipalChatPage agora mostra metadados e abertura
explicita de imagem/PDF pelo binding autorizado attachment_id.

ChatImagePreview compartilha somente leitura, TTL e purge; Principal fornece
sua moldura propria e o Superadmin preserva CoeloAdminDialogShell. Nao ha
import administrativo no Principal nem novo gateway/repository paralelo.
Troca de contexto fecha somente a rota propria e descarta resposta atrasada.
PDF solicita leitura nova antes da abertura externa; navegador ainda nao provado.

Verificacao local em slots nominais C0, sempre concurrency1, sem golden update:

- Lote de cinco arquivos: 101 casos executados. Primeira tentativa encontrou
  purge disparando setState durante build. Ajuste intermediario passou o novo
  caso de troca de contexto, mas produziu 98 PASS / 3 FAIL / 0 SKIP por adiar
  repaint mesmo fora de build (`principal-viewer-red.log`, exit1).
- Correcao final apaga estado privado sincronamente e adia repaint somente
  em SchedulerPhase.persistentCallbacks; fora dessa fase preserva repaint.
- Rerun focal de Principal attachment e viewer: **58 PASS / 0 FAIL / 0 SKIP**,
  exit0 (`principal-viewer-green.log`). Tres falhas resolvidas, nenhuma nova.
- Os tres arquivos restantes tinham 43 PASS na execucao anterior. Cobertura
  do plano: cinco arquivos/101 IDs, dos quais quatro novos; nao somar reruns
  nem declarar os 101 como uma execucao unica sobre o ultimo SHA.
- Analyze final do Principal, visualizador compartilhado, wrapper e testes:
  **No issues found**, exit0.

Nao ha promocao E2E nem nova acao no denominador. C0 deve incorporar as provas
como complemento de chat.attach FE local-green e verificar a base integrada.
H09 agora tem fonte commitada: r08-coordenacao/lote56-cron-execucoes.md em
origin/dev2d97892d9 comprova duas execucoes do scheduler; sem aceite visual.

## Provas API publicadas — sem promocao UI/E2E

- Acontece: `happens-api-proof.md`,23operacoes/checksPASS, PNG privado,
  read/hash/reload,TTLexpirado403,retirada200 e ausencia na reconsulta.
- Agora: `now-api-proof.md`,19operacoes/checksPASS, PNG privado eTTLURL;
  publicacao preservada com prazo13/09T15:24:39Z. Expiracao24h nao verificada.
- Momentos: `moments-api-proof.md`,20operacoes/checksPASS e1FAIL na retirada
 403peloautor;preservadoeencaminhadoC0paraACL. Nenhumretry aposfalha.
- Cardapios: `meal-plan-api-proof.md`,24operacoes/checksPASS sobrelote55,
  modeloexistentev2preservado, plano novo draft1/edit2/review3/publish4/archive5.

Essas contagens incluem consultas repetidas de proposito e nao sao testes ou
IDs de acao distintos. Todos os manifests preservam somente dados sinteticos
necessarios; nao incluem segredo ou URLassinada. Nao se inventou ator
cross-tenant negado: as contasQA existentes sao Owner/platform.

Memoria: nenhum contrato de produto foi mudado por essas provas. As fontes
canonicas de autorizacao seguem vigentes; C0 concilia a hipotese403 e a spec028.
Nao foi criada projecao de conhecimento para registrar mera atividade.


## Continuacao API — Momentos e Chat (12/09, 13h BRT)

Momentos: lote58/C0 resolveu o403 de retirada. Mesmo registro retirado200,
reconsulta ausente; read do outro consumidor qa-r06-realm403, logout204.
O read200 do autor e canonico; a tentativa historica com esse oraculo errado
permanece8PASS/1FAIL, nao uma nova falha de produto. Ver moments-api-proof.md.

Chat: grupo nominal e PNG privado criados uma unica vez. Primeiro roteiro
27PASS/1FAIL por esperar403 em vez do400/InvalidArgument do R2 sem assinatura.
Continuacao nos mesmos IDs26PASS/0FAIL, exit0/logout204: membros, hash, reload,
replay sem novoPUT, negativas e expiracao real da URL300s. Ver chat-api-proof.md.

Acontece/Agora/Cardapios mantem resultados publicados. Nenhuma nova promocao
UI/E2E ou cross-tenant. Agora24h permanece futuro; agendador H09 tem prova C0.
Sem processo, slot Flutter ou Chrome G4 ativo. Proximo gate solicitado ao C0
para continuar sem conflitar com as outras frentes ate14:52:16 BRT.


## Gate Perfil — confirmação depois de reload (abertura 13h08 BRT)

Autorização C0: corrigir somente PrincipalProfileEditPage._save após RED focal.
apps/superadmin → Coelo → Perfil → Editar → principal.profile-edit.
Incluído: confirmação apenas após reload aceito no contexto que iniciou o save;
falha/403 e troca de contexto não disparam sucesso. Fora: dados oficiais/H02,
SQL, fixtures, router e mudanças visuais. Testes preparados: três regressões
locais, mais suíte existente do editor; sem rerun API ou golden. Parada: RED
reproduzido, correção mínima verde/analyze e publicação para integração C0.
Estimativa do delta inspecionado: cerca de20min após slot disponível, calibrada
pela pequena alteração de retorno de _load e pelos testes já existentes.
Slot ainda não concedido: nenhum Flutter iniciado. Quadro H02/H05/H06/H13
preserva ambiguidades reais, elimina apenas repetição de decisões adjacentes.


## Gate Perfil concluído localmente — código9863512b9

C0/G7 confirmaram baseline única plano/key/type; cinco REDs reproduzidos.
Correção mínima de parser e confirmação após reload. Dois arquivos completos:
37PASS/0FAIL/0SKIP/native0, analyze4arquivos0/native0. Cinco novos+32existentes;
dois oráculos antigos de envelope page foram substituídos. Logs e prova em
profile-contract-proof.md; sem nova fixture, SQL, golden ou aceite UI/E2E.
Slot devolvido13h24, nenhum processo G4 ativo. H02/H05/H06/H13 preservados.
Retenção e disparador H09 detalhados em agora-expiry-handoff.md e
retained-r08-resources.json. Nova publicação Agora só vence13/09 12h24 BRT.
Próximo gate focal solicitado a C0, mantendo execução até corte14h52:16.
