---
title: "Avisos — edição agendada e reconciliação de publicação"
source: "contrato v2 draft-only de publish; N01; NoticeFormController; fixture stateful"
status: "local-green; sql-generation-pending; not-e2e-complete"
generated_at: "2026-09-07"
---

# Correção

Depois de salvar uma edição scheduled, o controller emitia publish novamente.
A RPC publish aceita somente draft; a edição podia persistir e terminar com
erro de transição. O mesmo ocorria depois de reconciliar um publish ambíguo
seguido de edição local.

O controller mantém o replay antes de decidir novos comandos. Um save que
retorna scheduled é o resultado da edição, sem novo publish. Estados active,
paused e terminais não geram save/publish implícitos pelo botão Publicar.
Salvar rascunho permanece uma ação separada; não foi implementada retomada
automática. Uma publicação reconciliada active mantém a edição local visível,
mas informa que não pode ser publicada nesse estado.

## Evidências

- RED: quatro novos testes falharam por publicação adicional, save inválido
  ou retorno nulo após edição agendada.
- GREEN: 22/22 controller; 103/103 de Avisos excluindo *_golden_test.dart.
- Fixture stateful preserva status entre comandos, verifica versão e nega
  publish não-draft; o teste antigo que simulava editar/publicar active foi
  corrigido para exigir reconciliação sem mutação inválida.
- Retry usa o mesmo request ID até recuperar a publicação aceita. No caso
  scheduled+edição, duas chamadas publish são o comando original e seu replay;
  não há terceira publicação. A edição usa a nova versão reconciliada.
- Analyzer dos dois arquivos sem problemas; formatter e diff check passaram.
- Dois reviews independentes aprovaram o recorte, sem achados acionáveis.

## Dependência explícita

Esta correção do cliente não implementa o job. N01 SQL ainda deve garantir que
save scheduled reautorize publicação, congele a nova geração e a materialize.
Nenhum SQL/Docker/produção foi executado nesta fatia. Goldens, replay real,
persistência, reautorização worker e auditoria continuam gates abertos.

Gate de memória: no-op; preserva o contrato de estados já aprovado.
