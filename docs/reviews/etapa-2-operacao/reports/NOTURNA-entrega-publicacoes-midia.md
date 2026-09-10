---
title: "Entrega da rodada noturna — grupo publicacoes-midia"
source: "Contrato em docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md; coordenação Claude da rodada de 09-10/09/2026"
status: "delivery-report; nenhuma mutação remota executada; nenhuma autorização nominal usada"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Entrega — publicacoes-midia

Recorte: `apps/superadmin` nas famílias `acontece`, `agora`, `momentos` e
`circulars`, 23 action_ids, mais a plataforma comum de mídia sob reserva
atribuída pelo coordenador.

Worktree `C:/Users/adrie/Documents/Coelo.worktrees/e2-noturna-publicacoes-midia`,
branch `work/etapa2-noturna-publicacoes-midia`, base `d784462c1` com
`origin/dev` mesclado em `3ab29d7df`.

## Os quatro documentos desta entrega

Tudo o que este grupo produziu fora de código está nestes quatro arquivos, no
mesmo diretório:

| Arquivo | Para que serve |
| --- | --- |
| `NOTURNA-entrega-publicacoes-midia.md` | este: lotes, defeitos, estado por ação, o que não fechou |
| `NOTURNA-decisao-owner-circulares-acoes-ausentes.md` | **oito decisões para o Owner**, com o caminho de cada uma já mapeado |
| `NOTURNA-revisao-candidatos-sql-publicacoes-midia.md` | revisão dos seis candidatos SQL, com um defeito e uma lacuna de prova |
| `NOTURNA-pacote-catalogo-midia.md` | desenho revisável da interface que falta no catálogo de mídia |

Há ainda um patch **preparado e não mesclado** na branch
`work/etapa2-noturna-copia-previa`, documentado em
`NOTURNA-patch-copia-previa.md` naquela branch.

## Lotes publicados

| # | SHA | O que é |
| ---: | --- | --- |
| 1 | `1e39b2fcf` | Integração seletiva de L01 `3697dd49e` nas três features Principal |
| 2 | `b10f48d1e` | Rota do leitor Principal de Circular a partir do feed misto |
| 3 | `57006c7a7` | Composição do feed de Momentos na rota normal |
| 4 | `1f53ec245` | União de `embedded` com o `mediaPicker` na publicação de Momentos |
| 5 | `04acb3e7b` | Anexos de Circular pelo R2 privado no gateway |
| 6 | `5ffdae8ba` | Recusa de resposta de Circular passa a dizer o que aconteceu |
| 7 | `40abfa875` | Agora relê o feed quando a autorização muda |
| 8 | `728aebecf` | Publicação repetida reapresenta a mesma chave de idempotência |
| 9 | `4e825eef5` | Compositor produtivo de Circular passa a anexar arquivos de verdade |
| 10 | `2de205da4` | Diretório de Circulares segue o cursor em vez de esconder o acervo |
| 11 | `cc445ad4c` | Cobertura do leitor roteado: larguras, 200%, Escape e semântica |
| 12 | `283e9f339` | Cobertura dos estados da rota de Momentos |
| 13 | `afec6cef6` | Revisão dos seis candidatos SQL do grupo |
| 14 | `6cb008665` | Máscara de existência na negação de `withdraw_happens_post` |
| 15 | `c72b2c217` | Ramo R2 em `happens-media` (inerte até a RPC anunciar o provedor) |
| 16 | `65d04ba9e` | Ramo R2 em `now-media` (inerte até a RPC anunciar o provedor) |
| 17 | `5dfcdd134` | Cliente do Acontece obedece ao provedor anunciado |
| 18 | `d6ff438fc` | Suíte pgTAP que faltava para o candidato do feed misto |
| 19 | `559017727` | `moments-media` confere os bytes armazenados, não só metadados |
| 20 | `9737f7777` | Guarda de contexto na retirada de Momento |
| 21 | `536b1f222` | Resumo de respostas no leitor administrativo |
| 22 | `4a40e13aa` | Retirada repetida de Momento reapresenta a mesma chave |
| 23 | `db2726df8` | Remoção do contrato órfão de retirada de Momento |
| 24 | `9fde22632` | Circular encerrada diz que fechou, em vez de pedir outra resposta |
| 25 | `6e2a21287` | Diretório pinta na primeira página em vez de esperar a última |
| 26 | `b0a11y` | Aviso de conflito de resposta passa a ser anunciado |

