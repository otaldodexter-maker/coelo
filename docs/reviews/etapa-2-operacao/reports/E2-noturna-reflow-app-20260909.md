---
title: "Transbordamento de layout no app inteiro — texto padrão e 200%"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "medição; nada corrigido fora do recorte operacoes-sistema"
generated_at: "2026-09-09"
group: "operacoes-sistema"
---

# Transbordamento de layout no app inteiro

33 telas de desenvolvimento abertas pelo router real, em 375×900 e 1440×900, com
texto padrão e com texto a 200%. Instrumento com pumps limitados, de modo que
telas em carregamento também são avaliadas. 132 casos no total.

## Resultado

| Escala | Passam | Falham |
| --- | ---: | ---: |
| 100% (padrão) | 61 de 66 | 5 |
| 200% | 59 de 66 | 7 |

### Falhas com texto PADRÃO — são defeitos que o usuário já vê

| Tela | 375 | 1440 | Dono provável |
| --- | --- | --- | --- |
| `/dev/safety` | falha | falha | acessos-pessoas |
| `/dev/imports` | falha | falha | operacoes-sistema |
| `/dev/agenda` | falha | passa | operacoes-sistema |

### Falhas adicionais apenas a 200%

| Tela | 375 | 1440 | Dono provável |
| --- | --- | --- | --- |
| `/dev/meal-plans` | falha | passa | operacoes-sistema |
| `/dev/plans` | passa | falha | operacoes-sistema |

## O que a medição mostra

**O problema é concentrado, não sistêmico.** Vinte e oito das 33 telas passam nas
duas larguras e nas duas escalas. Isso contraria a hipótese de que haveria
fragilidade geral do Design System: são telas específicas, com geometria
específica.

**Três telas quebram no estado padrão.** Não dependem de o usuário ampliar texto.
`/dev/safety` e `/dev/imports` falham nas duas larguras; `/dev/agenda` falha em
largura de telefone.

**Nenhuma largura sozinha encontra o conjunto.** Planos só falha em 1440;
Cardápios e Agenda só em 375. Verificar reflow numa única largura não é verificar
reflow.

## Segurança infantil é o pior conjunto do app

`/dev/safety` acumula: transborda nas duas larguras **com texto padrão**, falha
nas três diretrizes nativas de acessibilidade, e foi a tela que expirava no
instrumento antigo por permanecer em carregamento. E, diferente de Importações,
**não está adiada** — é funcionalidade de MVP sobre dados de criança.

Não investiguei nenhuma das causas em `/dev/safety`: pertence a acessos-pessoas.
Entrego a triagem.

## Limites

Mede ausência de exceção de layout na abertura da tela, em duas larguras e duas
escalas, tema claro. Não cobre interação, navegação interna, estados de erro, nem
tema escuro — este último foi medido à parte no recorte `operacoes-sistema` e não
foi fator em nenhum caso. Não identifica a causa de nenhuma falha: para as quatro
telas do meu recorte a causa está nos relatórios próprios; para `/dev/safety`,
não foi investigada.
