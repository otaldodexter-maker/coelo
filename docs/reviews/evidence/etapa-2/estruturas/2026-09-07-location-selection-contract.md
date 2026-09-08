---
title: "LOC-CONTRACT01 — seleção de local em Dart puro"
source: "reserva do Coordenador; design/plano aprovados; testes e revisões locais"
status: "local-green; not-verified-e2e"
generated_at: "2026-09-07"
---

# Pacote nominal

Três arquivos novos em coelo_domain: barrel lib/locations.dart, fonte
lib/src/locations/location_selection.dart e teste próprio. O barrel geral e
consumidores ficaram intocados. Busca de símbolos não encontrou contrato
equivalente; opções legadas de Atividades não fornecem tipo nem catálogo
institucional e não foram convertidas.

## Verificação

RED confirmado antes da fonte: import ausente e tipos não definidos, não falha
ambiental. Depois:9 testes novos e31 testes totais do pacote passaram.
`dart analyze` no pacote inteiro: zero issues. Nenhuma dependência adicionada
ou atualizada; lock não rastreado gerado pela resolução do teste foi removido.

Revisão de conformidade e revisão de qualidade independentes, ambas somente
leitura: sem bloqueadores. Cobertura: proprietários distintos, IDs explícitos,
kinds explícitos, variantes exaustivas, catalogado/pontual, snapshot estável e
ausência nullable. Os testes não substituem validação ou autorização server-side.

## Compatibilidade e limites

Consumidores futuros importam package:coelo_domain/locations.dart. Snapshot
não é entidade completa, não é autoridade nem estado atual. Não há serialização
de RPC, catálogo paralelo, adapter legado, autorização, cópia, reserva, foto,
mapa, endereço ou operação remota nesta fatia.

E2E4/5 devem revisar o contrato antes de adotar; não recebem autorização para
reservar outro catálogo nem inferir tipo de opção legada. A fonte canônica local
e a projeção team documentam esses limites. Não se alterou conhecimento admin
ou users porque comportamento disponível nessas superfícies não mudou.
Gate de conhecimento: base e cenários passaram. O validador exige source
escalar; fonte complementar ficou no corpo do artigo, sem alterar o validador.
