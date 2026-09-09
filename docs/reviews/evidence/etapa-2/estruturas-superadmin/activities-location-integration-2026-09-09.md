---
title: "Atividades — corte técnico para seleção de local e reserva"
source: "D02 R02; spec aprovada de Locais de 2026-09-02; inspeção da base e candidatos em 2026-09-09"
status: "reviewed-design; implementation-blocked-on-nominal-shared-reservations"
generated_at: "2026-09-09"
---

# Achado na base

`activities.location` ainda não possui persistência segura. O formulário usa o
modelo legado `ActivityFormLocationOption`, limitado a unidade, e guarda apenas
`ActivityFormDraft.locationId`. `_activitySaveCommand` descarta esse campo e o
RPC agregado `superadmin_activity_save_v2` rejeita chaves de local. Portanto uma
resposta de sucesso do save não prova que o local foi salvo.

O catálogo compartilhado já oferece `LocationSelection`, snapshots e
`LocationSelectionField`. Ele não pode ser alimentado pelas opções legadas:
`ActivityFormLocationOption` não informa escopo institucional, tipo interno ou
externo nem estado atual. A própria spec proíbe inferir esses valores.

A migration candidata do catálogo em `9e689374` encerra a descoberta e o writer
legados de `activity_locations`; ela não cria vínculo entre local e atividade.
O contrato mínimo de reservas existe no candidato arquivado `2e3ae0f7`, mas não
está na base atual e declara corretamente que ainda faltam reader, writer,
adapter e SQL. A disponibilidade semanal de `15516da9` não é reserva datada.

# Menor sequência segura

1. Integrar e revisar os três paths de `2e3ae0f7`:
   `packages/coelo_domain/lib/src/locations/location_catalog_entry.dart`,
   `packages/coelo_domain/lib/src/locations/location_reservations.dart` e
   `packages/coelo_domain/test/locations/location_reservations_contract_test.dart`.
   O contrato preserva consumidor `activity`, ocorrência UTC, recorrência única
   ou semanal limitada e decisão de conflito exclusivamente server-side.
2. Criar DTO compartilhado nominal em
   `packages/coelo_api/lib/src/locations/location_reservation_dto.dart`, exportado
   por `packages/coelo_api/lib/locations.dart`, com encode estrito do draft e
   decode estrito de assessment/resultado. Nenhum DTO expõe outro consumidor do
   conflito, expande recorrência no cliente ou trata snapshot como autorização.
3. Criar migration forward-only nova
   `packages/coelo_database/migrations/<versão>_superadmin_activity_location_reservations_v1.sql`.
   Não editar migrations históricas. Ela introduz o vínculo canônico do
   consumidor com XOR entre `location_id` catalogado e texto pontual, snapshot
   textual/versionado, e reservas/ocorrências expandidas pelo servidor. Nomes
   físicos finais e a dependência da migration do catálogo precisam de reserva
   nominal antes da escrita.
4. Na mesma migration, substituir a implementação do RPC agregado v2 sem mudar
   sua assinatura. O payload passa a exigir `location_selection` e
   `location_reservation`; ausência explícita é `null`, não omissão. O save
   valida catálogo ativo, scope/tenant/hierarquia, atividade consumidora,
   política corrente e capability de override. O lock do request e os locks de
   local/intervalo vêm antes de uma segunda validação de sessão, identidade,
   vínculo e capability. Atividade, vínculo, reserva, recibo e auditoria ficam
   na mesma transação; qualquer negação ou conflito deixa zero efeito parcial.
5. Estender o reader v2 da atividade para retornar a seleção persistida e a
   reserva canônica. O detalhe retorna snapshot histórico para renderização e
   reautoriza o recurso atual separadamente; ausência de acesso não vira
   `not found` nem reutiliza a lista legada de locais.
6. No cliente, alterar somente após os contratos acima:
   `activity_command.dart`, `activity_directory.dart`,
   `supabase_activity_command_repository.dart`,
   `supabase_activity_directory_repository.dart`, `activity_form_draft.dart`,
   `activity_form_controller.dart`, `activity_form_sections.dart` e
   `activity_form_page.dart`. O formulário compõe `LocationSelectionField` com
   `CatalogLocationSelectionSource`; seleção catalogada ou pontual permanece no
   draft. A opção de reserva só aparece quando existe período, dias e horários
   próprios da atividade. Datas de avaliação pedagógica não podem ser usadas
   como agenda da atividade.
7. `superadmin_router.dart` recebe uma reserva curta apenas para injetar o
   reader/source compartilhado. O bootstrap produtivo não usa fixtures nem o
   catálogo legado.

# Payload e resposta mínimos

`location_selection` é `null`, `{kind: catalogued, snapshot: {id, scope_kind,
institution_id, unit_id, location_kind, label}}` ou `{kind: one_off, text}`.
`location_reservation` é `null` ou contém o local catalogado, consumidor
`activity`, primeira ocorrência UTC, recorrência única/semanal limitada e a
justificativa somente na confirmação de conflito. Texto pontual nunca é
reservável.

A resposta de sucesso inclui `location_selection` canônica e, quando aplicável,
`reservation` com ID, versão positiva, ocorrências UTC expandidas e indicador de
override. O cliente mantém as validações existentes de correlação da atividade,
versão positiva e status e acrescenta igualdade de consumidor/atividade,
location ID e escopo. Divergência falha fechada.

# Provas necessárias

- permitido, negado, tenant A/B e hierarquia instituição/unidade;
- local inativo/revogado durante espera e sessão expirada durante espera;
- um vencedor em concorrência e retry idempotente com a mesma resposta;
- conflito `block`, `warn` sem capability, `warn` com justificativa e auditoria;
- zero atividade/vínculo/reserva/recibo parcial após falha;
- reload do detalhe mostrando seleção e reserva persistidas;
- snapshot renomeado/inativo preservado como histórico sem virar autorização;
- teste Flutter da rota produtiva com source real, save, releitura e falhas
  sanitizadas.

O guard local que impede salvar enquanto `locationId` legado está selecionado é
somente uma proteção contra descarte silencioso. Ele não conclui
`activities.location` nem qualquer aceite de reservas.
