---
title: "Proposta ao coordenador — separar a chave de mutação de Estrutura por realm"
source: "superadmin_router.dart:611 e :742; superadmin_auth_scope.dart:375; docs/open-questions.md OQ-032 e OQ-043; migrations de CRUD por família"
status: "proposta; não implementada pelo executor por ser arquivo compartilhado com 21 pontos de chamada"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O problema

`structureMutationsEnabled` é uma chave só, e o router a aplica a quatro famílias:
`_isStructureMutationLocation` cobre `/institutions/`, `/units/`, `/groups/` e
`/activities/`. A justificativa escrita ao lado dela, em
`superadmin_auth_scope.dart:375`, é: "OQ-032/OQ-043: these CRUD repositories
still target the legacy people-based realm".

Fui verificar família por família qual RPC o CRUD realmente chama, e a
justificativa **já não vale para metade delas**:

| Família | RPC de CRUD | Realm | Migration |
| --- | --- | --- | --- |
| Instituições | `superadmin_institution_edit_core_v2` | **interno v2** | `20260828000500_superadmin_internal_institution_edit_core.sql` |
| Atividades | `superadmin_activity_save_v2` | **interno v2** | cadeia `activities_v2`, OQ-043 resolvida para Activities em 2026-08-31 |
| Turmas | `superadmin_group_save` | people-based | `20260811151254_group_management_security.sql`, com `updated_by_person_id references public.people` |
| Unidades | `create_unit_for_superadmin`, `update_unit_for_superadmin` | people-based, e **sem migration nenhuma** | — (OQ-032 em aberto: conflito `institution_type_id` × `unit_type_id`) |

A OQ-043 diz textualmente que a resolução vale para Activities e que "outros
CRUDs anteriores à ADR 0019 continuam fora desta resolução". A OQ-032 continua
aberta e é um conflito real de schema, não uma pendência de composição.

Ou seja: Unidades e Turmas estão **corretamente** fechadas. Instituições e
Atividades estão fechadas por carona numa chave cuja razão não se aplica a elas.
São cinco ações do recorte presas assim: `institutions.create`,
`institutions.edit`, `activities.create`, `activities.edit` e
`activities.assessment`.

# A proposta

Separar em duas chaves, mantendo as duas em `false` — nada muda de
comportamento até alguém decidir ligar:

```dart
// superadmin_router.dart, junto de hasAssessmentMutationCapability
bool hasStructureMutationCapability(String location) =>
    location.startsWith('/institutions/') || location.startsWith('/activities/')
    ? enableInternalRealmStructureMutations
    : enableStructureMutations;
```

com o novo parâmetro `bool enableInternalRealmStructureMutations = false` ao lado
de `enableStructureMutations`, propagado por `SuperadminApp` e pelo escopo de
auth do mesmo jeito que o atual.

O `redirect` de `:742` passa a chamar `hasStructureMutationCapability(location)`.
Os outros **21 pontos de chamada** estão dentro de blocos de rota de família
conhecida, então cada um vira a chave certa por leitura direta — não dá para
fazer isso por substituição cega.

# Por que não implementei

O `superadmin_router.dart` é editado por várias frentes nesta rodada. Uma mudança
em 21 pontos dele, vinda de um executor, vira conflito de integração caro e
atravessa a decisão de quem liga a chave, que é do coordenador e do Owner. A
proposta fica aqui com o formato exato do patch; a decisão e a execução são de
quem integra.

# O que muda se for aceita

Instituições e Atividades passam a poder abrir suas telas de criar e editar assim
que o backend delas estiver aplicado, **sem** esperar a OQ-032 de Unidades, que é
o item mais longe de fechar do recorte inteiro. Pelo mapa de gates, são cinco
ações destravadas por uma mudança que não toca em nenhuma regra de autorização —
o servidor continua revalidando tudo.
