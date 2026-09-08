---
title: "AG-READ01 — cliente dedicado à projeção parcial 039"
source: "contrato fechado AG-READ01; migration 20260908045531; reserva do Coordenador; testes Flutter locais"
status: "cliente isolado local-green; composição, SQL GREEN e E2E abertos"
generated_at: "2026-09-08"
---

## Escopo e resultado

Base `8218f26b37a6aae461269a56d191ca65710b62d0`. Três arquivos novos:
`agenda_read_repository.dart`, `supabase_agenda_read_repository.dart` e
`supabase_agenda_read_repository_test.dart`, somente no domínio Agenda do Superadmin.

Interface dedicada aos três readers v2 (list/get/contexts), sem implementar o
repository legado de comandos. DTO conserva `context_id` explícito e audiência
parcial, sem propriedade `personIds`. Histórico ausente na lista é diferente de
histórico vazio no detalhe. Coleções expostas são imutáveis. Capabilities reais
continuam metadados; `mutationActionsAvailable` permanece falso.

Envelope e projeções são fechados. Valida paginação, identidade do detalhe,
coerência institucional, hierarquia de contextos, metadados de capability,
enums, datas e recorrência. Negativas HTTP200 039 são interpretadas antes da
projeção; somente código/correlação seguros são retidos. Erros de transporte e
PostgREST não expõem mensagem bruta. Não há fallback People, cache, retry,
HTTP real, DI, router ou ativação de comandos.

## Evidência e review

- RED inicial: 24 testes falharam contra reader ainda não implementado.
- Implementação: 24 PASS; ampliação contratual e review independente.
- Review `activities_contract_read` identificou lembrete vazio permitido pelo
  SQL e rejeitado pelo cliente. RED focado reproduziu esse caso: 48 PASS,
  1 FAIL. Correção preserva a string, sem alterar o contrato server-side.
- Final: **49 PASS**, exit0. Inclui histórico não vazio com revisão anterior
  nula, projeção parcial, negativas, respostas malformadas, paginação,
  capabilities, hierarquia, recorrência e transporte.
- Analyzer dos três arquivos: **sem issues**, exit0, após corrigir três
  avisos de blocos `if`.
- Gate de memória: validação PASS; **no-op** de projeção, pois não há nova
  decisão de produto. O contrato técnico candidato fica nesta evidência e no
  crosswalk, sem publicar instruções de funcionalidade indisponível ao usuário.

Comandos, em `apps/superadmin`:

```powershell
rtk proxy flutter test --no-pub test/features/agenda/supabase_agenda_read_repository_test.dart
rtk proxy flutter analyze --no-pub lib/features/agenda/domain/agenda_read_repository.dart lib/features/agenda/data/supabase_agenda_read_repository.dart test/features/agenda/supabase_agenda_read_repository_test.dart
```

## Primeiro gate aberto

GREEN nominal SQL pelo Eng1 e integração de uma superfície read-only que
renderize explicitamente a projeção parcial, sem traduzir omissão em audiência
individual vazia. A futura composição exige reserva própria e lifecycle de
sessão/contexto/respostas tardias. Este pacote não faz essas promessas.
Remoto, UI real → backend → reload, comandos, reservas e R2 continuam abertos.
