---
title: "LOC-BOOT01 — materialização nominal local"
source: "Engenheiro1 e coordenação em2026-09-08; LOC-TAP01 fbef1b92"
status: "prepared-not-executed-local-only"
generated_at: "2026-09-08"
---

# Seleção e ordem

Somente Engenheiro1 materializa no perfil local LocationCatalogV2, mediante
SQL gate explícito da coordenação. Este documento e o artefato não concedem
autorização de execução nem criam perfil/Docker/banco. Nunca copiar para o
diretório de migrations de produção.

Derivado entregue em
`packages/coelo_database/tests/fixtures/20260908030959_location_catalog_v2_capability_bootstrap_local.sql`.
Aplicar após dependências Auth nominalmente selecionadas e antes da candidata
20260908031000. Timestamp30959 define somente a ordenação no perfil local.

O runner faz reset antes das fixtures e não aceita include psql. Por isso o
derivado é SQL autocontido: somente `SET LOCAL coelo.local_replay =
'location-catalog-v2';` foi inserido imediatamente depois de BEGIN e antes de
DO. COMMIT encerra a configuração local. Cabeçalho histórico da fonte foi
preservado; a instrução de SET externo nele é dispensada apenas neste derivado.
Não há novo grant de execução, bypass de guard, alteração de auditoria ou
mudança nos inserts nominais de capabilities/Owner.

## Proveniência

- Fonte intacta: `tests/fixtures/location_catalog_v2_capability_bootstrap.sql`,
  SHA256 `3DD0BF5C11E52A68102E3E707E48835EB676513C235DAAB5DEFCDB1E7AD24BFB`.
- Derivado: SHA256 `D46583BC936DFB284B5D05BDBA8DEA8F965D31A0F899164BFDD8A8C6BD6D2471`.
- Candidata31000 permanece inalterada: SHA256
  `6871FBA98001D37154CC7BA76B896EBC67FD93CCCA6EB18BAAA2C17CBA1AC652`.
- IDs Git94701e7b/fbef1b92 identificam commits, não SHA256 de arquivo.

`Test-LocationBootstrapMaterialization.Tests.ps1` reproduziu RED por ausência
do derivado, depois PASS: fonte tem SHA exato e derivado só acrescenta a linha
GUC (comparação textual após normalizar CRLF/LF). SQL não foi executado.

## ACL PG17: pendência não resolvida por este pacote

config.toml selecionaPG17 e20260811192514 concede ALL a service_role. É
fundamento para suspeita de MAINTAIN no catálogo, não resultado de consulta.
Engenheiro1 propôs probe AuthOnly47 independente, sob liberação central.
Probe solicitado: versão/current_user e aclexplode do activity_locations,
excluindo owner, ordenado por grantee/privilege_type. Só após catálogo nominal
retornado pode ser proposto acrescentar exatamente
`service_role:MAINTAIN:false` ao fingerprint, se essa for a única diferença.
Nenhum grant foi revogado/acrescentado e nenhum fingerprint relaxado aqui.

Memória: preparação operacional, não nova regra durável de produto.