## Resultado medido do recorte

Medido em uma execução única, não somado de relatos anteriores: **638 PASS e
23 FAIL** nas oito features do recorte mais as seis rotas tocadas, já incluindo
todos os lotes.

Uma medição anterior deu 636 PASS e as mesmas 23 falhas, mas precedia dois
lotes; foi refeita em vez de ajustada de cabeça.

As 23 falhas são **todas** de golden e reproduzem na base sem nenhum lote deste
grupo: 10 em `principal_happens_preview_golden_test`, 11 em
`principal_moments_preview_golden_test` e 2 em `circular_directory_golden_test`.
Nenhum golden foi regravado, conforme decisão da coordenação.

Fora de golden, zero falhas.

## Defeitos corrigidos, em ordem de gravidade

1. **Vazamento de existência** em `withdraw_happens_post` (candidato). A função
   levantava `no_data_found:post_not_found` antes de chamar `happens_actor`, e
   um ator autenticado distinguia "não existe" de "existe e não é seu",
   inclusive atravessando tenant. Classe **e** mensagem unificadas.
2. **MIME real não conferido** em `moments-media`. A finalização comparava só
   tamanho e `Content-Type`, e esse `Content-Type` é o que o próprio cliente
   declarou no PUT assinado. Agora relê os bytes e confere a assinatura real.
3. **Cliente escolhendo destino de mídia** no Acontece, fixando o bucket em
   constante compilada, contra a ADR 0032. O destino passou a ser anunciado
   pelo servidor.
4. **Chave de idempotência gerada por chamada** em `publish_happens_post` e
   `publish_now`, o que fazia uma nova tentativa da mesma publicação chegar ao
   servidor como intenção diferente.
5. **Acervo escondido em silêncio** no diretório de Circulares: o hospedeiro
   lia uma página e descartava o cursor, então busca não encontrava Circular
   antiga.
6. **Afordância inerte**: o compositor produtivo anunciava que anexo seria
   habilitado depois e não fazia nada.
7. **Convite falso na recusa de resposta**: conflito de versão e Circular
   encerrada convidavam a repetir um envio que o servidor nunca aceitaria.
8. **Leitura sobrevivendo à autorização** no Agora, que não descartava um feed
   obtido sob contexto superado.
9. **Confirmação aplicada ao contexto errado** na retirada de Momento.
10. **Abrir Circular do feed** apenas informava indisponibilidade; agora entrega
    o leitor da família Principal dentro do shell.
11. **Resumo de respostas invisível**: a RPC, o método de repositório e o teste
    existiam, e nenhuma tela chamava; o leitor ainda recebia o repositório pelo
    tipo mais estreito, o que tornava a chamada impossível.
12. **Encerramento anunciado como conflito**: o servidor sinaliza Circular
    encerrada com o mesmo conflito de versão do conteúdo obsoleto, então o
    convite falso sobrevivia nesse subcaso.

### Acréscimo não anunciado, registrado depois

Os lotes `c72b2c217` e `65d04ba9e` também acrescentaram
`X-Content-Type-Options: nosniff` e `Referrer-Policy: no-referrer` às respostas
de `happens-media` e `now-media`, alinhando as quatro superfícies de mídia ao
`circular-media`. É melhoria real, mas entrou sob uma descrição que falava
apenas de costura injetável e ramo R2. Fica nomeado aqui.


## Estado por ação, ao final da rodada

Leitura verificada nesta rodada, não herdada do inventário. Três ressalvas de
leitura, para nenhuma linha ser lida como mais do que diz:

- **"RPC: sim"** significa definida na cadeia local de migrations. Não é prova
  de que esteja aplicada em produção, e não tenho como obtê-la.
- **Observações sobre gateways de mídia descrevem o código**, não o que está
  implantado. As Edge Functions só passam a valer depois de um deploy que este
  grupo não executou nem tem autorização para executar.
