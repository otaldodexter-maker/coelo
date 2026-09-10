---
title: "Decisão do Owner — três ações de Circulares sem afordância"
source: "Varredura de 25 métodos de interface das famílias acontece, agora, momentos e circulars contra consumidores em presentation, application e app; rodada noturna de 09-10/09/2026"
status: "decision-request; nenhuma tela nova criada; nenhuma mutação remota executada"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Três ações de Circulares que existem no backend e não existem na tela

Este documento junta **uma** decisão em vez de três perguntas soltas. As três
ações compartilham a mesma causa: caminho completo do banco até o repositório,
sem nenhuma afordância que as acione.

Uma delas já foi corrigida nesta rodada; as outras duas dependem de decisão.

## O que existe hoje, ação por ação

| Ação | RPC no gateway v2 | Método no repositório | Afordância na tela |
| --- | --- | --- | --- |
| `circulars.attach` | sim | sim | **corrigido em `4e825eef5`** |
| `circulars.close` | `superadmin_circular_close_v2` | `closeResponses`, implementado em 4 lugares | **nenhuma** |
| `circulars.delete` | **nenhuma** | **nenhum** | **nenhuma** |

`circulars.attach` era o caso mais barato: o botão existia e apenas anunciava
que o envio "seria habilitado depois". Hoje seleciona arquivo, envia pelo
caminho de mídia e reporta falha honestamente.

`circulars.close` é o caso mais frustrante: tudo pronto, ninguém consegue
acionar. `public.delete_circular` existe mas é chamada só pelo repositório do
Principal; o gateway administrativo v2 tem sete funções e nenhuma de exclusão.

## Por que não foram implementadas de madrugada

O portão de mutação de produção do router é baseado em **localização**:
`_isProductionMutationLocation` olha o caminho da rota e libera ou bloqueia.
Um botão "Encerrar" no leitor `/circulars/:circularId/read` seria uma mutação
numa rota de leitura, portanto fora do portão.

Isso **não** seria inseguro: a RPC exige a capacidade
`circulars.circulars.manage` no servidor, e o cliente nunca é a fronteira de
autorização. Seria, porém, a única mutação do produto fora do portão — uma
inconsistência de arquitetura introduzida sem revisão.

Há uma pista do desenho pretendido: o portão **já reconhece** caminhos
terminados em `/manage`. Mas a pista cobre a **rota**, não a **tela**. Decidir
o que essa tela mostra é composição visual, autoridade do `coelo-ui` e decisão
do Owner.

## O que a opção completa exigiria

Se o Owner aprovar, o caminho é este e não precisa de descoberta adicional:

1. **Rota** `/circulars/:circularId/manage`, já reconhecida pelo portão de
   mutação, portanto sujeita à checagem de capacidade como as demais.
2. **Tela** com o mínimo para decidir: título, contexto, estado atual e o
   resumo de respostas — que passou a existir no leitor em `536b1f222` e pode
   ser reaproveitado sem nada novo.
3. **Ações** na tela:
   - *Encerrar respostas*, com confirmação, versão otimista e recarga. Usa
     `closeResponses`, que já existe nas quatro implementações.
   - *Excluir*, **se** o Owner decidir que exclusão lógica administrativa entra
     no MVP. Esta é a única que exige trabalho novo de backend: uma RPC de
     gateway v2 com capacidade própria, porque `public.delete_circular` hoje
     pertence ao caminho do Principal.
4. **Auditoria**: `close_circular_responses` já registra; a exclusão precisaria
   do equivalente antes de existir.

## As três perguntas, em uma

1. Encerrar respostas entra pela rota `/manage` dedicada, como o portão sugere?
2. Exclusão lógica administrativa entra no MVP, ou fica adiada como importação
   e exportação?
3. Se entrar, a tela `/manage` reúne as duas ações, ou a exclusão fica em outro
   lugar?

Respondidas as três, a implementação é direta e não depende de mais nada.

## O que NÃO está sendo pedido

Não se pede redesenho de Circulares. Título, texto, anexos, perguntas,
políticas de resposta, revisão, agendamento e público já estão definidos, e a
confirmação visual do shell foi resolvida pelo Owner em 09/09/2026.

## Padrão, não acidente

Vale registrar como padrão da família e não como três casos isolados: em
Circulares, três ações tinham backend completo e nenhuma tela. É a mesma doença
que aparece do outro lado quando a tela existe e não alcança o dado — como o
resumo de respostas, que tinha RPC, método de repositório e teste, e nenhum
consumidor, corrigido em `536b1f222`.
