---
title: "Circulares — hosts e descarte do contexto de edição"
source: "production_circular_hosts; CircularComposerController; revisão review_chat_receipt"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

## Recorte e causa

Hosts produtivos de diretório/editor no Superadmin e descarte do controller
compartilhado consumido pelo Superadmin. O editor aguardava draft de A e
construía controller com repository corrente B, sem reiniciar no novo contexto.
O diretório também não reiniciava. Controller notificava listeners após dispose.

Hosts agora capturam dependências, limpam contexto, reiniciam por alterações e
verificam geração/mounted antes de aceitar resultado/erro. Controller descartado
rejeita novos comandos e resultados tardios com CircularInvalid/contextDisposed;
não continua publicação depois de save pendente. Nenhum cancelamento remoto ou
rollback é alegado: operação já enviada pode ter sido confirmada pelo servidor.
Enquanto ativo, snapshots, request IDs e recuperação idempotente são preservados.

## Evidência

- RED5 hosts: novo contexto não era solicitado e conteúdo anterior persistia.
- RED3 controller: save/publicação após dispose lançavam FlutterError.
- GREEN24 focal; GREEN91/91 Circulares + principal_circulars não-golden.
- Analyzer4, formatter, validador visual e diff check passaram.
- Review independente estático sem bloqueantes.
- Fixture dos hosts passou a usar CoeloTheme.light exigido pela tabela; a tabela
  fixa replica texto visualmente, portanto o teste confere também items.single
  no diretório. Esses ajustes não alteraram código visual produtivo.

## Limites

Não foi executado backend, R2 ou Stream, nem atualizado golden. A cobertura
do host compositor troca repository e ID juntos e cobre ID isolado; picker de
instituições e dispose durante prepare não têm caso direto nesta fatia.
Os callbacks da página composer (publish/schedule) após substituição do
controller continuam pendência separada. Esta fatia não encerra Circulares E2E.
Conhecimento: aplica invariantes existentes; nenhuma nova regra de produto.