- **"Cliente avançado"** nunca significa ação concluída ponta a ponta.

| action_id | Cliente | RPC | Observação verificada |
| --- | --- | --- | --- |
| `acontece.feed` | avançado | sim | Abre o leitor Principal; teto de 20 sem paginação (decisão) |
| `acontece.create` | avançado | sim | Cliente deixou de fixar bucket; provedor anunciado |
| `acontece.publish` | avançado | sim | Chave de idempotência por intenção |
| `acontece.remove` | fechado | **não** | `withdraw_happens_post` só em candidato |
| `agora.view` | avançado | sim | Relê na revisão de autorização; estados honestos |
| `agora.create` | avançado | sim | `embedded` e seletor de mídia convivendo |
| `agora.publish` | avançado | sim | Chave de idempotência por intenção |
| `agora.expire` | satisfeito no cliente | sim | Servidor exclui expirado; transição material é candidato |
| `momentos.view` | fechado | **não** | `list_visible_moments` só em candidato |
| `momentos.create` | avançado | sim | Gateway passou a conferir MIME real dos bytes (código) |
| `momentos.publish` | avançado | sim | Sinal de refresh compartilhado com a leitura |
| `momentos.remove` | fechado | **não** | `withdraw_moment` só em candidato; guarda de contexto adicionada |
| `circulars.list` | avançado | sim | Segue o cursor, pinta na 1ª página; declara truncamento |
| `circulars.filter` | parcial | sim | Filtra no cliente sobre a lista completa; servidor não filtra |
| `circulars.create` | avançado | sim | Anexos passaram a funcionar |
| `circulars.edit` | avançado | sim | Nova revisão por `save_draft_v2`; recusa fechada/arquivada |
| `circulars.detail` | avançado | sim | Resumo de respostas passou a aparecer |
| `circulars.schedule` | **desabilitado** | sim | Nenhum host fornece o seletor; decisão de UX pendente |
| `circulars.publish` | avançado | sim | Versão otimista no contrato |
| `circulars.close` | **inerte** | sim | Backend completo, nenhuma afordância; decisão pendente |
| `circulars.delete` | **ausente** | **não** | Ausente nas três camadas; decisão pendente |
| `circulars.respond` | avançado | sim | Recusas dizem o que aconteceu; encerramento distinguido |
| `circulars.attach` | avançado | sim | Bilhete autorizado e expirável; gateway pronto para R2 |

Nenhuma ação é declarada concluída ponta a ponta. Três têm cliente fechado e
RPC ausente da cadeia aplicada, e por isso **não completam em produção**.

## O que NÃO está fechado, e por quê

- `withdraw_happens_post`, `list_visible_moments` e `withdraw_moment` **não
  existem na cadeia aplicada**. Só em candidatos. Portanto `momentos.view`,
  `momentos.remove` e `acontece.remove` têm cliente fechado e ação que **não
  completa em produção**.
- Mídia de Acontece e Agora **não está no R2**. Falta migration que exponha
  `storage_provider` no envelope de preparo e troque a checagem de existência
  do finalize, que hoje consulta `storage.objects`.
- `circulars.delete` está ausente nas três camadas: gateway v2 sem RPC,
  repositório sem método, tela sem afordância.
- Nenhuma suíte pgTAP foi executada. O harness sancionado **não replica a
  cadeia canônica**: falha na 53ª migration, `20260812002010`, com
  `relation "app_private.unit_import_source_attestations" does not exist`.
  Nenhuma migration rastreada cria essa tabela.

  Contexto medido por outra frente na mesma noite, que reposiciona isto: o SQL
  versionado chama **605** objetos de `app_private` e cria **590**, sobrando 40
  chamados e nunca criados em oito domínios; e o conjunto que `supabase start`
  aplicaria tem 17 arquivos e **zero** `create table`. Ou seja, não é lacuna
  deste recorte nem falta de esforço: **não existe base reproduzível para
  ninguém**.

## Ordem de aplicação que evita incidente

O candidato de Circulares muda o **default** de `storage_provider` para `r2`.
Aplicá-lo antes do deploy quebra anexo de Circular para todos. A ordem é:

