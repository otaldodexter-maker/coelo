---
title: "Assinaturas: o que o cliente envia e o que producao espera"
source: "Dump schema-only de producao (evvbomzejfijozbtgvpt) de 2026-09-10; varredura de client.rpc em apps/superadmin/lib na base bb15db748"
status: "measured"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
author: "Rodada 3, grupo acessos-pessoas"
---

# Nenhuma divergencia de assinatura entre cliente e producao

## Por que medir isso

A medicao anterior mostrou que 96 das 162 RPCs chamadas pelo Superadmin nao
existem em producao. Mas existir nao basta: o PostgREST chama funcao do Postgres
por **nome de parametro**. Se o cliente envia `p_foo` e a funcao espera `p_bar`,
a chamada e recusada mesmo com a funcao presente, e o sintoma em tela e igual ao
de funcao ausente.

Entao, para as 66 RPCs que **existem** em producao, era preciso conferir se os
parametros batem. Sem isso, aplicar as 36 migrations pendentes poderia destravar
o nome e continuar quebrado no argumento.

## Resultado

| Medida | Valor |
| --- | --- |
| RPCs do cliente com bloco `params` explicito | 90 |
| Divergencias encontradas | 5 |
| **Quebras (parametro que producao nao conhece)** | **0** |

**Nenhuma quebra.** Todo parametro que o cliente envia para uma funcao existente
e conhecido por aquela funcao em producao. Isso e uma boa noticia concreta: o
problema de contrato do Superadmin e **so** a ausencia das funcoes. Uma vez
aplicadas as migrations, as chamadas se encaixam.

## As 5 divergencias sao limitacao do metodo, nao achado

Nos cinco casos o cliente aparentemente "nao envia" parametros que a funcao
declara. Inspecionando, o motivo e sempre o mesmo: o mapa de parametros e
montado em runtime com espalhamento. Exemplo real, em
`features/agenda/data/supabase_agenda_repository.dart:280`:

```dart
params: {'p_request_id': _intentFor('save', arguments), ...arguments},
```

Analise estatica nao enxerga dentro de `arguments`. Os cinco casos sao
`get_profile_about`, `list_visible_profile_circulars`, `superadmin_agenda_command`,
`superadmin_agenda_decide_publication` e `superadmin_agenda_save`. Nenhum deles
indica defeito; indicam apenas que este metodo nao os alcanca. Ficam registrados
como nao medidos, nao como aprovados.

## Correcao de uma medicao intermediaria

A primeira versao deste script reportou **30 quebras**. Estava errado: ele
delimitava o bloco `params` por uma janela de caracteres de tamanho fixo a partir
da chamada, e a janela vazava para a chamada seguinte no mesmo arquivo,
atribuindo a uma funcao os parametros de outra. Refeito com casamento de
parenteses e de chaves, ignorando conteudo de string, o numero real e zero.

Registro o erro porque ele e instrutivo para as outras frentes: qualquer medicao
por regex sobre codigo precisa respeitar os delimitadores da linguagem, e um
resultado alarmante merece ser duvidado antes de virar relatorio.

## Limites desta medicao

- Cobre `public`. Funcoes `app_private` nao sao chamadas pelo cliente.
- Compara **nomes** de parametro, nao tipos. Um `text` onde se espera `uuid`
  passaria por aqui e falharia em runtime.
- Nao cobre as 96 RPCs ausentes: para elas nao ha assinatura em producao com que
  comparar. A conferencia de assinatura dessas so pode ser feita depois da
  aplicacao.
