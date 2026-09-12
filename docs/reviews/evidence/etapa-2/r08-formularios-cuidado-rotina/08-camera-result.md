---
source: "08-camera-plan.md; gate nominal C0 R08 G3; contrato produtivo Photo1; ADR0032"
status: "local-green; câmera no navegador e E2E pendentes de runtime"
generated_at: "2026-09-12"
---

# Foto — resultado da captura local

Recorte: `apps/superadmin -> Formulários -> Responder -> Foto -> forms.upload`. Base `origin/dev 7cc6d4e7b`, merge `8b9e784e5`. O desenho focal foi materializado antes do código em `08-camera-plan.md`. Não inclui H20/Medicação.

## Implementação

O novo adapter web condicional inicia `getUserMedia` com vídeo, sem áudio, e preferência por câmera traseira quando disponível. O diálogo mostra a prévia e permite **Usar foto**, **Cancelar** ou retry depois de uma negativa. O frame confirmado é codificado localmente em JPEG, com maior lado limitado a2560px. O upload de resposta existente continua responsável pelo preflight e envio; o backend segue autoritativo para MIME/bytes/dimensões/checksum/escopo.

O campo Foto usa somente o callback de câmera, produz `FormAnswer.photo` e permite **uma imagem**, conforme o contrato atual. Nova captura só é habilitada depois da remoção explícita da referência. `allowCamera=false` apresenta indisponibilidade honesta. Galeria e imagem da pergunta mantêm o picker existente. Os callbacks de sessão e o segredo anônimo são os mesmos do pacote anterior.

Tracks são encerradas ao confirmar, iniciar o pop da rota, cancelar, trocar de contexto, invalidar sessão, deixar o app, falhar ou descartar o diálogo. Permissão/captura tardia não reabre a câmera e bytes tardios são zerados. Uma falha do contexto anterior não encerra o controlador novo.

Não há dependência, gateway, bucket, configuração, router ou app host novo. A implementação web usa as bibliotecas SDK já presentes no projeto, isoladas por export condicional; não é um seletor de arquivo HTML nem um crop de avatar. Em plataforma sem adapter, a UI informa a impossibilidade de acessar a câmera.

## Verificação

Slot nominal C0 `13:24–13:30 BRT`, liberado logo após processo `83919` terminar.

- `08-camera-tests.log`: **182 casos únicos PASS / 0 FAIL**, concurrency1; câmera8, upload19, resposta155.
- Onze casos novos: oito de câmera/lifecycle, dois do campo Foto e um da resposta preservando o tipo Photo. O restante se sobrepõe aos pacotes anteriores; não somar.
- 375×600 e texto200%: diálogo e confirmação sem overflow no teste focal.
- A primeira suíte completa passou; não houve RED nesta fatia. Não foi executado rerun sem motivo.
- `08-camera-analyze-initial.log`, `08-camera-analyze.log` e `08-camera-analyze-final.log`: análise explícita do adapter web e consumidores/testes. Resultado final sem apontamentos.
- Nenhum Flutter/Chrome retido. Não houve imagem real de câmera, dado pessoal ou recurso remoto criado.

Os testes usam um port sintético: provam o ciclo de vida do consumidor e o envio confirmado, mas não a disponibilidade de câmera física, permissão do navegador ou integração do elemento HTML na build real. O adapter web foi analisado estaticamente. A prova de navegador/build continua com G0/C0; não certificar `forms.upload` E2E a partir desta suíte.

## Integração e memória

Não exige parâmetro novo no router. `FormResponsePage` compõe o campo Foto quando existe sessão de mídia válida; para anônimo, permanece necessário o store estável e `FormsAnonymousImageApi` do pacote07. O default do campo abre o diálogo de câmera. Preservar a composição normal de mídia/store feita por C0/G6.

Delta para memória central: Foto ganhou consumidor de câmera no Superadmin web com limite efetivo1; Galeria permanece escolha de arquivo. Não amplia a cardinalidade da fonte antiga nem define autorização de dose/medicação. C0 publica esse conhecimento após integrar a superfície real.
