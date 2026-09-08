---
title: "LOC-CATALOG01 — proposta nominal de catálogo único"
source: "docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md"
status: "draft-for-coordinator-review"
generated_at: "2026-09-07"
---

# Objetivo e primeiro gate

Preparar o menor pacote SQL original para leitura/detalhe/criação de locais
textuais de instituição ou unidade. Não executar SQL mutante, replay ou deploy
com base neste documento. A reserva compartilhada, a matriz de capabilities,
o cutover legado e os campos mínimos de endereço precisam de aprovação nominal.

Este é um passo da vertical integral Estruturas/Pessoas/Locais. Não encerra
`locations.list`, `locations.create-edit`, `locations.detail-links` ou qualquer
dos sete IDs da E2E 2.

## Crosswalk factual

| Objeto existente | Papel atual | Consequência para o novo contrato |
| --- | --- | --- |
| `public.activity_locations` | Único catálogo físico encontrado: unit-only, UUID, nome, descrição, status, versão, autor people | Evoluir uma única fonte, sem duplicar IDs em catálogo paralelo. |
| `institution_addresses` / `unit_addresses` | Endereço do proprietário | Compartilhar vocabulário, não herdar registro/endereço automaticamente. |
| `institution_directory_locations` | View geográfica de filtros | Não é catálogo nem substituto de Locais. |
| `activity_management_payload` | Agrega locais pela unidade, inclusive `to_jsonb(location)` | Não representa bindings explícitos; ampliação de colunas/linhas exige fechar esse caminho. |
| `superadmin_get_activity_form_options` | Opções legadas id/unit/name | Não comprova tipo, visibilidade ou autorização do novo catálogo. |
| `superadmin_create_activity_locations` | Writer people-based e receipt próprio de Atividades | Não usar no realm interno nem converter seu receipt em autorização. |
| Groups detail | Sem local/endereço | Grupo é consumidor, nunca proprietário de catálogo. |
| `public.media_assets` | Modelo legado Acontece, com post obrigatório | Não acoplar Locais nem criar segunda plataforma; consumir contrato E2E 3. |

### Inventário remoto oficial, somente leitura

Projeto `coelo`, ref `evvbomzejfijozbtgvpt`, `ACTIVE_HEALTHY`, produção.
Consulta pelo plugin oficial Supabase, dois SELECTs de metadados e contagem
agregada; sem valores de registros, PII, DDL/DML, chamada de RPC ou HTTP de
negócio. Snapshot de 2026-09-07 (horário local):

- `activity_locations`: dez colunas, `unit_id NOT NULL`,
  `created_by_person_id NOT NULL`, RLS e FORCE RLS habilitados.
- Contagem total 0; ativos 0. Isso não garante que continuará vazio: o futuro
  pacote deve verificar novamente sob lock e abortar caso haja registros.
- Não foram encontradas tabelas `locations`, `location_maps`,
  `location_bindings` entre esses nomes consultados em public/app_private.
- SELECT direto concedido a authenticated, com policy people-based
  `activities.read`; service_role tem os sete grants de tabela.
- Gateways públicos directory/options/create de Atividades têm EXECUTE para
  authenticated. Helpers privados consultados não têm EXECUTE de cliente.
- `activity_management_payload` e writer privado de locais contêm
  `to_jsonb(location)`. Logo adicionar colunas na tabela sem fechar caminhos
  legados pode expor campos novos automaticamente. Não foi afirmado incidente
  nem executado teste de exploração.

MD5 das definições remotas consultadas (fingerprint, não prova de equivalência
textual com migrations):

| Função | MD5 |
| --- | --- |
| app_private.activity_management_payload(uuid) | dbfb21e52b0773a41815a0986be0d64f |
| app_private.superadmin_activity_directory(...) | f1809b1c0b268ed571eaaa958a061015 |
| public.superadmin_activity_directory(...) | e1e94802dd59857459e6816c8b6a4069 |
| app_private.superadmin_get_activity_form_options(uuid) | 65fe6408f0f2c6b0c1c9d71a809f2d80 |
| public.superadmin_get_activity_form_options(uuid) | 4600bdfb92b0ea38f597947365750052 |
| app_private.superadmin_create_activity_locations(...) | 886752274164d0d435c9df8ced18d896 |
| public.superadmin_create_activity_locations(...) | 1898ddd4ec4ea12373e1c13c55336774 |

## Proposta física, ainda não autorizada

Preferir evolução de `activity_locations`, preservando sua identidade física.
O nome legado não obriga uma segunda tabela. Preflight exige tabela vazia e
shape/constraints/ACL correspondentes ao pacote revisado. Qualquer divergência
aborta; não fazer backfill, apagar registro ou inferir `internal`/visibilidade.

Campos candidatos: proprietário institution/unit, `kind` internal/external,
andar opcional, endereço próprio, `visibility` team/guardians/students/all e
autoria interna. `institution_id` permanece obrigatório; `unit_id` passa a
opcional somente para proprietário institucional, mantendo FK composta.
Autor interno referencia `app_private.superadmin_internal_identities(id)`;
nenhum `current_person_id()` ou autor people sintético.

Delta de autoria proposto para aprovação: retirar `NOT NULL` de
`created_by_person_id`, sem apagar a coluna; exigir autoria interna nas novas
linhas desta fatia e impedir que o writer v2 informe autoria people. O contrato
final deve fixar a constraint exata junto do fechamento do writer legado, sem
abrir caminhos de Admin/Principal por inferência.

