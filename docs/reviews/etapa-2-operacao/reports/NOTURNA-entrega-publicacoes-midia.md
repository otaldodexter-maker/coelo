---
title: "Entrega da rodada noturna — grupo publicacoes-midia"
source: "Contrato em docs/reviews/etapa-2-operacao/TRABALHO-ATUAL.md; coordenação Claude da rodada de 09-10/09/2026"
status: "delivery-report; nenhuma mutação remota executada; nenhuma autorização nominal usada"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Entrega — publicacoes-midia

Recorte: `apps/superadmin` nas famílias `acontece`, `agora`, `momentos` e
`circulars`, 23 action_ids, mais a plataforma comum de mídia sob reserva
atribuída pelo coordenador.

Worktree `C:/Users/adrie/Documents/Coelo.worktrees/e2-noturna-publicacoes-midia`,
branch `work/etapa2-noturna-publicacoes-midia`, base `d784462c1` com
`origin/dev` mesclado em `3ab29d7df`.

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

## Resultado medido do recorte

Medido em uma execução única ao final da rodada, não somado de relatos
anteriores: **636 PASS e 23 FAIL** nas oito features do recorte mais as seis
rotas tocadas.

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

Nenhum container, volume ou porta permanece. O replay isolado subiu um Postgres
em projeto temporário próprio e foi encerrado com a árvore limpa.
