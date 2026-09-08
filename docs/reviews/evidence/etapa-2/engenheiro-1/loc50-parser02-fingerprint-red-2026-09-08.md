---
source:
  - "Gate central LOC50, snapshot c80be689317f72a38ebba0f8bf86354d94fa5ab9"
  - "Execução local LOC-PARSE02 e consulta independente do ledger, 2026-09-08"
  - "Candidata 6b0cbb3009c7184896cfd2aebd6c7a7ca0fafe10"
status: bloqueio_preflight_fingerprint_zero_pgtap
generated_at: "2026-09-08"
---

O replay **LocationCatalogV2/50** compilou o DO preflight corrigido e parou com **SQLSTATE 55000: location legacy helper fingerprint drift**, statement 4. **Zero pgTAP**: as três fixtures aprovadas não chegaram a executar. O erro de parser 42601 anterior não reapareceu.

O fluxo alcançou o loop de sete helpers após validar estrutura, constraints, índice/policy e ACL da tabela, incluindo MAINTAIN. A mensagem genérica não identifica qual assinatura divergiu; não é possível atribuir um helper ou hash específico a esta execução. Os demais gates posteriores e o resultado funcional LOC não foram comprovados.

Uma consulta independente, somente de leitura no container de identidade conferida, capturou às **05:06:46.1285895 UTC** o ledger com **49 nomes e versões**, terminando em **20260908030959_location_catalog_v2_capability_bootstrap_local**. A candidata 31000 não consta nessa captura. Os 49 registros correspondem integralmente aos primeiros 49 inputs do perfil nominal. O registro integral está em [loc50-parser02-ledger49-2026-09-08.json](loc50-parser02-ledger49-2026-09-08.json).

O observador aguardava nominalmente a versão 50, que não foi aplicada; encerrou no deadline sem encontrá-la, exit 1, preservando sua última captura válida de 49. Isso não é uma segunda tentativa de replay. A consulta não aplicou SQL de aplicação nem reteve a stack.

| Evidência | Valor |
|---|---|
| Início UTC | 2026-09-08T05:05:25.4745946+00:00 |
| Identidade | coelo_safe_9b7246578068485594779a6fbae45 |
| Criação UTC | 2026-09-08T05:05:31.5550764Z |
| Marker | .coelo-safe-replay lido e idêntico à identidade |
| Preparação | 47 canônicas + 2 preflights + 1 bootstrap = 50 |
| Ledger capturado | 49 entradas, máximo 20260908030959 |
| Primeiro bloqueio | 55000 / location legacy helper fingerprint drift |
| pgTAP | 0 |
| Wrapper | sessão 6514 encerrada, exit 1 |
| Observador de ledger | sessão 41915 encerrada, exit 1 por alvo 50 não encontrado |
| Cleanup independente UTC | 2026-09-08T05:08:25.0618667+00:00 |
| Recursos próprios | 0 containers, 0 volumes, 0 redes; staging ausente |
| Staging histórico alheio | coelo_safe_af5bdf571cff41309f5b6845b713a preservado |

O snapshot foi comparado com c80be689 antes do start. Candidata blob **8d26581692ff78db923de98d7c788257857fbbdb**, SHA CRLF **f6c6c842114932d96af6b2478df43827241192044cfcae778e7ca3e4132960df**; bootstrap 115df2ca e três fixtures originais preservados. Não houve nova alteração, retry, grant ou enfraquecimento de fingerprint.

A coordenação autorizou preparar um probe Auth47 das sete assinaturas, com catálogo e hashes brutos/normalizados somente na consulta. A execução desse probe exige gate próprio. Nenhuma regra de produto foi alterada; o bloqueio e seu encaminhamento permanecem nesta fonte canônica de evidência, sem nova projeção de conhecimento.
