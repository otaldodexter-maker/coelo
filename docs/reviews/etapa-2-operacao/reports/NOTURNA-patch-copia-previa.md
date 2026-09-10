---
title: "Patch preparado - telas produtivas que se declaram previa"
source: "Varredura de callbacks opcionais nunca fornecidos, grupo publicacoes-midia, rodada noturna de 09-10/09/2026"
status: "prepared-not-merged; aguarda decisao do Owner; NAO cobre principal_for_you"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Patch preparado, nao mesclado

Branch `work/etapa2-noturna-copia-previa`, sobre a `dev` integrada. **Nao
mesclar sem decisao do Owner.**

## O defeito

Seis mensagens em tres superficies do Principal afirmam um contexto que nao e o
da tela. Essas paginas **sao** as rotas produtivas hoje, com `embedded: true`.
Na tela real, tocar em responder no Agora informa que a resposta esta
indisponivel "nesta previa": o produto afirmando algo falso sobre si mesmo.

O repositorio ja se contradiz sobre isso. `principal_profile_route_page_test`
exige que "experiencia completa" **nao** apareca na rota real;
`principal_for_you_route_responsive_test` **espera** que apareca.

## O que este patch faz

Implementa **uma** das duas opcoes: tornar a mensagem verdadeira nos dois
contextos, sem afirmar previa. Nenhuma composicao aprovada muda; so o texto.

| Arquivo | Antes | Depois |
| --- | --- | --- |
| `principal_happens_preview_page` | `$label estara disponivel na experiencia completa.` | `$label ainda nao esta disponivel.` |
| `principal_happens_preview_page` | `$action indisponivel nesta previa.` | `$action ainda nao esta disponivel.` |
| `principal_happens_preview_page` | `Reproducao de video indisponivel nesta previa.` | `Reproducao de video ainda nao esta disponivel.` |
| `principal_now_preview_page` | `Resposta indisponivel nesta previa.` | `Resposta ainda nao esta disponivel.` |
| `principal_now_preview_page` | `Compartilhamento indisponivel nesta previa.` | `Compartilhamento ainda nao esta disponivel.` |
| `principal_moments_preview_page` | `$label estara disponivel na experiencia completa.` | `$label ainda nao esta disponivel.` |

Mais os tres testes que travavam as frases exatas, nas mesmas features.

## O que este patch NAO faz, deliberadamente

- **Nao cobre `principal_for_you`.** E de outra frente, e o seu teste espera a
  frase antiga. Alguem precisa faze-lo no mesmo movimento, ou a divergencia
  apenas muda de lugar.
- **Nao implementa a outra opcao.** A alternativa - a acao sumir quando nao ha
  capacidade, como a galeria do Acontece ja faz com compartilhar e salvar -
  altera composicao aprovada e e autoridade do `coelo-ui`. Se o Owner escolher
  essa, **este patch nao e reaproveitavel**.

## Verificacao

`flutter analyze --no-pub` nas tres features: sem problemas.
54 PASS e 0 FAIL nas suites que travavam os textos.

## Por que preparado e nao aplicado

Copia e linguagem do produto, com composicoes aprovadas, e a escolha entre as
duas opcoes nao e de executor. O patch existe para que a decisao do Owner custe
uma resposta, e nao uma resposta seguida de trabalho.
