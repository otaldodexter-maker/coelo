---
title: "E2E5 — harness de segurança e preview de Atividades"
source: "activity_repository_security_test.dart; activity_routes_test.dart; review activities_contract_read"
status: "testes locais atualizados; sem alteração produtiva"
generated_at: "2026-09-07"
---

Recorte: ajustar dois testes ao contrato já implementado, preservando negativas;
fora: código produtivo/SQL/deploy. Ordem falha real → diagnóstico de expectativa
obsoleta → correção do harness → regressão/review. Parada local: regressão verde
e nenhuma flexibilização de autorização. Cerca de 3 minutos.

Falhas reais: security test esperava zero HTTP, embora A01 já use directory_v2;
rota DEV esperava preview aberto sem optar por allowDevelopmentPreview.

Agora o security test exige exatamente uma chamada ao RPC nominal v2, sem query
e busca literal no corpo JSON. Detail/form-options não geram chamadas legadas.
Somente o cenário DEV recebe opt-in; novo teste preserva default bloqueado sem
sessão, redirecionamento login e zero chamadas ao repository de produção.

`flutter test --no-pub test/features/activities/data
test/app/router/activity_routes_test.dart`: **64/64 PASS**.
Analyzer dos dois testes: sem issues; diff check limpo. Review independente:
sem enfraquecimento de segurança identificado. Nenhum arquivo produtivo alterado.

Não comprova E2E/BD; guard produtivo e contrato nominal permanecem intactos.
Gate de memória no-op, sem nova regra de produto. Rastreadores centrais sob
writer Coordenador.
