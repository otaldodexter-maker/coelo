---
source: "ADR0032; spec Locais2026-09-02; inventario de codigo D02 em2026-09-09"
status: "nominal-dependency-proposal; implementation-not-started"
generated_at: "2026-09-09"
---

# Dependência concreta para planta, marcadores e foto

Superfícies: institutions.locations-map, units.locations-map e
locations.detail-links. O catálogo LOC01–04 não cria imagem/planta ou marcador.
O componente de formulário informa essa indisponibilidade. A prévia externa
de endereço é desenho ilustrativo, sem geocoding, e não é planta R2.

Contrato reaproveitável existente em `packages/coelo_api/lib/src/media`:
MediaUploadTarget(institutionId,resourceId,domain,purpose), MediaUploader,
MediaReader e MediaSession. O ciclo compartilhado SuperadminMediaScope invalida
capacidades/bytes por revisão de autorização. Não criar outro lifetime ou
transporte de segredos no domínio Locais.

ADR0032 já fixa domínio `locations`, finalidades `map-general` e `photo` e
entidades `location-map`/`location`. Não há nova decisão de prefixo.
Planta: origem20MiB/64MP, master6000px/8MiB; foto: origem10MiB/36MP,
master2560px/4MiB. Bytes/MIME/dimensões/checksum e remoçãoEXIF dependem do
pipeline server-side; o cliente não pode fabricar recibo de normalização.

Gargalo de schema apurado: migration compartilhada
`20260908160000_private_media_catalog_r2_v1.sql` limita media_assets a
legacy-happens/form-image e media_bindings a form_version/item. Sua chave
canônica deriva campos de Forms. Nenhum binding de mapa/foto de Locais foi
encontrado no catálogo, funções ou adapter da base inspecionada. Portanto o
gateway genérico não autoriza reaproveitar endpoints de Forms para esses bytes.

Pacote nominal necessário para revisão D00, antes de escrever shared schema:

- Migration nova e TAP próprios de Locais para location_maps (um por owner),
  location_map_markers (coordenadas normalizadas0..1, alttext e FK Local),
  referências tipadas aos ativos/variantes compartilhados. Não criar segundo
  catálogo de assets, bucket ou keybuilder independente.
- Extensão nominal dos constraints e binding/ownership do catálogo privado
  para essas duas entidades/finalidades, preservando Forms/Acontece existentes.
- Adapters server-side do mesmo fluxo MediaUploader/Reader com capacidades,
  ownership/visibilidade, receipts, upload/finalização/read/revogação/cleanup.
- Composição do SuperadminMediaScope já compartilhado e adapter app-local,
  sem bucket/object_key/credenciais no contrato Flutter.

Prova exigida: permitido/negado/revogado, tenantA/B, finalização medida,
substituição/remoção, URL expirada, purga do lifetime, persistência/reload e
auditoria. Nenhuma operação R2 foi realizada e não há pacote remoto nominal
para aplicar neste checkpoint. A reserva solicitada do motor de reservas
datadas não inclui esse schema/mídia compartilhados.
