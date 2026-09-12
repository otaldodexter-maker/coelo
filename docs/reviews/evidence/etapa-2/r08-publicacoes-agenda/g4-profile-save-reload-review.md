---
source: "C0 R08; commit 9863512b9; baseline production migration 20260910000000"
status: "reviewed-read-only; two-concrete-findings"
generated_at: "2026-09-12"
---

# Revisão focal de Perfil G4

Recorte somente leitura: save → reload, parser do contrato plano e troca de
contexto no commit `9863512b9`. Flutter, produção, SQL e arquivos G4/C0 não
foram tocados.

## Partes corretas

- A RPC canônica retorna página plana; campos usam `key` e seções usam `type`.
  A normalização nova para `field_key`/`section_type` é fiel à baseline.
- `null` é ausência legítima; retorno não objeto e versão ausente falham.
- O save só confirma depois de uma releitura aceita. Negação/falha na releitura
  não chama `onSaved`; retry de leitura não repete o save.
- A geração impede o resultado tardio de save/reload de atualizar outro
  contexto.

## Achados concretos

1. A baseline devolve `subject_type` e `subject_id`, mas
   `parseProfileAboutReadResponse` ignora ambos e constrói a página com o
   `subject` solicitado. Um retorno divergente seria silenciosamente relabelado
   e exibido no contexto atual. A exigência R02 já nomeava “save aceito +
   releitura de sujeito divergente sem sucesso”. O parser deve exigir strings
   iguais a `profileAboutSubjectTypeToken(subject.type)` e
   `subject.subjectId`, convertendo divergência em `FormatException` e depois
   indisponibilidade. A resposta canônica não contém actor; inventar validação
   client-side de actor não é autorizado nem necessário.
2. `didUpdateWidget` afirma cobrir mudança de papel, mas a igualdade compara
   repository, membership, person, institution, unit e group e ignora
   `roleCode`/`scopeKind`. Uma atualização de papel na mesma membership conserva
   o draft sem nova leitura autorizada. Ambos devem participar da identidade do
   contexto, com teste de mudança isolada.

Os achados foram enviados ao C0 e diretamente ao G4. Nenhum teste foi repetido;
a evidência nativa de G4 registra 37 aprovados.

## Revisão da correção

O G4 publicou `b58cbaec9`. A revisão estática final confirmou, sem novo achado
bloqueador:

- `subject_type` e `subject_id` agora precisam coincidir exatamente com o
  sujeito solicitado antes da construção da página;
- quatro casos negativos cobrem tipo/id diferente ou ausente;
- `roleCode` e `scopeKind` agora participam da identidade de
  `didUpdateWidget`, com dois casos isolados de reload fail-closed;
- nenhum campo ou requisito de actor foi adicionado ao DTO.

A prova pertence ao G4: RED 6 esperado, depois 43 PASS/0 FAIL/0 SKIP e análise
sem apontamentos. O G6 não repetiu Flutter.
