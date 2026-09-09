---
source: "D00 r12/r13; attendance subagent; canonical working-tree wrapper observed 2026-09-09"
status: "superseded-by-d00-ownership; preserved-comparison-only; untested"
generated_at: "2026-09-09"
---

# Patch interrompido e preservado

`child-http-invoke.patch` foi preparado sob r12 e interrompido após r13 informar
que D00apoio assumiu o hook HTTP. Não aplicar como entrega apta. Nenhum runner
compartilhado foi editado; nenhum teste estrutural novo ou SQL foi executado.
D00 decide se algum hunk ajuda a comparação; a implementação central prevalece.

- Patch SHA256: FE2EA2581EDE719C5D03E153E8D0F27561623C588BAD12D046C7030AB2AF9A0A.
- HEAD da raiz na observação:232e65197551bbfbfcbce2338df89373a0d168a7.
- Wrapper da raiz tinha WIP D00: hash raw820F43F900CAAEAE19A8311BD3B2DA158C33E66019BB57FC118D6076EEC67721, LF0E3DBE65A0FE2202BF8EA8A14435E064B5B6C9BADC7ED61070512F9F18448B90.
- Candidato TEMP: d03-child-http-invoke-patched.ps1; hash29344E8FACBE9014125AF9BE21A864F718F63F428C2B55627D1B4F3F4BB922AD; sem processo ativo.
- Apenas git apply --check passou contra aquela fonte; não é teste de execução.

Hunks propostos: switch RunChildDirectoryHttp; serviços mínimos DB/GoTrue/Kong/
PostgREST; guards de perfil/target/modos incompatíveis; TAP exato; dispatch
HTTP após CHILD. O patch permite combinação com CHILD concurrency e pressupõe
perfil pós-CHILD. Portanto não é o novo ensaio pré-CHILD/cache da r13 e não deve
ser usado para repetir45+3 apenas como preparação HTTP.