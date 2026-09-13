---
source: "Owner R10; base 845ffe9b5"
status: "no-op; current implementation complies"
generated_at: "2026-09-13"
---

# C1 — Editar como ação primária

## Recorte

`Etapa 2 -> apps/superadmin -> detalhes administrativos -> Editar`.

Foram inspecionados somente consumidores de detalhe no escopo autorizado. Os
menus de linha, ações secundárias, Principal, Atividades e `group_form_page`
ficaram fora.

| Consumidor | action_id | Estado encontrado |
| --- | --- | --- |
| `person_detail_page.dart` | `people.edit` | `FilledButton.icon`, key `person-detail-edit` |
| `access_profile_detail_page.dart` | `access-profiles.edit` | `FilledButton.icon` para modelo e perfil |
| `superadmin_circular_detail_page.dart` | `circulars.detail` / `circulars.edit` | `FilledButton.icon`, key `circular-detail-edit`; desabilita em ação ocupada e não aparece em status não editável |

Não há CTA primário equivalente nos detalhes autorizados de Institutions,
Units ou Groups. Meal Plans e Notices expõem apenas ações de linha/diretório,
fora do recorte. O tema do `FilledButton` fornece o laranja de marca sem HEX
ou estilo local.

Nenhuma alteração de código, teste, build, Chrome, remoto ou tracker central
foi necessária.
