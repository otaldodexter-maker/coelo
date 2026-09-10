---
title: "Entrega do grupo operacoes-sistema — rodada noturna 09/10 de setembro"
source: "trabalho proprio sobre a base d784462c1, branch work/etapa2-noturna-operacoes-sistema"
status: "documento vivo; atualizado ate a pre-entrega das 04:50"
generated_at: "2026-09-09"
last_update: "2026-09-09 21:48 (America/Sao_Paulo)"
group: "operacoes-sistema"
---

# Entrega — operacoes-sistema

Recorte: `auth`, `shell`, `agenda`, `imports`, `audit`, `support`, `account`,
`catalog`, `plans`, `meal_plans`, `error_pages`. 61 IDs, mapeados no inventário
sem reauditoria. Nenhum arquivo reservado foi escrito: router, migrations
aplicadas, plataforma de mídia, inventário e os três rastreadores permanecem do
coordenador.

## Correções entregues

| Commit | O que fecha |
| --- | --- |
| `1ac657de6` | Cardápios: a intenção de escrita sobrevive ao recibo divergente; validação de recibo num ponto único; `submitForReview` coberto junto. |
| `5f42fbcbd` | Planos: o diretório fecha em erro quando a falha não é do repositório. |
| `01081d3fc` | Planos: `_rpc` passa a tipar falha de transporte — causa raiz do anterior. |
| `585351fec` | Planos: o formulário fecha em erro quando o payload é inválido. |
| `29fa6ff13` | Agenda: intenção idempotente nos três comandos e falha de transporte fechada. |
| `f07545d35` | Cardápios/mídia: transporte fechado nos três métodos, com validação preservada; primeiro arquivo de teste do repositório. |
| `ac3238f7c` | Planos: o rótulo da métrica encolhe a 150% e 200%. |
| `0626c7655` | Páginas de erro: os goldens 409 ausentes viram skip com motivo, em vez de vermelho permanente. |
| `ef4b423a8`, `153b2dbfa` | Cinco suítes de rota recuperadas, 19 falhas ao todo. |
| `9a074a05c` | 96 artefatos de diff de golden destrackeados; a worktree deixa de sujar. |
| `458277400` | Minha conta: 32 casos cobrindo largura × tema × escala. |
| `94465f9c3` | Agenda: reprodução do transbordamento a 375 preservada como skip, com o resultado negativo da correção tentada. |

## Medições publicadas

| Relatório | Resultado |
| --- | --- |
| Censo de goldens | 226 PASS, 6 SKIP, 151 FAIL em 49 suítes, 27 features. |
| Catálogo | 16 divergências reais, não 14; e a armadilha que apaga o aviso. |
| Idempotência de escrita | 13 sítios fora do recorte, por dono. |
| Composição de produção | Suporte sem camada de dados; `account.profile` só em `/dev`; `account.sessions` sem tela. |
| Overflow da tabela admin | Causa raiz nomeada; linhas inalcançáveis, não clipadas. |
| Texto a 200% | Quatro telas falham; nenhuma largura sozinha acharia as três novas. |
| Diretrizes a11y do Flutter | 21 de 27; `/dev/imports` falha nas três. |

## Acessibilidade — o que ficou medido

Classe única nas quatro telas que transbordam: **geometria fixa que não acompanha
a escala de texto**. `mainAxisExtent` fixo em Planos, célula quadrada em
Cardápios, célula de calendário em Agenda, tabela sem rolagem vertical em
Importações.

Agenda é a mais severa porque ocorre com **texto a 100%** num viewport de
telefone. A correção autorizada — estender a condição `largeText` existente para
largura estreita — foi aplicada, medida e **não resolve**: com uma única marca o
transbordamento permanece idêntico, porque nem o número do dia mais uma marca
cabe em 39,6 pixels. Revertida, e registrada a correção da minha própria
recomendação: ela não é a mais barata de aprovar.

### O estado vazio também transborda

As oito rotas de produção, com a composição padrão fail-closed, passam em 16 de
16 casos com texto a 100% — o caminho de indisponibilidade honesta está sólido.
A 200%, duas falham em 375: `/agenda` e `/meal-plans`. Cardápios transborda 37
pixels, o **mesmo número** medido com dados de desenvolvimento.

Isso afasta a explicação confortável de que esses defeitos vêm do volume de
dados semeado em desenvolvimento. Eles ocorrem no estado mais vazio possível da
aplicação, e o número idêntico mostra que a causa é a moldura, não o conteúdo.

Para Agenda, as três medições juntas descrevem a tela: com dados e texto a 100%
em 375, falha; sem dados a 100%, passa; sem dados a 200%, falha. A célula não tem
folga nenhuma. É também por isso que a extensão autorizada não tinha margem para
recuperar, e a pergunta certa ao Owner passa a ser se a célula precisa de mais
altura ou de outra composição — não quantas marcas cabem.

### Travessia por teclado

Oito das nove telas passam uma travessia de doze Tabs sem exceção e com o foco
avançando. A nona, `/dev/imports`, falha pela exceção de overflow já
diagnosticada, e **não** por defeito de foco. Registrado assim para não contar
duas vezes o mesmo defeito em eixos diferentes.

Tema não é fator em nenhum caso. Claro e escuro falham identicamente nas mesmas
rotas, o que separa o eixo de tema do eixo de largura e dispensa metade da
matriz para quem vier depois.

## Bloqueios, com a natureza de cada um

- **Decisão do Owner:** baseline 409; rebaseline de Suporte; altura do cartão de
  Planos a 200%; componente `CoeloAdminResizableTable`.
- **Ambiente/autorização remota:** pacote AUDIT-READ-V2 pronto e revisável,
  replay 0/145.
- **Ausência de implementação, não verificação pendente:** Suporte, 503 em
  produção; `account.sessions`, sem tela; `shell.switch-context`, sem seletor.
- **Decisão de produto:** `plans.activate` e `plans.assign`.

## O que NÃO foi feito, e por quê

Nenhuma execução remota. Nenhum golden regravado. Nenhum arquivo de produto de
outra frente alterado — as quatro suítes de rota fora do recorte são arquivos de
teste, com autorização nominal registrada. Nenhuma asserção afrouxada para
fechar suíte.

## Correções que fiz contra o meu próprio relato

Registradas porque mudam o que o leitor deve confiar:

1. Classifiquei Suporte como bloqueado por golden. O bloqueio real é ausência de
   camada de dados e 503 em produção. Os 61 testes verdes exercitam protótipo.
2. Afirmei que o aviso do Catálogo subnotificava. O risco é o inverso: regenerar
   o relatório **apaga** o aviso.
3. Descrevi a guarda de rota como bloqueio pela chamada sem argumento. O bloqueio
   vem do redirect com location; a causa é ausência do ramo.
4. Disse que `prototype_navigation` não mudou com a flag. O contador não mudou; o
   modo de falha mudou.
