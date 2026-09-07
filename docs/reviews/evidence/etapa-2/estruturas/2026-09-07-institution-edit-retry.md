---
title: "Instituições — identidade do tipo e retry após reload"
source: "spec 042; diagnóstico independente e testes locais de 2026-09-07"
status: "local-green; produção não exercitada"
generated_at: "2026-09-07"
---

# Correções de edição cadastral

IDs afetados: `institutions.edit`, `institutions.reload`.
Somente controller/repository de Instituições e respectivos testes.

- P1 reproduzido: editar nome de instituição preservando tipo convertia UUID
  autoritativo em `local-type-escola`; o contrato 042 exige UUID existente.
  Agora o tipo inalterado mantém o ID carregado. Mudança textual de tipo não
  reutiliza indevidamente esse UUID; catálogo/troca real continua fora do pacote.
- P2 reproduzido: edição aceita seguida de falha de conexão no reload limpava
  o request pendente. Retry gerava novo request_id para versão já consumida.
  Agora a indisponibilidade tipada preserva a chave para replay idempotente.
  Negação terminal continua limpando a chave; nenhum dado anterior é retornado
  como fallback pelo repository.

## Verificação

RED dos dois testes reproduziu os valores errados (ID local e request IDs
distintos). GREEN final: 36 testes dos arquivos abaixo; analyzer sem problemas.
Revisão independente confirmou os mecanismos e executou 35 testes antes da
adição do negativo terminal; o agente principal executou a suíte final de 36.

```text
rtk flutter test --no-pub test/features/institutions/presentation/view_models/institution_form_controller_test.dart test/features/institutions/data/supabase_institution_directory_repository_test.dart
```

## Limites

Não houve chamada de produção, mutation remota, migration ou mudança de
capability, MFA, tenant, versão ou schema. Wiring produtivo do repository
interno já existe; esta evidência usa HTTP mock, não prova o fluxo em produção.
Não fecha edição/tela/E2E nem resolve troca de tipo via catálogo remoto.

Delta aos trackers centrais: registrar estas duas correções e testes nos IDs
indicados mantendo abertos os gates visuais, produtivos, negativos remotos e
reload real. Nenhum tracker central alterado nesta branch.

Gate de memória: regras de identidade e idempotência já estão na fonte canônica;
sem nova decisão ou projeção de conhecimento duplicada.
