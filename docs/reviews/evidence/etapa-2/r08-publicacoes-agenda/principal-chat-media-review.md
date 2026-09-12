---
source: local review of G4 commits 9bee7eb26 and bb0da7578 requested by C0
status: reviewed-no-concrete-defect
generated_at: 2026-09-12
---

# Revisao do consumidor de midia do Principal

Recorte somente leitura: `ChatImagePreview`,
`PrincipalChatAttachmentTile` e a composicao em `PrincipalChatPage`. O commit
`bb0da7578` contem apenas a prova API do Acontece; nao altera esse consumidor.

## Ciclo conferido

- `didUpdateWidget` do tile chama `_reset()` antes de criar uma nova
  `MediaSession`; `invalidate()` marca a sessao antiga como invalida
  sincronamente.
- `_generation` e `isCurrent()` impedem que URL privada tardia, retorno de PDF
  ou callback da rota antiga alcancem a nova attachment/repository.
- a remocao pos-frame captura a `DialogRoute` antiga, enquanto `_route` e
  zerada antes de uma eventual abertura nova.
- `ChatImagePreview.didUpdateWidget` desregistra o purge antigo, associa a
  sessao nova e so inicia I/O no pos-frame se geracao, contexto e sessao ainda
  forem atuais.
- purge, expiracao e `dispose` cancelam timer, removem a `NetworkImage`, fazem
  `evict` e removem o observer de lifecycle.
- imagens validam expiracao antes de materializar preview; PDFs validam ticket
  antes de abrir o download. Metadados de bytes sao exibidos sem transformar o
  binding em asset canonico.

## Fronteira visual

O Principal importa apenas Flutter, `coelo_api`, tokens, o abridor de download,
o contrato de Chat e `ChatImagePreview`, que e infraestrutura visual neutra.
Nao ha import de `coelo_ui_admin`, `SuperadminChat*` ou outra composicao
administrativa. O `frameBuilder` mantem o dialogo na familia visual Principal.

## Conclusao

Nenhum defeito concreto de regressao foi encontrado nesse recorte. Os testes
autorais ja cobrem ticket expirado/retry em 375 e 1440 com texto a 200%, alem
da troca de repository com descarte de URL privada tardia. Por instrucao do C0,
nenhum lote generico ou rerun foi executado e nenhum arquivo de produto foi
alterado.
