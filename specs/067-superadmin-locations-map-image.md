---
title: "Operação › Locais — mapa por imagem, mídia com visibilidade e hierarquia (OQ-034)"
source: "docs/open-questions.md (OQ-034, confirmado pelo Owner em 15/09/2026); docs/archive/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md (design aprovado; catálogo, reservas e política de conflito); OQ-045 (domínio R2 `locations`); decisions/0032-mvp-private-media-r2.md; docs/reviews/inventario-etapa-2.json (institutions.locations-map deferred-post-mvp → substituída); dump de schema de produção de 17/09/2026 (SHA-256 c87f4d67…): public.activity_locations, public.location_bindings, public.location_reservations, public.location_reservation_occurrences, public.location_scheduling_policies"
status: "approved-for-implementation"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
---

# Operação › Locais

Spec **sem prova**. Substitui a ação `institutions.locations-map` (fora do
MVP) pela tela **Operação › Locais**, na direção do Owner (OQ-034). O design de
02/09 (catálogo, reservas, política de conflito) continua válido onde não
conflita; esta spec fixa a tela, a hierarquia e a mídia.

## Tela

- **Lista**: um card por instituição (e a mesma lista em tabela); menu ⋯ com
  "Ver mapa da instituição" e "Ver unidades". Em Unidades, cards/tabela com as
  unidades da instituição, cada uma com o próprio mapa e locais.
- **Mapa da instituição / unidade (wizard)**:
  1. **Endereço** puxado do cadastro (instituição ou unidade). Alterar em
     qualquer tela avisa por popup que muda nas duas e pede confirmação.
     **Imagem do mapa geral** (anexo; sem provedor de mapas — Google/Mapbox
     só na seção Sobre, pós-MVP). **Fotos e vídeos** da instituição/unidade
     com visibilidade **todos / só quem acompanha / ninguém**, com aviso de que
     servem para dar visibilidade (perfil público depois do MVP).
  2. **Locais** (lista + adicionar).
- **Local**: `kind` **interno** | **externo**.
  - Interno: Bloco (tem? nome livre) → Andar (subsolo, −3, −2, −1, térreo,
    1º…8º, outros) → Tipo (sala, quadra, piscina, secretaria, estoque,
    laboratório, refeitório, biblioteca, auditório, pátio/parquinho,
    banheiro/fraldário, enfermaria, outros) → Nome → foto (opcional) → planta
    (opcional) → visibilidade **todos / funcionários / responsáveis / admin /
    nenhum**.
  - Externo: **endereço obrigatório**; demais campos opcionais.
- **Integração** com Turmas e Atividades: "cadastrar local" a partir da turma
  ou atividade leva a esta tela — sem locais, inicia o cadastro; com locais,
  abre com instituição/unidade/bloco/andar pré-selecionados.

## Modelo de dados (esboço, forward-only)

- `public.locations` (nova, canônica): `owner_kind` (`institution`|`unit`),
  `institution_id`, `unit_id?`, `kind` (`internal`|`external`), `block_name?`,
  `floor_code` (allowlist acima), `type_code` (allowlist acima), `name`,
  `address_json?` (obrigatório se externo), `visibility`
  (`all|staff|guardians|admin|none`), `status`, `management_version`,
  `provenance_location_id?` (repasse instituição → unidade cria cópia).
- `public.location_media_assets`: mapa geral, foto, planta e vídeos, em R2
  privado (`coelo-media-prod`, domínio `locations` — OQ-045), com
  `purpose` (`site-map|photo|floor-plan|video`) e `visibility`
  (`all|followers|none` para mídia da instituição; a do local herda a do
  local). Media Gateway próprio `location-media` (modelo `now-media`).
- `activity_locations`/`location_bindings`/reservas existentes passam a
  referenciar `locations.id` (compatibilidade por view enquanto houver dados
  legados; hoje não há locais catalogados em produção).
- Endereço da instituição/unidade permanece a fonte; `locations` não copia
  endereço da sede.

## RPCs (esboço)

`superadmin_locations_directory_v1` (instituições/unidades com contagem de
locais), `superadmin_location_map_get_v1(owner)`, `superadmin_location_save_v1`
(criar/editar com `expected_version`, PT409), `superadmin_location_change_status_v1`
(inativar/reativar — spec 066), `prepare/finalize/authorize_read` da mídia
(gateway). Visibilidade validada no backend/RLS; mídia nunca pública.

## Aceite (futuro recorte)

pgTAP: externo exige endereço, allowlists de andar/tipo, visibilidade por
público, repasse cria cópia com proveniência, cross-tenant negado, mídia sem
URL pública; FE: wizard de dois passos, hierarquia pré-selecionada vindo de
Turmas/Atividades, popup de endereço; rota real com upload real de mapa e
foto (CDP), reload, negativa de leitura por público não autorizado.