1. configurar `COELO_R2_*` e criar `coelo-media-prod` e `coelo-documents-prod`;
2. implantar `circular-media` com o ramo R2;
3. só então aplicar a migration.

## Varreduras com resultado negativo

Registradas para ninguém repetir:

- **RPCs do recorte**: quatorze conferidas uma a uma contra a cadeia; apenas as
  três acima ausentes. Não há outro caso da classe "verde sobre protótipo".
- **MIME real nas demais superfícies de mídia**: `form-media` confere (usa
  `sniffImageMime`), Circular, Acontece e Agora já conferiam.
- **`_Metric` transbordando com texto ampliado**: não reproduz em
  `principal_profile_happens_tab`; nove combinações de largura e escala, todas
  sem exceção de layout.
- **Índice do pager de Momentos após recarga menor**: sem defeito, o código
  zera o índice e faz `jumpToPage(0)`.
- **Guardas de contexto em fluxos assíncronos**: o upload de anexo e o envio de
  resposta já se protegem; só a retirada de Momento não se protegia.

## Erros meus, corrigidos

- Medi largura com `setSurfaceSize` e li 800 px, que é o padrão da superfície de
  teste, e reportei um defeito de prévia contextual que **não existe**.
  Refeito com `tester.view.physicalSize`; corrigido no registro.
- Reescrevi sem necessidade o texto de uma falha transitória e quebrei
  referência aprovada. Revertido.
- Passei `dart format` no router e reformatei 191 linhas de arquivo
  compartilhado. Descartado e refeito com 8.
- Declarei "cliente fechado" para Momentos sem dizer que a RPC não existe na
  base. Corrigido antes de virar promoção indevida.
- Afirmei que um diretório temporário estava vazio antes de conferir; ao
  remover, continha um arquivo, que era cópia de migration rastreada.

## Recursos

Nenhum container, volume ou porta **deste grupo** permanece. O replay isolado
subiu um Postgres em projeto temporário próprio e foi encerrado; o diretório
temporário residual foi conferido e removido.

Registro para não haver leitura errada: durante a madrugada existiu na máquina
um container `coelo-sqlcheck` que **não é deste grupo** e não foi tocado.

## Custos que esta rodada introduziu, declarados

Duas correções trocaram um problema por um custo. Nenhum é defeito, mas quem
mantiver isto depois precisa saber:

- **`moments-media` finaliza lendo os bytes de volta.** Antes conferia só o
  `HEAD`. A leitura é limitada ao tamanho já esperado, com teto de 25 MB por
  ativo, e é o preço de conferir o MIME real — o mesmo preço que Circular,
  Acontece e Agora já pagavam. Sem ela, qualquer conteúdo do tamanho declarado
  passava como imagem.
- **O diretório de Circulares faz até 10 leituras por abertura.** Antes fazia 1
  e escondia o resto. Desde `6e2a21287` a lista pinta na primeira e cresce nas
  seguintes, então o custo não aparece como tela parada — mas o número de idas
  ao servidor por abertura subiu.

Registro também a correção de um defeito **meu**: o lote 10 deixava a tela em
carregamento até a última página, o que numa instituição grande eram até dez
idas antes do primeiro item. Encontrado relendo a própria entrega, não por
teste — nenhum teste falhava.

## Dimensões varridas nesta rodada

Nove, cada uma com resultado registrado — as com defeito viraram lote, as sem
defeito ficam aqui para ninguém repetir:

1. Existência das RPCs que o recorte chama — 14 conferidas, 3 ausentes.
2. Métodos de interface sem consumidor — 25 conferidos, 2 sem.
3. Classes de apresentação sem consumidor — 2 encontradas.
4. Callbacks opcionais nunca fornecidos — 5 encontrados, 3 honestos.
5. Conferência de MIME real nas superfícies de mídia — 1 faltava.
6. Guardas de contexto em fluxo assíncrono — 1 faltava.
7. Idempotência por intenção — 3 famílias fora do padrão da casa.
8. Uso do cursor de paginação — 2 superfícies descartavam.
9. Vazamento de texto do servidor para a interface — nenhum.
