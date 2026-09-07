---
title: "Formulários — validação local de ticket de exportação"
source: "Prompt 5 Etapa 2; ADR 0032; diff e testes locais"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Recorte

`forms.responses.export`, Superadmin, resolução de download. Rejeitar resposta
malformada do gateway sem modificar protocolo, hostname autorizado ou prazo de
retenção. Nenhuma alteração em router, API compartilhada, migration ou remoto.

## Evidências

- Exige URL e expiração como strings; URL HTTPS absoluta com host, sem
  credenciais ou fragmento; expiração estritamente futura.
- Mantém query de ticket e consulta ao gateway em cada resolução.
- RED anterior à correção: quatro falhas esperadas; GREEN focado: 10/10.
- Regressão executada em 2026-09-07 às 19:22 BRT:
  `rtk proxy flutter test --no-pub test/features/forms/data`: 29/29.
- Analyzer dos dois arquivos: sem problemas na verificação da implementação.
- Review independente read-only: aprovado no recorte, sem falha concreta.

## Limites e handoff

Front-end permanece parcial/local-green, não verified. Back-end e E2E não
promovidos: não houve autorização real, XLSX real, R2 ou teste remoto. Validação
de formato de URL não substitui autorização, expiração ou revogação server-side.
O bloqueio CSV/ZIP do adapter em c0729294 não prova bloqueio SQL legado.
Próximo gate: contrato nominal server-side, geração XLSX e reautorização no
gateway, sob coordenação e lease de produção. Nenhum prazo de conclusão E2E
pode ser derivado destes testes.

Gate de memória: no-op; aplica contrato aprovado, sem decisão de produto nova.
