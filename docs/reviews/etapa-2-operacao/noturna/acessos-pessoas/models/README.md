---
source: "specs/018-profiles-permissions-superadmin.md; ADR0019; AGENTS.md; R02 D04; catalog-only production inspection 2026-09-09"
status: "local-candidate-awaiting-nominal-replay; no-production-authorization"
generated_at: "2026-09-09"
---

# Modelos: pacote nominal de Acessos e Pessoas

`apps/superadmin -> Acessos -> Modelos -> listar/filtrar/criar/detalhe/editar/duplicar`
(`access-models.list/filter/create/detail/edit/duplicate`). Base autoral `d784462c1`.

A leitura de catálogo remoto confirmou cursor legado, ausência do helper
`access_profile_require_model_action`, da tabela de receipts, das permissões
`*.role_models.*` e de `application_code`. Logo, aplicar somente o filtro CSV
`20260909174500` não instala o contrato que o cliente integrado consome.
Nenhum dado pessoal foi lido e nenhuma mutação remota foi executada.

`build_package.py` concatena cinco fontes canônicas, removendo somente seus
limites externos de transação. `manifest.json` registra SHA256 de cada fonte e
do resultado em UTF8/LF. Não altera migrations existentes. `package.sql` é um
candidato transacional; ainda não é uma migration autorizada para produção.

O preflight exige os corpos legados observados, fundação interna AAL1 vigente,
ausência da base Modelos e labels NOT NULL sem defaults do replay. O fechamento
revoga import/export de todos os clientes, inclusive `authenticated`, e confere
ACLs, proprietário, search_path e RLS. Preserva MFA adiado e metadados do gate.
Falha antes de COMMIT deve reverter todo o pacote; não aplicar partes avulsas.

Ensaio local usa o runner existente, perfil `AuthOnly`, target
`20260901200206`, primeiro `ap_models_nominal_package_test.sql` (8 casos), depois
`access_profile_models_aal1_phase_policy_test.sql` (34), as três suítes READ
authorization/helper_acl/prelookup_regression (11+10+17) e
`d04_access_models_scope_filter_test.sql` (15). Total nominal95, ainda não executado
na criação deste registro. Reexecução justificada: pacote e base de aplicação
diferentes da prova histórica15; esta não provava instalação sobre o remoto.
O arquivo gerado de teste remove apenas defaults locais de labels para exigir
as mesmas constraints de produção; nunca executar esse arquivo no remoto.

Próximos gates: ensaio95 e rollback negativo do pacote; revisão coordenada;
autorização nominal de produção; aplicação serializada; provas HTTP/UI normais
com personas e cleanup. SQL verde não autoriza publicar o cliente nem promove
FE/BE/E2E. Segurança infantil e demais contratos permanecem separados.

Memória: nenhuma nova regra aprovada; aplicação das invariantes existentes.
