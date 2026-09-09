---
title: "D02 — contrato e DTO de reservas datadas"
source: "Spec de Locais de 2026-09-02; candidato2e3ae0f7; código/testes D02; reserva D00r11"
status: "local-green; no-backend-or-e2e"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Etapa2 → apps/superadmin → Locais → agendamento → locations.schedule; contratos para groups.location, activities.location e consumidores D03. Reserva datada não é janela semanal de funcionamento.

A recuperação do candidato mantém consumidor tipado+ID, ocorrência UTC, conflito sem divulgar outro consumidor e listas de ocorrências imutáveis. Correções atuais: weekdays defensivos e validados; término como data de calendário; fuso IANA obrigatório e explícito na recorrência semanal. O backend deve validar o fuso e expandir em horário local; offset UTC sozinho não define as regras futuras. Não há expansão no Flutter.

DTO: encodeLocationReservationDraftV2 produz location_id, consumer, first_occurrence, recurrence e conflict_justification; não envia política nem inventa ocorrências. Recorrência semanal usa kind=weekly, weekdays0..6 ordenados, until=YYYY-MM-DD e time_zone. O decoder recebe somente o payload de sucesso já separado do envelope e exige requestedLocationId/requestedConsumer; compara IDs/tipo, versão positiva, estados/booleanos estritos, intervalos válidos e shape fechado. Assessment exige correlação e consistência block/warn com none/refused/confirmable/not_confirmable; intervalos de conflito não aceitam consumer_id. Envelope, endpoint, cache e autorização não foram implementados aqui.

## Evidência observada

Registro reconstruído das saídas de ferramentas; não é transcrição bruta.
Cwd domain: packages/coelo_domain. `rtk proxy dart test test/locations/location_reservations_contract_test.dart --name 'copies the weekdays|rejects empty'`: RED0P/2F, mutação externa esvaziava weekdays e datas/dias inválidos eram aceitos. Após fix, `rtk proxy dart test test/locations/location_reservations_contract_test.dart`:13PASS únicos,exit0. Contagem histórica21 do commit original não foi usada.
Cwd api: packages/coelo_api. Teste novo inicialmente não carregou porque codecs não existiam: falha de carregamento esperada, nenhum caso funcional executado. Após implementação, `rtk proxy dart test test/locations/location_reservation_dto_test.dart`:21PASS únicos,exit0.
Analyzer final dos6paths production/exports/testes: No issues found,exit0. Cinco infos de braces na primeira análise foram corrigidas. dart format e git diff --check sem erro.

SHAs publicados:3e97048a (domain),753fbd33 (DTO). São contratos locais aptos a revisão/consumo tipado; não concluem FE/BE/E2E nem criam reserva no banco. Critério seguinte: reader/writer/motor SQL nominal e UI integrada, política/recorrência/conflito/override, persistência/reload e negativas reais.