Preservar limites existentes de nome (120) e descrição (500), versão positiva
e IDs. Limite de andar, normalização, campos mínimos/limites de endereço e
tratamento dos nomes únicos são decisões nominais do contrato, não defaults
silenciosos. `all` significa somente audiência autenticada/autorizada, nunca
internet pública. Novas linhas exigem tipo/visibilidade explícitos.

### Boundary legado obrigatório no mesmo pacote transacional

Não basta uma policy RLS nova: leitores SECURITY DEFINER e projeções integrais
continuariam vendo os novos dados. A proposta depende de reserva E2E 2/E2E 5
para fechar todos os caminhos catalogais antigos antes de aceitar linhas novas:

1. Revogar leitura direta desnecessária de authenticated na tabela; manter
   deny-by-default e privilégio de service_role somente se nominalmente exigido.
2. Fechar writer público legado e seu helper para novos writes; sem mudar os
   demais comandos de Atividades por conveniência.
3. Remover a descoberta implícita de novos locais em payload/directory/options
   legados ou substituir por ponte explicitamente aprovada que reautorize
   ator/recurso/audiência. Nunca manter `to_jsonb(location)` irrestrito.
4. Não transformar ligação por unidade em vínculo reverso ou reserva. Sem
   bindings fabricados a partir das agregações legadas.

Essa transição exige review/regressão E2E 5. Enquanto não houver aprovação,
nenhuma dessas funções, grants ou tabelas será alterada.

## Contrato interno candidato

Nomes propostos, ainda sem migration/timestamp reservado:

- `public.superadmin_location_directory_v2`: proprietário explícito, paginação
  estável e filtros allowlisted, escopo real derivado/revalidado no servidor.
- `public.superadmin_location_detail_v2(p_location_id uuid)`: mínima projeção
  segura e ID inexistente/cross-scope indistinguível.
- `public.superadmin_location_create_v2(p_payload jsonb,p_request_id uuid)`:
  criação idempotente, validação e receipt privado por ator/request/hash.
- Helpers privados sem EXECUTE de cliente; receipt privado próprio da operação
  interna, não o receipt people-based de Atividades.

Capabilities candidatas `locations.read` / `locations.create`, inicialmente
Owner-only, são proposta de mínimo privilégio a aprovar, não grants existentes.
Não herdar `platform.read` ou `activities.read`. Preflight fixa matriz exata.
Escopos platform/institution seguem o contexto interno, sem client claims como
autoridade. A matriz/audiência de gestão precisa ficar explícita no aceite.

MFA segue ADR 0019, aditivo de 2026-09-01: AAL1/AAL2 aceitos durante validação
do MVP, preservando revalidação de sessão/capability/realm. Não copiar AAL2
obrigatório de specs históricas nem reativá-lo neste pacote.

Erros usam envelope seguro; auditoria interna registra ator/resultado e campos
alterados sem dump de nome/endereço. Receipt reautoriza no replay, não ressuscita
acesso revogado. Criação não inicia upload, binding, agenda ou notificação.

## Fora desta primeira fatia

Editar/inativar, copiar para unidade, mapas/marcadores/fotos, Media Gateway,
bindings/reversos, Turmas, opções para Formulários, Atividades/Eventos, reservas,
recorrência e conflitos. Permanecem no escopo original, não são descartados.

## RED/replay exigidos após aprovação

- Preflight rejeita shape/hash/ACL inesperados e qualquer linha pré-existente.
- Catálogos institution/unit independentes; FK cruzada e IDs adulterados negados.
- Ator não interno, sessão/vínculo/capability revogados e escopo alheio negados.
- Externo sem endereço válido negado; interno pode omitir endereço.
- Sem classificação/default de legado, PII extra ou client-supplied autoria.
- Idempotência, concorrência, reautorização de receipt e rollback audit failure.
- Leituras/joins/grants legados não alcançam linhas/colunas novas.
- Persistência e reload de fixtures transacionais com teardown íntegro.

Engenheiro 1 mantém ownership do Docker/harness; nenhum replay autônomo aqui.
Remoto exige lease nominal separado depois do pacote local revisado.

## Fontes locais e SHA-256 dos bytes

| Arquivo | SHA-256 |
| --- | --- |
| Design canônico 2026-09-02-superadmin-locais-mapas-agendamentos-design.md | 10428FC6E8CA8A25299F308391681A74B2593098CC5BCA40C67B400F0E95C51F |
| decisions/0019-superadmin-internal-identity.md | E4E9E6CE1AEC25F25F1504B84937841C6B86D5F466E1D12E4388697609F799AF |
| 20260811192514_activity_management_security.sql | DCB4B5F0781AF2F3B0BB1B6A9B63D79A00549E371B7CA0FEB0AC5BE5BD3820F4 |
| 20260811193838_activity_management_commands.sql | 77FDAE731EB56DF04BD45F3B8F854495A422BB3230802B5BC4855840F436813B |
| 20260811194840_activity_files_identity_commands.sql | 3AB6F64F3F2D00FB6FF99FA6F1F3C929753BCF29F5B6506F62C95B50107474E9 |
| 20260811200614_activity_read_model_contract_hardening.sql | 9E99D589EC89975110D3FCAEF8C363701BD255B00072B99A4797A923458CEA26 |

Memória de produto: no-op enquanto proposta não aprovada. Estimativa do pacote
local após decisões/reservas: 8–16 horas, a recalcular com o perfil de replay;
não inclui espera de ambiente, consumidor Flutter ou prova E2E.
