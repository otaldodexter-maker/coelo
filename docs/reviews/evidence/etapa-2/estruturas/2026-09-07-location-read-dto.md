---
title: "LOC-DTO01 — modelo e decoder de leitura"
source: "docs/superpowers/plans/2026-09-07-location-read-dto.md; LOC-CATALOG01 ce318d05"
status: "prepared-local-tests-pass-not-e2e"
generated_at: "2026-09-07"
---

## Escopo e resultado local

Modelo Dart puro e transporte estrito do candidato Locais. Preservados
LocationScope, LocationKind, snapshots e consumidores. Sem criação, builder,
RPC wire, UI, SQL, bridge ou alteração no barrel geral. Estado PREPARED até
replay do contrato e confirmação dos bytes reais da resposta.

## Evidências executadas

- API ausente produziu falha de compilação inicial; scaffold sem implementação
  permitiu observar 73 falhas de execução esperadas. Implementação: 73 GREEN.
- Teste extra de surrogate UTF16 isolado falhou por aceitar o texto inválido;
  correção recusa esse valor preservando caracteres astrais válidos.
- Suíte completa coelo_api: 97 PASS, incluindo Formulários existentes e 83
  testes de Locais. Suíte completa coelo_domain: 32 PASS.
- Análise estática dos seis arquivos Dart nominais: zero issues após correção
  de sete avisos iniciais de estilo/inferência.
- Duas revisões readonly: nenhum P1/P2 no recorte. Sugestões de cobertura
  incorporadas: demais negativas, erro desconhecido, diretório de unidade e
  página acima de 100 itens.

Decoder valida 14 chaves exatas, owner XOR/ID esperado, enums explícitos,
codepoints de nome/descrição/andar, bytes UTF8 do endereço, ausência versus
null e datas com timezone sem normalização de calendário inválido. Coleções
são cópias imutáveis. Bigint além de 9007199254740991 é recusado porque JSON web
pode perder precisão; não muda a capacidade do banco de armazenar bigint.

## Limites

ID e proprietário são integridade de transporte, nunca autorização. Não há
canAccess, toSnapshot ou dados internos em exceções. Endereço é estrutural,
não geocodificado. Não comprovados persistência, RLS, acesso remoto, sessão
real, navegação Flutter ou os sete IDs de Locais.

Memória: somente evidência técnica candidata, sem promover regra nova ao
conhecimento aprovado de produto. Rastreador/ledger permanecem com coordenação.
